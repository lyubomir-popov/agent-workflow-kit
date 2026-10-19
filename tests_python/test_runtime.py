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

    def test_defaults_restore_unattended_flags_confirmed_probes_and_shared_tiers(self):
        settings = runtime.load(self.repo)
        self.assertEqual(settings['tierModels']['H'], {'model': 'gpt-5.4', 'effort': 'xhigh'})
        self.assertEqual(settings['tierModels']['S'], {'model': 'gpt-5.4', 'effort': 'high'})
        self.assertEqual(settings['tierModels']['L'], {'model': 'gpt-5.4-mini', 'effort': None})
        self.assertIn('--dangerously-bypass-approvals-and-sandbox', settings['workers']['codex']['command'])
        for flag in ('--allow-all', '--no-ask-user', '--autopilot', '--max-autopilot-continues', '-s'):
            self.assertIn(flag, settings['workers']['copilot']['command'])
        self.assertIn('--dangerously-skip-permissions', settings['workers']['claude']['command'])
        self.assertEqual(settings['workers']['codex']['authCommand'], ['codex', 'login', 'status'])
        self.assertEqual(settings['workers']['copilot']['authProtocol'], 'copilot-jsonrpc')
        self.assertIsNone(settings['workers']['claude']['authCommand'])

    def test_shared_tier_effort_is_optional_and_adapter_specific(self):
        settings = runtime.load(self.repo)
        context = dict(prompt='literal & | ^ ü', repo='space path', package='specs/x',
                       task='T001', tier='H', review='task')
        codex = runtime.argv(settings, 'codex', runtime.profile(settings, 'codex'), context)
        self.assertNotIn('--model', codex)
        self.assertIn('model_reasoning_effort="xhigh"', codex)
        copilot = runtime.argv(settings, 'copilot', runtime.profile(settings, 'copilot'), context)
        self.assertIn('--reasoning-effort', copilot)
        self.assertIn('xhigh', copilot)
        context['tier'] = 'L'
        self.assertNotIn('--reasoning-effort', runtime.argv(settings, 'copilot',
                         runtime.profile(settings, 'copilot'), context))
        context['tier'] = 'H'
        claude = runtime.argv(settings, 'claude', runtime.profile(settings, 'claude'), context)
        self.assertNotIn('gpt-5.4', claude)
        self.assertNotIn('--model', claude)

    def test_codex_preserves_legacy_copilot_alias_guard_and_explicit_native_models(self):
        settings = runtime.load(self.repo)
        context = dict(prompt='x', repo='x', package='specs/x', task='T001', tier='L', review='task')
        profile = runtime.profile(settings, 'codex')
        self.assertNotIn('--model', runtime.argv(settings, 'codex', profile, context))
        settings['tierModels']['codex'] = {'L': {'model': 'fixture-codex-model', 'effort': 'low'}}
        result = runtime.argv(settings, 'codex', profile, context)
        self.assertIn('fixture-codex-model', result)
        self.assertIn('model_reasoning_effort="low"', result)

    def test_invalid_shared_tier_and_effort_templates_fail_closed(self):
        context = dict(prompt='x', repo='x', package='specs/x', task='T001', tier='H', review='task')
        settings = self.settings({'tierModels': {'H': {'model': '', 'effort': 'xhigh'}}})
        with self.assertRaises(ValueError):
            runtime.argv(settings, 'codex', runtime.profile(settings, 'codex'), context)
        settings = self.settings({'workers': {'codex': {'effortArgs': 'shell string'}}})
        with self.assertRaises(ValueError):
            runtime.profile(settings, 'codex')

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
