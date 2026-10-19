"""Retirement regressions for the repository's tracked portable pre-commit hook."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


KIT = Path(__file__).resolve().parents[1]


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
