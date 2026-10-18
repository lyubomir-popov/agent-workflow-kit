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
        self.root = Path(self.temporary.name)
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
        parent.write_text('keep', encoding='utf-8')
        result = prompts.install(apply=True, destinations=[self.destinations[0]])
        self.assertTrue(all(item['action'] == 'kept' for item in result['items']))
        self.assertTrue(result['checklist'])
        self.assertEqual(parent.read_text(encoding='utf-8'), 'keep')

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
    def test_existing_routers_accept_integer_two_without_falling_back_to_legacy(self):
        folder = Path(__file__).resolve().parents[1] / 'prompts'
        for source in sorted(folder.glob('*.prompt.md')):
            content = source.read_text(encoding='utf-8')
            if '## Workflow mode' not in content:
                continue
            with self.subTest(prompt=source.name):
                router = content.split('## Workflow mode', 1)[1].split('## Version 1 route', 1)[0]
                self.assertIn('JSON integer `1` or `2`', router)
                self.assertIn('do not coerce strings', router)
                self.assertIn('versions 1 and 2 must not execute Legacy procedure', router)
                route = content.split('## Version 2 route', 1)[1].split('## Legacy procedure', 1)[0]
                self.assertNotIn('pwsh', route)
                self.assertNotIn('agent-loop.ps1', route)

    def test_v2_routes_use_python_lint_and_honestly_stop_at_pending_scheduler(self):
        folder = Path(__file__).resolve().parents[1] / 'prompts'
        def route(name):
            return (folder / (name + '.prompt.md')).read_text(encoding='utf-8').split(
                '## Version 2 route', 1)[1].split('## Legacy procedure', 1)[0]
        for name in ('audit-workflow', 'run-validation'):
            self.assertIn('wfk lint --repo . --json', route(name))
        self.assertIn('not implemented in slice B', route('overnight'))
        self.assertIn('Do not launch', route('overnight'))
        self.assertIn('prompts/overnight.prompt.md', route('proceed-autonomously'))
        self.assertIn('/whats-next', route('freshen-status'))
        for name in ('orchestrate', 'competing-audit'):
            self.assertIn('config', route(name))
            self.assertIn('slice C', route(name))
            self.assertIn('prompts/review.prompt.md', route(name))

    def test_review_prompt_requires_saved_findings_dispositions_and_owner_gate(self):
        source = Path(__file__).resolve().parents[1] / 'prompts' / 'review.prompt.md'
        content = source.read_text(encoding='utf-8')
        for instruction in (
                'reviews/<date>-<checkpoint>-<reviewer>-findings.md',
                'reviews/<date>-<checkpoint>-<reviewer>-dispositions.md',
                'Reviewer:', 'Reviewed revision:', 'Verdict:',
                '`accept`', '`changes`', '`blocker`',
                'numbered', 'major', 'minor', 'Known limits', 'tasks.md',
                'at most two review rounds', 'owner',
                'only the findings file path and verdict'):
            self.assertIn(instruction, content)
