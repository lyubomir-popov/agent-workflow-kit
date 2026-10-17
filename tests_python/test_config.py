import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from wfk import config


class ConfigTests(unittest.TestCase):
    def test_cleanup_defaults_and_invalid_grace_are_not_silently_accepted(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path = root / 'user.json'
            with patch.dict(os.environ, {'WFK_CONFIG': str(path)}):
                value = config.load()
                self.assertEqual(value['cleanupGraceHours'], 24)
                self.assertIn('develop', value['protectedBranches'])
                self.assertIn('release/*', value['protectedBranches'])
                for raw in ('-1', 'true', '"0"', 'NaN', 'Infinity'):
                    path.write_text('{"cleanupGraceHours":' + raw + '}', encoding='utf-8')
                    with self.assertRaises(ValueError):
                        config.load()
                path.write_text('{"cleanupGraceHours":0,"protectedBranches":["keep/*"]}', encoding='utf-8')
                value = config.load()
                self.assertEqual(value['cleanupGraceHours'], 0)
                self.assertIn('keep/*', value['protectedBranches'])
                self.assertIn('main', value['protectedBranches'])

    def test_repo_paths_and_v1_diagnostics(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / '.workflow-kit.json').write_text(json.dumps({
                'workflowModelVersion': 1, 'targetBranch': 'trunk',
                'managedScratchRoot': '{temp}/old', 'autoLoadedFiles': [],
            }), encoding='utf-8')
            with patch.dict(os.environ, {'WFK_CONFIG': str(root / 'absent')}):
                value = config.load(root)
            self.assertEqual(value['targetBranch'], 'trunk')
            self.assertTrue(any('managedScratchRoot' in s for s in value['warnings']))
            self.assertTrue(any('autoLoadedFiles' in s for s in value['warnings']))

    def test_user_roots_resolve_from_user_config(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            settings = root / 'config.json'
            settings.write_text(json.dumps({'repoRoots': ['projects'],
                                            'scratchRoots': ['scratch']}), encoding='utf-8')
            with patch.dict(os.environ, {'WFK_CONFIG': str(settings)}):
                value = config.load()
            self.assertEqual(value['repoRoots'], [str(root / 'projects')])
            self.assertIn(str(root / 'scratch'), value['scratchRoots'])

    def test_invalid_version_and_malformed_config_fail(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path = root / '.workflow-kit.json'
            with patch.dict(os.environ, {'WFK_CONFIG': str(root / 'absent')}):
                for text in ('{', '[]', '{"workflowModelVersion": true}',
                             '{"workflowModelVersion": 3}'):
                    path.write_text(text, encoding='utf-8')
                    with self.assertRaises(ValueError):
                        config.load(root)

    def test_explicit_missing_target_does_not_fall_back(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            subprocess.run(['git', 'init', '-b', 'main', str(root)], check=True,
                           capture_output=True)
            (root / '.workflow-kit.json').write_text(
                '{"workflowModelVersion":2,"targetBranch":"missing"}', encoding='utf-8')
            with patch.dict(os.environ, {'WFK_CONFIG': str(root / 'absent')}):
                target, source = config.resolve_target(root)
            self.assertIsNone(target)
            self.assertIn('config', source)
