"""Declarative adapters and tier settings cannot smuggle shell commands."""
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from wfk import runtime


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        env = patch.dict(os.environ, {'WFK_CONFIG': str(self.repo / 'user.json')})
        env.start()
        self.addCleanup(env.stop)

    def settings(self, value):
        (self.repo / '.workflow-kit.json').write_text(json.dumps(value))
        return runtime.load(self.repo)

    def test_defaults_have_three_adapters_and_unverified_auth(self):
        settings = runtime.load(self.repo)
        for name in ('codex', 'copilot', 'claude'):
            profile = runtime.profile(settings, name)
            with self.assertRaisesRegex(ValueError, 'unverified'):
                runtime.argv(settings, name, profile, {}, auth=True)

    def test_v1_ignores_scheduler_fields_and_v2_merges_user_then_repo(self):
        (self.repo / 'user.json').write_text(json.dumps({'workers': {'fixture': {
            'command': [sys.executable], 'authCommand': [sys.executable, '-V']}}}))
        settings = self.settings({'workflowModelVersion': 1, 'workers': {'fixture': {'command': ['bad']}}})
        self.assertEqual(settings['workers']['fixture']['command'], [sys.executable])
        self.assertTrue(settings['warnings'])
        settings = self.settings({'workflowModelVersion': 2, 'workers': {'fixture': {'input': 'argv'}}})
        self.assertEqual(runtime.profile(settings, 'fixture')['input'], 'argv')

    def test_models_have_one_owner_and_argv_preserves_special_characters(self):
        settings = self.settings({'tierModels': {'codex': {'H': 'test-model'}},
            'workers': {'codex': {'modelArgs': ['--model', '{model}']}}})
        profile = runtime.profile(settings, 'codex')
        context = dict(prompt='x; $(never) " ü', repo='space path', package='specs/x',
                       task='T001', tier='H', review='task')
        self.assertEqual(runtime.argv(settings, 'codex', profile, context)[-2:], ['--model', 'test-model'])
        settings['workers']['codex']['command'] = ['fake', '{prompt}']
        self.assertEqual(runtime.argv(settings, 'codex', settings['workers']['codex'], context)[1], context['prompt'])

    def test_invalid_templates_codes_limits_and_auth_probe_are_rejected(self):
        for data in ({'command': 'shell string'}, {'command': ['fake', '{bad}']},
                     {'authCommand': ['fake', '{prompt}']}, {'quotaExitCodes': [0]},
                     {'authPatterns': ['']}, {'input': 'shell'}):
            with self.subTest(data=data):
                settings = self.settings({'workers': {'fake': dict(command=['fake'], **data)}}) if 'command' not in data else self.settings({'workers': {'fake': data}})
                with self.assertRaises(ValueError):
                    runtime.profile(settings, 'fake')
        for value in (float('inf'), float('nan'), True, -1):
            with self.assertRaises(ValueError):
                self.settings({'scheduler': {'authTimeout': value}})

    def test_log_patterns_only_classify_failed_processes(self):
        log = self.repo / 'log'
        log.write_text('quoted AUTH FAILURE\nquota exhausted\n')
        result = dict(returncode=0, timed_out=False, interrupted=False, log=str(log))
        profile = {'authPatterns': ['auth failure'], 'quotaPatterns': ['quota exhausted']}
        self.assertIsNone(runtime.failure(profile, result))
        result['returncode'] = 2
        self.assertEqual(runtime.failure(profile, result), 'auth')
        result['timed_out'] = True
        self.assertEqual(runtime.failure(profile, result), 'timeout')


if __name__ == '__main__':
    unittest.main()
