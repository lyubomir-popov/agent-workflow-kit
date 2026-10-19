import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from wfk import prompts


class PromptInstallationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.destinations = [self.root / 'Code' / 'prompts',
                             self.root / 'Code - Insiders' / 'prompts']
        self.sources = sorted((Path(__file__).resolve().parents[1] / 'prompts').glob('*.prompt.md'))

    def test_preview_creates_nothing_and_lists_every_shipped_prompt_for_both_hosts(self):
        result = prompts.install(destinations=self.destinations)
        self.assertTrue(result['dry_run'])
        self.assertEqual(len(result['items']), len(self.sources) * 2)
        self.assertTrue(all(item['action'] == 'would-install' for item in result['items']))
        self.assertEqual({item['path'] for item in result['items']},
                         {str(folder / source.name) for folder in self.destinations
                          for source in self.sources})
        self.assertFalse(any(folder.exists() for folder in self.destinations))

    def test_apply_copies_sources_exactly_and_repeat_is_unchanged(self):
        result = prompts.install(apply=True, destinations=self.destinations)
        self.assertFalse(result['dry_run'])
        self.assertTrue(all(item['action'] == 'install' for item in result['items']))
        for folder in self.destinations:
            for source in self.sources:
                self.assertEqual((folder / source.name).read_bytes(), source.read_bytes())
        repeated = prompts.install(apply=True, destinations=self.destinations)
        self.assertTrue(all(item['action'] == 'unchanged' for item in repeated['items']))

    def test_existing_different_prompt_is_previewed_before_explicit_replacement(self):
        folder = self.destinations[0]
        folder.mkdir(parents=True)
        target = folder / self.sources[0].name
        target.write_text('user customization', encoding='utf-8')
        unrelated = folder / 'personal.prompt.md'
        unrelated.write_text('keep', encoding='utf-8')
        result = prompts.install(destinations=[folder])
        item = next(item for item in result['items'] if item['path'] == str(target))
        self.assertEqual(item['action'], 'would-rewrite')
        self.assertEqual(target.read_text(encoding='utf-8'), 'user customization')
        self.assertTrue(any('--apply' in warning for warning in result['warnings']))
        result = prompts.install(apply=True, destinations=[folder])
        item = next(item for item in result['items'] if item['path'] == str(target))
        self.assertEqual(item['action'], 'rewrite')
        self.assertEqual(target.read_bytes(), self.sources[0].read_bytes())
        self.assertEqual(unrelated.read_text(encoding='utf-8'), 'keep')

    def test_nonfile_collision_is_preserved_with_manual_instructions(self):
        target = self.destinations[0] / self.sources[0].name
        target.mkdir(parents=True)
        (target / 'owner-note').write_text('keep', encoding='utf-8')
        result = prompts.install(apply=True, destinations=[self.destinations[0]])
        item = next(item for item in result['items'] if item['path'] == str(target))
        self.assertEqual(item['action'], 'kept')
        self.assertTrue(result['warnings'])
        self.assertTrue(result['checklist'])
        self.assertEqual((target / 'owner-note').read_text(encoding='utf-8'), 'keep')

    def test_parent_file_collision_does_not_create_or_rewrite_anything(self):
        parent = self.root / 'Code'
        original = b'owner parent file\r\n\x00\xff'
        parent.write_bytes(original)
        result = prompts.install(apply=True, destinations=[self.destinations[0]])
        self.assertTrue(all(item['action'] == 'kept' for item in result['items']))
        self.assertTrue(all(str(parent) in warning and 'collision' in warning
                            for warning in result['warnings']))
        self.assertTrue(all('Manually' in item and str(parent) in item
                            for item in result['checklist']))
        self.assertEqual(parent.read_bytes(), original)

    def test_linked_parent_is_preserved_instead_of_followed(self):
        destination = self.destinations[0]
        outside = self.root / 'outside'
        outside.mkdir()
        destination.parent.mkdir()
        try:
            destination.symlink_to(outside, target_is_directory=True)
        except OSError:
            self.skipTest('symlink creation unavailable on this host')
        result = prompts.install(apply=True, destinations=[destination])
        self.assertTrue(all(item['action'] == 'kept' for item in result['items']))
        self.assertEqual(list(outside.iterdir()), [])

    def test_symlink_collision_is_preserved_even_with_apply(self):
        folder = self.destinations[0]
        folder.mkdir(parents=True)
        original = self.root / 'original'
        original.write_text('keep', encoding='utf-8')
        target = folder / self.sources[0].name
        try:
            target.symlink_to(original)
        except OSError:
            self.skipTest('symlink creation unavailable on this host')
        result = prompts.install(apply=True, destinations=[folder])
        self.assertEqual(next(item['action'] for item in result['items']
                              if item['path'] == str(target)), 'kept')
        self.assertTrue(target.is_symlink())
        self.assertEqual(original.read_text(encoding='utf-8'), 'keep')

    def test_platform_destinations_use_user_config_locations(self):
        home = self.root / 'home'
        cases = [
            ('win32', {'APPDATA': str(self.root / 'roaming')}, self.root / 'roaming'),
            ('win32', {}, home / 'AppData' / 'Roaming'),
            ('darwin', {}, home / 'Library' / 'Application Support'),
            ('linux', {'XDG_CONFIG_HOME': str(self.root / 'xdg')}, self.root / 'xdg'),
            ('linux', {}, home / '.config'),
        ]
        for platform, environment, config in cases:
            with self.subTest(platform=platform, environment=environment):
                with patch.object(prompts.sys, 'platform', platform), \
                        patch.object(Path, 'home', return_value=home), \
                        patch.dict(os.environ, environment, clear=True):
                    self.assertEqual(prompts.default_destinations(),
                                     [config / 'Code' / 'User' / 'prompts',
                                      config / 'Code - Insiders' / 'User' / 'prompts'])

    def test_explicit_empty_destinations_do_not_fall_back_to_user_install(self):
        result = prompts.install(apply=True, destinations=[])
        self.assertEqual(result['items'], [])


class SavedReviewPromptTests(unittest.TestCase):
    def setUp(self):
        self.folder = Path(__file__).resolve().parents[1] / 'prompts'
        self.sources = sorted(self.folder.glob('*.prompt.md'))

    def prompt(self, name):
        return (self.folder / (name + '.prompt.md')).read_text(encoding='utf-8')

    def test_shipped_prompts_fail_closed_and_route_supported_configs_to_python(self):
        retired = ('Legacy procedure', 'Version 1 route', 'Version 2 route',
                   'agent-loop.ps1', 'workflow-kit.ps1', 'pwsh',
                   'canonicalMirrorMode', 'TierDispatchMap')
        for source in self.sources:
            content = source.read_text(encoding='utf-8')
            with self.subTest(prompt=source.name):
                self.assertIn('## Workflow routing', content)
                self.assertIn('JSON integer `2`', content)
                self.assertIn('JSON integer `1`', content)
                self.assertIn('wfk lint --repo . --json', content)
                self.assertIn('wfk init --repo . --json', content)
                self.assertIn('ignored-v1-field diagnostics', content)
                self.assertIn('non-integer version', content)
                self.assertIn('unsupported', content)
                self.assertIn('fail closed', content)
                self.assertIn('v1-powershell', content)
                self.assertIn('agent: agent', content)
                self.assertNotIn('\nmode:', content)
                self.assertNotIn('\nmodel:', content)
                for phrase in retired:
                    self.assertNotIn(phrase, content)

    def test_python_routes_keep_bounded_scheduler_and_owner_gates(self):
        overnight = self.prompt('overnight')
        self.assertIn('wfk run --repo . --package', overnight)
        self.assertIn('--apply', overnight)
        self.assertIn('Authentication probes fail closed', overnight)
        self.assertIn('explicit package', overnight)
        self.assertIn('permission flags do not authorize', overnight)
        self.assertIn('two rounds', overnight)
        self.assertIn('printed report path', overnight)

        proceed = self.prompt('proceed-autonomously')
        self.assertIn('prompts/overnight.prompt.md', proceed)
        self.assertIn('explicit package', proceed)
        self.assertIn('--apply', proceed)

        orchestrate = self.prompt('orchestrate')
        self.assertIn('templates/scheduler-defaults.json', orchestrate)
        self.assertIn('copilot-opus', orchestrate)
        self.assertIn('claude-opus-4.8', orchestrate)
        self.assertIn('prompts/review.prompt.md', orchestrate)
        self.assertIn('two rounds', orchestrate)

    def test_audit_orientation_and_validation_preserve_workflow_ownership(self):
        audit = self.prompt('audit-workflow')
        self.assertIn('wfk lint --repo . --json', audit)
        self.assertIn('Preserve', audit)
        self.assertIn('unresolved inbox handoffs', audit)

        whats_next = self.prompt('whats-next')
        self.assertIn('without deleting, emptying or blindly', whats_next)
        self.assertIn('declared branch', whats_next)
        self.assertIn('first incomplete task', whats_next)

        validation = self.prompt('run-validation')
        self.assertIn('wfk lint --repo . --json', validation)
        self.assertIn('does not authorize edits', validation)

    def test_review_prompt_requires_saved_findings_dispositions_and_owner_gate(self):
        content = self.prompt('review')
        for instruction in (
                'reviews/<date>-<checkpoint>-<reviewer>-findings.md',
                'reviews/<date>-<checkpoint>-<reviewer>-dispositions.md',
                'Reviewer:', 'Reviewed revision:', 'Verdict:',
                '`accept`', '`changes`', '`blocker`',
                'numbered', '`major`', '`minor`', '`Known limits`',
                'at most two review rounds', 'owner clears',
                'only the findings file path and verdict'):
            self.assertIn(instruction, content)
