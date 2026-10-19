"""Retirement regressions for the repository's tracked portable pre-commit hook."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


KIT = Path(__file__).resolve().parents[1]


class VendorAssetTests(unittest.TestCase):
    def test_spec_kit_assets_do_not_reference_retired_kit_scripts(self):
        retired = (
            'agent-loop.ps1', 'install-vscode-prompts.ps1',
            'workflow-checks.ps1', 'workflow-closeout.ps1', 'workflow-hook.ps1',
            'workflow-kit.ps1', 'workflow-migration.ps1', 'workflow-model.ps1',
            'workflow-preservation.ps1', 'workflow-scheduler.ps1',
            'bin/agent-loop', 'bin/workflow-kit', 'bin/install-vscode-prompts',
        )
        references = []
        for path in (KIT / '.specify').rglob('*'):
            if path.is_file():
                content = path.read_bytes().decode('utf-8', errors='replace')
                content = content.replace('\\', '/').lower()
                references.extend(f'{path.relative_to(KIT)}: {name}'
                                  for name in retired if name in content)
        self.assertEqual(references, [], '\n'.join(references))


class RetirementTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='wfk retirement ')
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name) / 'fixture repo'
        self.repo.mkdir()
        self.env = dict(os.environ,
            WFK_CONFIG=str(Path(self.temp.name) / 'absent-user-config.json'),
            GIT_CONFIG_NOSYSTEM='1',
            GIT_CONFIG_GLOBAL=os.devnull,
            GIT_AUTHOR_NAME='Fixture',
            GIT_AUTHOR_EMAIL='fixture@example.invalid',
            GIT_COMMITTER_NAME='Fixture',
            GIT_COMMITTER_EMAIL='fixture@example.invalid')
        self.git('init', '-b', 'main')
        (self.repo / '.workflow-kit.json').write_text(json.dumps({
            'workflowModelVersion': 2,
            'targetBranch': 'main',
            'autoLoadedFiles': [],
            'hostBudgets': [],
        }), encoding='utf-8')
        (self.repo / 'docs').mkdir()
        (self.repo / 'docs/specs.md').write_text(
            '# Catalog\n\n## Current packages\n\n| Spec | Package | Branch |\n|---|---|---|\n',
            encoding='utf-8')
        (self.repo / 'AGENTS.md').write_text('# Fixture instructions\n', encoding='utf-8')
        (self.repo / 'bin').mkdir()
        shutil.copy2(KIT / 'bin/wfk', self.repo / 'bin/wfk')
        shutil.copytree(KIT / 'wfk', self.repo / 'wfk',
                        ignore=shutil.ignore_patterns('__pycache__'))
        self.git('add', '.')
        self.git('-c', 'core.hooksPath=', 'commit', '-m', 'fixture')
        hook = self.repo / '.git/hooks/pre-commit'
        shutil.copy2(KIT / '.githooks/pre-commit', hook)
        hook.chmod(0o755)

    def git(self, *args, check=True):
        return subprocess.run(['git', '-C', str(self.repo), *args], env=self.env,
                              capture_output=True, text=True, check=check)

    @unittest.skipUnless(shutil.which('pwsh'), 'vendor scripts require PowerShell 7')
    def test_vendor_prerequisites_resolve_cursor_without_retired_kit(self):
        self.git('checkout', '-b', 'feat/003-vendor-fixture')
        scripts = self.repo / '.specify/scripts/powershell'
        shutil.copytree(KIT / '.specify/scripts/powershell', scripts)
        feature = self.repo / 'specs/003-vendor-fixture'
        feature.mkdir(parents=True)
        for name in ('spec.md', 'plan.md', 'tasks.md'):
            (feature / name).write_text('# Fixture\n', encoding='utf-8')
        (self.repo / '.specify/feature.json').write_text(json.dumps({
            'feature_directory': 'specs/003-vendor-fixture',
        }), encoding='utf-8')
        env = self.env.copy()
        env.pop('SPECIFY_FEATURE', None)
        env.pop('SPECIFY_FEATURE_DIRECTORY', None)
        command = [shutil.which('pwsh'), '-NoProfile', '-File',
                   str(scripts / 'check-prerequisites.ps1'), '-Json']
        for flags in (['-PathsOnly'], ['-RequireTasks', '-IncludeTasks']):
            with self.subTest(flags=flags):
                result = subprocess.run(command + flags, cwd=self.repo, env=env,
                                        capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                data = json.loads(result.stdout)
                self.assertEqual(Path(data['FEATURE_DIR']).resolve(), feature.resolve())
                if '-RequireTasks' in flags:
                    self.assertIn('tasks.md', data['AVAILABLE_DOCS'])

    def test_tracked_hook_allows_clean_lint_and_refuses_lint_error(self):
        tracked = (KIT / '.githooks/pre-commit').read_text(encoding='utf-8')
        self.assertIn('"$repo/bin/wfk" lint', tracked)
        self.assertNotIn('pwsh', tracked)
        valid = self.repo / 'valid.txt'
        valid.write_text('valid\n', encoding='utf-8')
        self.git('add', 'valid.txt')
        passed = self.git('commit', '-m', 'valid change', check=False)
        self.assertEqual(passed.returncode, 0, passed.stdout + passed.stderr)
        accepted_head = self.git('rev-parse', 'HEAD').stdout.strip()

        (self.repo / 'AGENTS.md').write_text(
            '# Fixture instructions\n<!-- MANUAL ADDITIONS START -->\n', encoding='utf-8')
        self.git('add', 'AGENTS.md')
        refused = self.git('commit', '-m', 'invalid change', check=False)

        self.assertNotEqual(refused.returncode, 0, refused.stdout + refused.stderr)
        self.assertIn('AGENTS.md: feature state or vendor marker',
                      refused.stdout + refused.stderr)
        self.assertEqual(self.git('rev-parse', 'HEAD').stdout.strip(), accepted_head)
        self.assertIn('AGENTS.md', self.git('diff', '--cached', '--name-only').stdout.splitlines())


if __name__ == '__main__':
    unittest.main()
