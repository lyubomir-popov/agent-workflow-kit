"""Portable launchers and composing Git hooks, using isolated Git fixtures."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


KIT = Path(__file__).resolve().parents[1]


class HooksTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="wfk hooks ")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / "fixture repo"
        self.repo.mkdir()
        self.env = os.environ.copy()
        self.env.update({"WFK_CONFIG": str(self.base / "user.json"),
                         "GIT_CONFIG_NOSYSTEM": "1",
                         "GIT_CONFIG_GLOBAL": str(self.base / "global.gitconfig"),
                         "PYTHONPATH": str(KIT),
                         "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
                         "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid"})
        self.git("init", "-b", "main")
        self.git("-c", "core.hooksPath=", "commit", "--allow-empty", "-m", "Initial")
        (self.repo / ".workflow-kit.json").write_text(
            json.dumps({"workflowModelVersion": 2, "targetBranch": "main"}), encoding="utf-8")

    def git(self, *args, input=None, check=True):
        return subprocess.run(["git", "-C", str(self.repo), *args], text=True,
                              input=input, capture_output=True, env=self.env, check=check)

    def cli(self, *args):
        result = subprocess.run([sys.executable, "-m", "wfk", *args], cwd=self.base,
                                text=True, capture_output=True, env=self.env)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def install(self, apply=True):
        args = ["hooks", "install", "--repo", str(self.repo), "--json"]
        if apply:
            args.append("--apply")
        return self.cli(*args)

    def test_install_previews_without_writing(self):
        result = self.install(apply=False)
        self.assertEqual(len(result["items"]), 2)
        self.assertFalse((self.repo / ".git/hooks/post-merge").exists())
        self.assertEqual(self.git("config", "--get", "core.hooksPath", check=False).returncode, 1)

    def test_install_is_idempotent_and_preserves_existing_bytes(self):
        hook = self.repo / ".git/hooks/post-merge"
        original = b"#!/bin/sh\nexit 7\n"
        hook.write_bytes(original)
        hook.chmod(0o755)
        # A previous backup belongs to the owner and must never be overwritten.
        backup = hook.with_name("post-merge.wfk-original")
        backup.write_text("owner data", encoding="utf-8")
        first = self.install()
        installed = hook.read_bytes()
        second = self.install()
        self.assertEqual(installed, hook.read_bytes())
        self.assertEqual(backup.read_text(encoding="utf-8"), "owner data")
        item = next(item for item in first["items"] if item["hook"] == "post-merge")
        self.assertEqual(Path(item["backup"]).read_bytes(), original)
        self.assertTrue(all(item["action"] == "unchanged" for item in second["items"]))

    def test_relative_hooks_path_is_respected(self):
        self.git("config", "core.hooksPath", "custom hooks")
        self.install()
        self.assertTrue((self.repo / "custom hooks/post-merge").is_file())
        self.assertEqual(self.git("config", "--get", "core.hooksPath").stdout.strip(), "custom hooks")

    def test_absolute_hooks_path_is_respected(self):
        hooks = self.base / "shared hooks"
        self.git("config", "core.hooksPath", str(hooks))
        self.install()
        self.assertTrue((hooks / "post-rewrite").is_file())
        self.assertEqual(self.git("config", "--get", "core.hooksPath").stdout.strip(), str(hooks))

    def test_public_callback_previews_without_removing_worktree(self):
        worktree = self.base / "preview landed checkout"
        self.git("worktree", "add", "-b", "landed", str(worktree))
        result = self.cli("hooks", "run", "--repo", str(self.repo), "--json")
        self.assertEqual(result["status"], "would-clean")
        self.assertTrue(worktree.is_dir())
        self.assertEqual(self.git("show-ref", "--verify", "refs/heads/landed").returncode, 0)

    def test_public_callback_cleans_only_with_explicit_apply(self):
        worktree = self.base / "apply landed checkout"
        self.git("worktree", "add", "-b", "landed", str(worktree))
        result = self.cli("hooks", "run", "--repo", str(self.repo), "--apply", "--json")
        self.assertEqual(result["status"], "completed")
        self.assertFalse(worktree.exists())

    def test_relative_hooks_path_installs_in_linked_target_and_composes(self):
        target = self.base / "linked target"
        landed = self.base / "linked landed"
        self.git("switch", "-c", "topic")
        self.git("worktree", "add", str(target), "main")
        self.git("worktree", "add", "-b", "landed", str(landed))
        self.git("config", "core.hooksPath", "custom hooks")
        (self.repo / ".git/info/exclude").write_text("custom hooks/\n", encoding="utf-8")
        original = b"#!/bin/sh\nprintf '%s' \"$1\" > previous-hook-ran\nexit 9\n"
        for checkout in (self.repo, target):
            hook = checkout / "custom hooks/post-merge"
            hook.parent.mkdir()
            hook.write_bytes(original)
            hook.chmod(0o755)
        preview = self.install(apply=False)
        self.assertEqual(len(preview["items"]), 6)
        self.assertEqual((target / "custom hooks/post-merge").read_bytes(), original)
        result = self.install()
        self.assertEqual(len(result["items"]), 6)
        for checkout in (self.repo, target):
            self.assertEqual((checkout / "custom hooks/post-merge.wfk-original").read_bytes(), original)
        self.assertEqual(self.git("config", "--get", "core.hooksPath").stdout.strip(), "custom hooks")
        invoked = subprocess.run(["git", "-C", str(target), "hook", "run", "post-merge", "--", "argument with spaces"],
                                 capture_output=True, text=True, env=self.env)
        self.assertEqual(invoked.returncode, 0, invoked.stderr)
        self.assertEqual((target / "previous-hook-ran").read_text(), "argument with spaces")
        self.assertFalse(landed.exists())
        self.assertTrue(target.exists())

    def test_shared_hooks_directory_is_deduplicated_across_checkouts(self):
        worktree = self.base / "shared checkout"
        self.git("worktree", "add", "-b", "topic", str(worktree))
        result = self.install()
        self.assertEqual(len(result["items"]), 2)
        hooks = self.base / "absolute shared hooks"
        self.git("config", "core.hooksPath", str(hooks))
        result = self.install()
        self.assertEqual(len(result["items"]), 2)

    def test_existing_failure_still_preserves_arguments_stdin_and_git_success(self):
        hook = self.repo / ".git/hooks/post-rewrite"
        hook.write_text("#!/bin/sh\nprintf '%s\\n' \"$@\" > hook-args.txt\ncat > hook-input.txt\nexit 9\n", encoding="utf-8")
        hook.chmod(0o755)
        self.install()
        source = self.base / "rewrite input.txt"
        source.write_text("before after\n", encoding="utf-8")
        result = self.git("hook", "run", f"--to-stdin={source}", "post-rewrite", "--", "rebase", "argument with spaces",
                          check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.repo / "hook-args.txt").read_text(), "rebase\nargument with spaces\n")
        self.assertEqual((self.repo / "hook-input.txt").read_text(), "before after\n")

    def test_callback_only_cleans_when_current_checkout_is_target(self):
        from wfk import hooks
        with mock.patch.dict(os.environ, self.env), mock.patch.object(hooks, "_cleanup") as cleanup:
            hooks.run(self.repo, apply=True)
            cleanup.assert_called_once_with(self.repo)
            cleanup.reset_mock()
            self.git("switch", "-c", "topic")
            hooks.run(self.repo, apply=True)
            cleanup.assert_not_called()
            self.git("switch", "--detach")
            hooks.run(self.repo, apply=True)
            cleanup.assert_not_called()

    def test_callback_failure_is_never_a_git_failure(self):
        from wfk import hooks
        with mock.patch.dict(os.environ, self.env), mock.patch.object(hooks, "_cleanup", side_effect=OSError("fixture failure")):
            result = hooks.run(self.repo, apply=True)
        self.assertEqual(result["status"], "skipped")

    def test_callback_accepts_local_target_of_origin_head(self):
        from wfk import hooks
        (self.repo / ".workflow-kit.json").unlink()
        self.git("update-ref", "refs/remotes/origin/main", "HEAD")
        self.git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
        with mock.patch.dict(os.environ, self.env), mock.patch.object(hooks, "_cleanup") as cleanup:
            hooks.run(self.repo, apply=True)
            cleanup.assert_called_once_with(self.repo)

    def test_callback_accepts_configured_short_remote_target(self):
        from wfk import hooks
        self.git('update-ref', 'refs/remotes/origin/main', 'HEAD')
        (self.repo / '.workflow-kit.json').write_text(json.dumps({
            'workflowModelVersion': 2, 'targetBranch': 'origin/main',
        }), encoding='utf-8')
        with mock.patch.dict(os.environ, self.env), mock.patch.object(hooks, '_cleanup') as cleanup:
            hooks.run(self.repo, apply=True)
            cleanup.assert_called_once_with(self.repo)

    def test_installed_hook_cleans_landed_fixture_worktree(self):
        worktree = self.base / "landed checkout"
        self.git("worktree", "add", "-b", "landed", str(worktree))
        hook = self.repo / ".git/hooks/post-merge"
        hook.write_text("#!/bin/sh\nprintf ran > existing-hook-ran\nexit 9\n", encoding="utf-8")
        hook.chmod(0o755)
        self.install()
        result = self.git("hook", "run", "post-merge", "--", "0", check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.repo / "existing-hook-ran").read_text(), "ran")
        self.assertFalse(worktree.exists())
        self.assertNotEqual(self.git("show-ref", "--verify", "refs/heads/landed", check=False).returncode, 0)

    def test_existing_hook_still_runs_when_generated_python_path_is_unavailable(self):
        hook = self.repo / ".git/hooks/post-merge"
        hook.write_text("#!/bin/sh\nprintf ran > existing-hook-ran\nexit 9\n", encoding="utf-8")
        hook.chmod(0o755)
        self.install()
        content = hook.read_text(encoding="utf-8")
        content = content.replace(Path(sys.executable).as_posix(), "/unavailable-wfk-python")
        hook.write_text(content, encoding="utf-8", newline="\n")
        result = self.git("hook", "run", "post-merge", "--", "0", check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.repo / "existing-hook-ran").read_text(), "ran")

    def test_shared_hook_uses_invoking_checkout_for_target_guard(self):
        worktree = self.base / "feature checkout"
        landed = self.base / "landed checkout"
        self.git("worktree", "add", "-b", "feature", str(worktree))
        self.git("worktree", "add", "-b", "landed", str(landed))
        self.install()
        result = subprocess.run(["git", "-C", str(worktree), "hook", "run", "post-merge", "--", "0"],
                                capture_output=True, text=True, env=self.env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(landed.exists())

    @unittest.skipUnless(os.name == "nt", "Windows cmd launcher")
    def test_windows_launcher_works_outside_kit_with_spaces(self):
        launcher = self.copy_launcher("wfk.cmd")
        result = subprocess.run([str(launcher), "wt", "ls", "--repo", str(self.repo), "--json"],
                                cwd=self.base, text=True, capture_output=True, env=self.env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIsInstance(json.loads(result.stdout), dict)

    @unittest.skipIf(os.name == "nt" or not shutil.which("sh"), "POSIX sh launcher")
    def test_posix_launcher_works_outside_kit_with_spaces(self):
        launcher = self.copy_launcher("wfk")
        result = subprocess.run(["sh", str(launcher), "wt", "ls", "--repo", str(self.repo), "--json"],
                                cwd=self.base, text=True, capture_output=True, env=self.env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIsInstance(json.loads(result.stdout), dict)

    def copy_launcher(self, name):
        kit = self.base / "kit copy with spaces"
        shutil.copytree(KIT / "wfk", kit / "wfk", ignore=shutil.ignore_patterns("__pycache__"))
        (kit / "bin").mkdir()
        launcher = kit / "bin" / name
        shutil.copy2(KIT / "bin" / name, launcher)
        return launcher


if __name__ == "__main__":
    unittest.main()
