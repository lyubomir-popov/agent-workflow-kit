"""Exercise the public CLI; every Git mutation stays in temporary fixtures."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest


KIT_ROOT = Path(__file__).resolve().parents[1]
ITEM_FIELDS = {
    "kind", "repo", "path", "branch", "commit", "tracked", "untracked",
    "locked", "prunable", "landed", "target", "target_source", "last_commit",
    "size_bytes", "status", "reason",
}


class WorktreeFixtures(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="wfk-fixture-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.config = self.root / "user" / "config.json"
        self.config.parent.mkdir()
        # Most cases test exclusions other than age; the grace regression uses
        # the actual default independently, without waiting a day.
        self.config.write_text('{"cleanupGraceHours":0}', encoding="utf-8")
        self.env = os.environ.copy()
        for name in ("GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE",
                     "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES"):
            self.env.pop(name, None)
        self.env.update({
            "WFK_CONFIG": str(self.config), "PYTHONPATH": str(KIT_ROOT),
            "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_TERMINAL_PROMPT": "0", "GIT_OPTIONAL_LOCKS": "0",
        })

    def git(self, repo, *args, check=True):
        result = subprocess.run(
            ["git", "-C", str(repo), *map(str, args)], env=self.env,
            capture_output=True, text=True, encoding="utf-8",
        )
        if check:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def repo(self, name="repo", branch="main", separate=False):
        path = self.root / name
        path.mkdir(parents=True)
        args = ["init", "-b", branch]
        if separate:
            args += ["--separate-git-dir", str(self.root / (name + "-metadata"))]
        self.git(path, *args)
        self.git(path, "config", "user.name", "Fixture Author")
        self.git(path, "config", "user.email", "fixture@example.invalid")
        self.git(path, "config", "commit.gpgSign", "false")
        self.git(path, "config", "core.autocrlf", "false")
        (path / ".gitignore").write_text("build/\n.workflow-kit.json\n", encoding="utf-8")
        self.commit(path, "base.txt", "base\n")
        return path

    def commit(self, repo, filename, content):
        destination = repo / filename
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(content, encoding="utf-8")
        self.git(repo, "add", "--all")
        self.git(repo, "commit", "-m", "fixture " + filename)
        return self.git(repo, "rev-parse", "HEAD")

    def worktree(self, repo, branch, path=None, start="main"):
        path = path or self.root / "host-native" / branch
        path.parent.mkdir(parents=True, exist_ok=True)
        self.git(repo, "worktree", "add", "-b", branch, path, start)
        return path

    def repo_config(self, repo, **values):
        (repo / ".workflow-kit.json").write_text(
            json.dumps({"workflowModelVersion": 2, **values}), encoding="utf-8")

    def cli(self, cwd, *args, check=True):
        result = subprocess.run(
            [sys.executable, "-m", "wfk", *map(str, args)], cwd=cwd,
            env=self.env, capture_output=True, text=True, encoding="utf-8",
        )
        if check:
            self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        return result

    def items(self, cwd, command="ls", *args):
        payload = json.loads(self.cli(cwd, "wt", command, *args, "--json").stdout)
        self.assertIsInstance(payload, dict)
        self.assertIsInstance(payload["items"], list)
        for item in payload["items"]:
            self.assertTrue(ITEM_FIELDS <= item.keys(), item)
            self.assertIn(item["kind"], {"worktree", "branch", "orphan"})
            for name in ("tracked", "untracked", "locked", "prunable", "landed"):
                self.assertIsInstance(item[name], bool, (name, item))
            if command == "clean":
                self.assertIn(item["action"], {"keep", "remove", "delete-branch", "prune"})
        if command == "clean":
            self.assertEqual(payload["dry_run"], "--apply" not in args)
        return payload["items"]

    def by_path(self, items, path):
        matches = [item for item in items if item["path"] and
                   Path(item["path"]).resolve() == path.resolve()]
        self.assertEqual(len(matches), 1, (path, items))
        return matches[0]

    def assert_kept(self, items, path):
        item = self.by_path(items, path)
        self.assertEqual(item["action"], "keep", item)
        self.assertTrue(item["reason"], item)
        return item

    def snapshot(self, repo):
        """Detect accidental index, ref, object, config or metadata writes."""
        common = Path(self.git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir"))
        return {str(path.relative_to(common)): path.read_bytes()
                for path in common.rglob("*") if path.is_file()}

    def landed(self, repo, style, branch="feature"):
        tree = self.worktree(repo, branch)
        self.commit(tree, "feature.txt", "one\n")
        self.commit(tree, "feature.txt", "one\ntwo\n")
        if style == "ff":
            self.git(repo, "merge", "--ff-only", branch)
        elif style == "merge":
            self.git(repo, "merge", "--no-ff", branch, "-m", "fixture merge")
        elif style == "squash":
            self.git(repo, "merge", "--squash", branch)
            self.git(repo, "commit", "-m", "fixture squash")
        elif style == "rebase":
            self.commit(repo, "target-only.txt", "target diverged\n")
            rebased = self.worktree(repo, "rebased", self.root / "rebase-helper", branch)
            self.git(rebased, "rebase", "main")
            self.git(repo, "merge", "--ff-only", "rebased")
            self.git(repo, "worktree", "remove", rebased)
            self.git(repo, "branch", "-d", "rebased")
        return tree

    def test_new_is_immediate_uses_default_path_and_explicit_start(self):
        repo = self.repo()
        base = self.git(repo, "rev-parse", "HEAD")
        self.commit(repo, "later.txt", "later\n")
        result = json.loads(self.cli(self.root, "wt", "new", "topic", "--from", base,
                                     "--repo", repo, "--json").stdout)
        expected = self.root / "repo-worktrees" / "topic"
        self.assertEqual(Path(result["path"]).resolve(), expected)
        self.assertEqual(result["branch"], "topic")
        self.assertTrue(expected.is_dir())
        self.assertEqual(self.git(expected, "rev-parse", "HEAD"), base)

    def test_new_uses_repo_relative_override_from_linked_checkout(self):
        repo = self.repo()
        self.repo_config(repo, worktreeRoot="../custom-worktrees")
        linked = self.worktree(repo, "caller")
        result = json.loads(self.cli(linked, "wt", "new", "next", "--json").stdout)
        self.assertEqual(Path(result["path"]).resolve(), self.root / "custom-worktrees" / "next")

    def test_standalone_branches_require_opt_in_and_protected_names_survive(self):
        repo = self.repo()
        tree = self.landed(repo, 'ff', 'idle-topic')
        self.git(repo, 'worktree', 'remove', tree)
        names = ('main', 'master', 'develop', 'trunk', 'release/next', 'keep/custom')
        for branch in names[1:]:
            self.git(repo, 'branch', branch)
        self.repo_config(repo, protectedBranches=['keep/*'])
        preview = self.items(repo, 'clean')
        self.assertEqual(next(r for r in preview if r['branch'] == 'idle-topic')['action'], 'keep')
        self.items(repo, 'clean', '--apply')
        self.assertTrue(self.git(repo, 'branch', '--list', 'idle-topic'))
        preview = self.items(repo, 'clean', '--branches')
        self.assertEqual(next(r for r in preview if r['branch'] == 'idle-topic')['action'], 'delete-branch')
        self.assertTrue(self.git(repo, 'branch', '--list', 'idle-topic'))
        self.items(repo, 'clean', '--branches', '--apply')
        self.assertFalse(self.git(repo, 'branch', '--list', 'idle-topic'))
        for branch in names:
            self.assertTrue(self.git(repo, 'branch', '--list', branch), branch)

    def test_brand_new_worktree_and_detached_head_are_kept_by_default_grace(self):
        repo = self.repo()
        self.config.write_text('{}', encoding='utf-8')
        created = json.loads(self.cli(self.root, 'wt', 'new', 'new-agent', '--repo', repo, '--json').stdout)
        path = Path(created['path'])
        detached = self.root / 'fresh-detached'
        self.git(repo, 'worktree', 'add', '--detach', detached, 'HEAD')
        rows = self.items(repo, 'clean', '--apply')
        for checkout in (path, detached):
            row = self.assert_kept(rows, checkout)
            self.assertFalse(row['moved'], row)
            self.assertTrue(row['landed'], row)
            self.assertIn('recent activity', row['reason'])
            self.assertTrue(checkout.is_dir())

    def test_unmoved_landed_existing_branch_and_detached_checkout_expire_after_grace(self):
        self.config.write_text('{}', encoding='utf-8')
        for style in ('existing-branch', 'detached'):
            with self.subTest(style=style):
                repo = self.repo('review-' + style)
                checkout = self.root / (style + '-checkout')
                if style == 'existing-branch':
                    self.git(repo, 'branch', 'review-existing')
                    self.git(repo, 'worktree', 'add', checkout, 'review-existing')
                else:
                    self.git(repo, 'worktree', 'add', '--detach', checkout, 'HEAD')
                fresh = self.assert_kept(self.items(repo, 'clean', '--apply'), checkout)
                self.assertFalse(fresh['moved'])
                self.age_activity(checkout, 2 * 86400, 2 * 86400)
                old = self.by_path(self.items(repo, 'clean', '--apply'), checkout)
                self.assertFalse(old['moved'])
                self.assertEqual(old['action'], 'remove', old)
                self.assertFalse(checkout.exists())

    def age_activity(self, checkout, head_age, admin_age):
        admin = Path(self.git(checkout, 'rev-parse', '--absolute-git-dir'))
        log = admin / 'logs' / 'HEAD'
        timestamp = int(time.time() - head_age)
        entries = []
        for line in log.read_bytes().splitlines():
            header, separator, message = line.partition(b'\t')
            identity, _, zone = header.rsplit(b' ', 2)
            entries.append(identity + b' ' + str(timestamp).encode() + b' ' + zone + separator + message)
        log.write_bytes(b'\n'.join(entries) + b'\n')
        modified = time.time() - admin_age
        os.utime(admin, (modified, modified))

    def test_default_grace_uses_newest_head_activity_and_admin_mtime(self):
        repo = self.repo()
        tree = self.landed(repo, 'ff')
        self.config.write_text('{}', encoding='utf-8')
        old = 2 * 86400
        for head_age, admin_age in ((0, old), (old, 0)):
            self.age_activity(tree, head_age, admin_age)
            row = self.assert_kept(self.items(repo, 'clean', '--apply'), tree)
            self.assertIn('recent activity', row['reason'])
        self.age_activity(tree, old, old)
        self.assertEqual(self.by_path(self.items(repo, 'clean', '--apply'), tree)['action'], 'remove')
        self.assertFalse(tree.exists())

    def test_empty_or_missing_head_reflog_uses_admin_mtime_for_grace(self):
        self.config.write_text('{}', encoding='utf-8')
        for style in ('empty', 'missing'):
            with self.subTest(style=style):
                repo = self.repo('no-log-' + style)
                tree = self.worktree(repo, 'no-log-' + style)
                admin = Path(self.git(tree, 'rev-parse', '--absolute-git-dir'))
                log = admin / 'logs' / 'HEAD'
                if style == 'empty':
                    log.write_bytes(b'')
                else:
                    log.unlink()
                os.utime(admin, None)
                row = self.assert_kept(self.items(repo, 'clean', '--apply'), tree)
                old = time.time() - 2 * 86400
                os.utime(admin, (old, old))
                row = self.by_path(self.items(repo, 'clean', '--apply'), tree)
                self.assertTrue(row['landed'])
                self.assertEqual(row['action'], 'remove', row)
                self.assertFalse(tree.exists())

    def test_all_four_landing_styles_preview_then_remove_ignored_output(self):
        for style in ("ff", "merge", "squash", "rebase"):
            with self.subTest(style=style):
                repo = self.repo(style)
                tree = self.landed(repo, style, "feature-" + style)
                (tree / "build").mkdir()
                (tree / "build" / "output.bin").write_bytes(b"ignored output")
                before = self.snapshot(repo)
                listing = self.items(repo, "ls", "--size")
                row = self.by_path(listing, tree)
                self.assertTrue(row["landed"], row)
                self.assertGreater(row["size_bytes"], 0)
                self.assertTrue(row["last_commit"])
                self.assertEqual(row["target"], "main")
                self.assertTrue(row["target_source"])
                preview = self.items(repo, "clean")
                self.assertEqual(self.by_path(preview, tree)["action"], "remove")
                self.assertTrue(tree.is_dir())
                self.assertEqual(self.snapshot(repo), before, "inventory/dry-run mutated Git metadata")
                applied = self.items(repo, "clean", "--apply")
                self.assertEqual(self.by_path(applied, tree)["action"], "remove")
                self.assertFalse(tree.exists())
                self.assertEqual(self.git(repo, "branch", "--list", "feature-" + style), "")
                self.assertTrue(repo.is_dir())

    def test_commit_after_squash_landing_is_unlanded_and_kept(self):
        repo = self.repo()
        tree = self.landed(repo, "squash")
        tip = self.commit(tree, "unlanded.txt", "valuable later work\n")
        row = self.assert_kept(self.items(repo, "clean", "--apply"), tree)
        self.assertFalse(row["landed"])
        self.assertEqual(self.git(tree, "rev-parse", "HEAD"), tip)

    def test_dirty_untracked_locked_primary_and_unlanded_are_kept(self):
        repo = self.repo()
        dirty = self.worktree(repo, "dirty")
        (dirty / "base.txt").write_text("dirty\n", encoding="utf-8")
        untracked = self.worktree(repo, "untracked")
        (untracked / "valuable.txt").write_text("preserve\n", encoding="utf-8")
        locked = self.worktree(repo, "locked")
        self.git(repo, "worktree", "lock", "--reason", "fixture lock", locked)
        unlanded = self.worktree(repo, "unlanded")
        self.commit(unlanded, "unlanded.txt", "preserve\n")
        rows = self.items(repo, "clean", "--apply")
        for path in (repo, dirty, untracked, locked, unlanded):
            self.assert_kept(rows, path)
            self.assertTrue(path.is_dir())
        self.assertTrue(self.by_path(rows, dirty)["tracked"])
        self.assertTrue(self.by_path(rows, untracked)["untracked"])
        self.assertTrue(self.by_path(rows, locked)["locked"])
        self.assertEqual((untracked / "valuable.txt").read_text(encoding="utf-8"), "preserve\n")

    def test_current_linked_checkout_and_unlanded_detached_are_kept(self):
        repo = self.repo()
        current = self.worktree(repo, "current")
        detached = self.worktree(repo, "detached-source")
        self.commit(detached, "detached.txt", "preserve\n")
        self.git(detached, "checkout", "--detach")
        rows = self.items(current, "clean", "--apply")
        self.assert_kept(rows, current)
        self.assert_kept(rows, detached)

    def test_unavailable_registered_worktree_is_preserved(self):
        repo = self.repo()
        tree = self.worktree(repo, "unavailable")
        # Simulate an unavailable mount without deleting any fixture data.
        moved = tree.with_name("temporarily-unmounted")
        tree.rename(moved)
        before = self.git(repo, "worktree", "list", "--porcelain")
        row = self.assert_kept(self.items(repo, "clean", "--apply"), tree)
        self.assertTrue(row["prunable"])
        self.assertEqual(self.git(repo, "worktree", "list", "--porcelain"), before)
        self.assertTrue(moved.is_dir())

    def test_unknown_target_never_lands_or_deletes(self):
        repo = self.repo(branch="trunk")
        tree = self.worktree(repo, "feature", start="trunk")
        row = self.assert_kept(self.items(repo, "clean", "--apply"), tree)
        self.assertFalse(row["landed"])
        self.assertFalse(row["target"])

    def test_target_priority_and_v1_ignored_field_warning(self):
        repo = self.repo()
        self.git(repo, "branch", "release")
        self.git(repo, "update-ref", "refs/remotes/origin/remote-default", "HEAD")
        self.git(repo, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/remote-default")
        self.assertEqual(self.by_path(self.items(repo), repo)["target"], "origin/remote-default")
        (repo / ".workflow-kit.json").write_text(json.dumps({
            "workflowModelVersion": 1, "targetBranch": "release", "autoLoadedFiles": [],
        }), encoding="utf-8")
        result = self.cli(repo, "wt", "ls", "--json")
        row = self.by_path(json.loads(result.stdout)["items"], repo)
        self.assertEqual(row["target"], "release")
        self.assertIn("autoLoadedFiles", result.stderr)

    def test_landed_local_branch_without_checkout_is_listed_and_deleted(self):
        repo = self.repo()
        tree = self.landed(repo, 'ff', 'landed-idle')
        self.git(repo, 'worktree', 'remove', tree)
        rows = self.items(repo)
        branch = [row for row in rows if row["kind"] == "branch" and row["branch"] == "landed-idle"]
        self.assertEqual(len(branch), 1)
        self.assertTrue(branch[0]["landed"])
        preview = self.items(repo, "clean", '--branches')
        self.assertEqual(next(row for row in preview if row["branch"] == "landed-idle")["action"],
                         "delete-branch")
        self.assertTrue(self.git(repo, "branch", "--list", "landed-idle"))
        self.items(repo, "clean", '--branches', "--apply")
        self.assertEqual(self.git(repo, "branch", "--list", "landed-idle"), "")

    def test_multiple_roots_and_user_roots_discover_git_metadata_locations(self):
        first = self.repo("projects/first")
        second = self.repo("more/second", separate=True)
        # Separate Git metadata path need not share a checkout naming convention.
        foreign = self.worktree(first, "external", self.root / "arbitrary" / "checkout")
        nested = self.worktree(second, "nested", second / ".claude" / "worktrees" / "nested")
        rows = self.items(self.root, "ls", "--root", self.root / "projects",
                          "--root", self.root / "more", "--root", foreign)
        for path in (first, second, foreign, nested):
            self.by_path(rows, path)
        self.assertEqual(len([row for row in rows if row["kind"] == "worktree"]), 4)
        self.config.write_text(json.dumps({"workflowModelVersion": 2,
                                          "repoRoots": ["../projects", "../more"]}), encoding="utf-8")
        configured = self.items(self.root)
        self.assertEqual({str(Path(row["path"]).resolve()) for row in configured if row["kind"] == "worktree"},
                         {str(path.resolve()) for path in (first, second, foreign, nested)})

    def test_remote_target_preserves_local_target_branch_from_detached_primary(self):
        for index, explicit in enumerate((False, True)):
            with self.subTest(explicit_config=explicit):
                repo = self.repo('remote-target-' + str(index))
                tree = self.landed(repo, 'ff', 'landed-idle')
                self.git(repo, 'worktree', 'remove', tree)
                self.git(repo, 'update-ref', 'refs/remotes/origin/main', 'HEAD')
                self.git(repo, 'symbolic-ref', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/main')
                if explicit:
                    self.repo_config(repo, targetBranch='refs/remotes/origin/main')
                self.git(repo, 'checkout', '--detach')
                preview = self.items(repo, 'clean', '--branches')
                target = next(row for row in preview if row['kind'] == 'branch' and row['branch'] == 'main')
                self.assertEqual(target['action'], 'keep', target)
                self.items(repo, 'clean', '--branches', '--apply')
                self.assertTrue(self.git(repo, 'branch', '--list', 'main'))
                self.assertFalse(self.git(repo, 'branch', '--list', 'landed-idle'))

    def test_nested_repository_inside_linked_checkout_is_discovered(self):
        repo = self.repo()
        linked = self.worktree(repo, 'container')
        nested = self.repo('host-native/container/independent')
        rows = self.items(self.root, 'ls', '--root', linked)
        for path in (repo, linked, nested):
            self.by_path(rows, path)

    def test_orphan_without_git_owner_is_reported_and_preserved(self):
        repo = self.repo()
        scratch = self.root / "scratch"
        orphan = scratch / "abandoned"
        orphan.mkdir(parents=True)
        (orphan / ".git").write_text("gitdir: " + str(self.root / "missing" / "worktrees" / "abandoned") + "\n",
                                     encoding="utf-8")
        (orphan / 'local-notes.txt').write_text('preserve this', encoding='utf-8')
        self.repo_config(repo, scratchRoots=[str(scratch)])
        row = self.by_path(self.items(repo), orphan)
        self.assertEqual(row["kind"], "orphan")
        self.assertIsInstance(row['size_bytes'], int)
        self.assertGreater(row['size_bytes'], 0)
        self.assert_kept(self.items(repo, "clean", "--apply"), orphan)
        preview = self.items(repo, "clean", "--orphans")
        self.assert_kept(preview, orphan)
        self.assertTrue(orphan.is_dir())
        # FR-014 forbids a recursive deletion fallback. Without a Git owner,
        # explicit opt-in still cannot make `git worktree remove` possible.
        self.assert_kept(self.items(repo, "clean", "--orphans", "--apply"), orphan)
        self.assertTrue(orphan.is_dir())


if __name__ == "__main__":
    unittest.main()
