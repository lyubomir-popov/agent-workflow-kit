"""Adoption and package transactions mutate temporary Git repositories only."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from wfk import adoption


class AdoptionFixtures(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='wfk-adoption-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        (self.root / 'user-config.json').write_text('{"targetBranch":"trunk"}', encoding='utf-8')
        environment = dict(os.environ, GIT_CONFIG_NOSYSTEM='1',
                           GIT_CONFIG_GLOBAL=os.devnull,
                           WFK_CONFIG=str(self.root / 'user-config.json'))
        for key in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE',
                    'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES'):
            environment.pop(key, None)
        self.environ = patch.dict(os.environ, environment, clear=True)
        self.environ.start()
        self.addCleanup(self.environ.stop)
        make_temporary = tempfile.mkdtemp
        self.scratch = patch.object(adoption.tempfile, 'mkdtemp',
                                   side_effect=lambda **kw: make_temporary(dir=self.root, **kw))
        self.scratch.start()
        self.addCleanup(self.scratch.stop)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.git('init', '-b', 'trunk')
        self.git('config', 'user.name', 'Fixture Author')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'commit.gpgSign', 'false')
        self.git('config', 'core.autocrlf', 'false')
        (self.repo / 'README.md').write_bytes(b'owner README\r\n')
        self.git('add', '--', 'README.md')
        self.git('commit', '-m', 'fixture: base')

    def git(self, *args, repo=None, check=True):
        result = subprocess.run(['git', '-C', str(repo or self.repo), *map(str, args)],
                                capture_output=True, text=True, encoding='utf-8')
        if check:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def snapshot(self):
        return {p.relative_to(self.repo).as_posix(): p.read_bytes()
                for p in self.repo.rglob('*') if p.is_file() and '.git' not in p.parts}

    def initialize(self):
        result = adoption.initialize(self.repo, apply=True)
        self.git('add', '--', *self.snapshot())
        self.git('commit', '-m', 'fixture: adopt')
        return result

    def test_init_preview_changes_neither_files_nor_git(self):
        before, head = self.snapshot(), self.git('rev-parse', 'HEAD')
        result = adoption.initialize(self.repo)
        self.assertTrue(result['dry_run'])
        self.assertTrue(result['items'])
        self.assertIsInstance(result['checklist'], list)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.git('rev-parse', 'HEAD'), head)
        self.assertEqual(self.git('status', '--porcelain'), '')

    def test_init_adds_portable_owners_and_templates_without_a_commit(self):
        head = self.git('rev-parse', 'HEAD')
        result = adoption.initialize(self.repo, apply=True)
        settings = json.loads((self.repo / '.workflow-kit.json').read_text())
        self.assertEqual(settings['workflowModelVersion'], 2)
        self.assertEqual(settings['targetBranch'], 'trunk')
        for name in ('AGENTS.md', 'INBOX.md', 'AGENT-INBOX.md', 'docs/specs.md',
                     '.specify/templates/overrides/spec-template.md',
                     '.specify/templates/overrides/plan-template.md',
                     '.specify/templates/overrides/tasks-template.md'):
            self.assertTrue((self.repo / name).is_file(), name)
        self.assertIn('wfk wt new', (self.repo / 'AGENTS.md').read_text())
        self.assertFalse(result['dry_run'])
        self.assertEqual(self.git('rev-parse', 'HEAD'), head)
        self.assertEqual((self.repo / 'README.md').read_bytes(), b'owner README\r\n')

    def test_init_preserves_every_existing_file_and_lists_manual_merges(self):
        existing = {
            'AGENTS.md': b'owner instructions\r\n', 'INBOX.md': b'unread\n',
            'CLAUDE.md': b'owner Claude guidance\r\n',
            '.github/copilot-instructions.md': b'owner Copilot guidance\r\n',
            'AGENT-INBOX.md': b'unresolved\n', 'docs/specs.md': b'owner catalog\n',
            '.workflow-kit.json': b'{"workflowModelVersion":1,"targetBranch":"trunk"}\n',
            '.specify/templates/overrides/spec-template.md': b'custom template\n',
        }
        for name, content in existing.items():
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        before = self.snapshot()
        result = adoption.initialize(self.repo, apply=True)
        for name, content in before.items():
            self.assertEqual((self.repo / name).read_bytes(), content, name)
        checklist = '\n'.join(result['checklist'])
        for name in existing:
            self.assertIn(name, checklist)
        second = self.snapshot()
        adoption.initialize(self.repo, apply=True)
        self.assertEqual(self.snapshot(), second)

    def test_init_preserves_oversized_agents_and_lint_rejects_200_lines(self):
        from wfk.workflow import lint
        original = b'Owner instructions\r\n' * 200
        (self.repo / 'AGENTS.md').write_bytes(original)
        adoption.initialize(self.repo, apply=True)
        self.assertEqual((self.repo / 'AGENTS.md').read_bytes(), original)
        before = self.snapshot()
        errors = lint(self.repo)['errors']
        self.assertTrue(any('AGENTS.md' in error and 'lines budget exceeded' in error
                            for error in errors), errors)
        self.assertEqual(self.snapshot(), before)

    def test_init_declares_default_instruction_and_host_limits_and_lints_clean(self):
        from wfk.workflow import lint
        adoption.initialize(self.repo, apply=True)
        settings = json.loads((self.repo / '.workflow-kit.json').read_text())
        budgets = {item['path']: item for item in settings['autoLoadedFiles']}
        for name, lines, size in (('AGENTS.md', 100, 12288),
                                  ('CLAUDE.md', 15, 2048),
                                  ('.github/copilot-instructions.md', 15, 2048)):
            self.assertEqual(budgets[name]['lines'], lines)
            self.assertEqual(budgets[name]['bytes'], size)
            self.assertEqual(budgets[name]['loading'], 'full')
            self.assertTrue((self.repo / name).is_file(), name)
        hosts = {item['host']: item for item in settings['hostBudgets']}
        self.assertEqual(set(hosts), {'copilot-chat', 'copilot-cli', 'codex', 'claude-code'})
        for host in hosts.values():
            self.assertEqual((host['lines'], host['bytes']), (150, 16384))
        self.assertEqual(set(budgets['AGENTS.md']['hosts']), set(hosts))
        self.assertEqual(set(budgets['CLAUDE.md']['hosts']), {'claude-code', 'copilot-chat'})
        self.assertEqual(set(budgets['.github/copilot-instructions.md']['hosts']),
                         {'copilot-chat', 'copilot-cli'})
        self.assertEqual(lint(self.repo)['errors'], [])

    def test_init_existing_config_checklist_names_missing_budget_fields(self):
        path = self.repo / '.workflow-kit.json'
        original = b'{"workflowModelVersion":2,"targetBranch":"trunk"}\r\n'
        path.write_bytes(original)
        for apply in (False, True):
            with self.subTest(apply=apply):
                result = adoption.initialize(self.repo, apply=apply)
                checklist = '\n'.join(result['checklist'])
                self.assertIn('autoLoadedFiles', checklist)
                self.assertIn('hostBudgets', checklist)
                self.assertEqual(path.read_bytes(), original)

    def assert_init_preserves_invalid_config(self, content):
        config = self.repo / '.workflow-kit.json'
        config.write_bytes(content)
        (self.repo / 'AGENTS.md').write_bytes(b'owner guidance\r\n')
        existing = self.snapshot()
        user_config = (self.root / 'user-config.json').read_bytes()
        refs, head = self.git('show-ref'), self.git('rev-parse', 'HEAD')
        preview = adoption.initialize(self.repo)
        self.assertTrue(preview['dry_run'])
        self.assertEqual(self.snapshot(), existing)
        result = adoption.initialize(self.repo, apply=True)
        for name, original in existing.items():
            self.assertEqual((self.repo / name).read_bytes(), original, name)
        for name in ('docs/specs.md', 'INBOX.md', 'AGENT-INBOX.md',
                     '.specify/templates/overrides/spec-template.md',
                     '.specify/templates/overrides/plan-template.md',
                     '.specify/templates/overrides/tasks-template.md'):
            self.assertTrue((self.repo / name).is_file(), name)
        self.assertIn('.workflow-kit.json', '\n'.join(result['warnings']))
        self.assertIn('.workflow-kit.json', '\n'.join(result['checklist']))
        self.assertIn('unknown', '\n'.join(result['checklist']))
        self.assertEqual((self.root / 'user-config.json').read_bytes(), user_config)
        self.assertEqual(self.git('show-ref'), refs)
        self.assertEqual(self.git('rev-parse', 'HEAD'), head)

    def test_init_preserves_malformed_json_config_and_adds_other_missing_files(self):
        self.assert_init_preserves_invalid_config(b'{owner invalid JSON\r\n')

    def test_init_preserves_unsupported_config_version_and_adds_other_missing_files(self):
        self.assert_init_preserves_invalid_config(b'{"workflowModelVersion":99,"targetBranch":"trunk"}\r\n')

    def test_init_refuses_parent_symlink_without_writing_outside_repo(self):
        outside = self.root / 'outside'
        outside.mkdir()
        try:
            (self.repo / 'docs').symlink_to(outside, target_is_directory=True)
        except OSError:
            self.skipTest('Directory symlinks unavailable on this host')
        with self.assertRaisesRegex(ValueError, 'symlink|outside|unsafe'):
            adoption.initialize(self.repo, apply=True)
        self.assertEqual(list(outside.iterdir()), [])
        self.assertFalse((self.repo / '.workflow-kit.json').exists())

    def test_init_checks_parent_file_collisions_before_any_write(self):
        parent = self.repo / 'docs'
        original = b'owner parent file\r\n\x00\xff'
        parent.write_bytes(original)
        with self.assertRaisesRegex(
                ValueError, r'Manual resolution required.*parent file collision.*docs/specs\.md'):
            adoption.initialize(self.repo, apply=True)
        self.assertFalse((self.repo / '.workflow-kit.json').exists())
        self.assertEqual(parent.read_bytes(), original)

    def test_new_preview_does_not_mutate_refs_or_files(self):
        self.initialize()
        before, refs = self.snapshot(), self.git('show-ref')
        result = adoption.new(self.repo, 'Preview package')
        self.assertTrue(result['dry_run'])
        self.assertEqual(result['branch'], 'feat/001-preview-package')
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.git('show-ref'), refs)
        self.assertEqual(self.git('status', '--porcelain'), '')

    def test_new_refuses_missing_current_table_separator_without_using_archive_table(self):
        self.initialize()
        catalog = self.repo / 'docs/specs.md'
        catalog.write_text(catalog.read_text().replace('|---|---|---|\n', '', 1))
        self.git('add', '--', catalog)
        self.git('commit', '-m', 'fixture: damaged current catalog table')
        before, refs = self.snapshot(), self.git('show-ref')
        for apply in (False, True):
            with self.subTest(apply=apply):
                with self.assertRaisesRegex(ValueError, 'Current packages.*header|Current packages.*separator'):
                    adoption.new(self.repo, 'Must refuse', apply=apply)
                self.assertEqual(self.snapshot(), before)
                self.assertEqual(self.git('show-ref'), refs)
                self.assertEqual(self.git('status', '--porcelain'), '')

    def test_new_registers_draft_and_complete_owners_before_creating_branch(self):
        self.initialize()
        template = self.repo / '.specify/templates/overrides/spec-template.md'
        template.write_text(template.read_text() + '\nProject custom marker\n')
        self.git('add', '--', template)
        self.git('commit', '-m', 'fixture: custom template')
        head = self.git('rev-parse', 'HEAD')
        result = adoption.new(self.repo, 'Owner intent', apply=True)
        self.assertFalse(result['dry_run'])
        self.assertEqual(result['branch'], 'feat/001-owner-intent')
        registered = self.git('rev-parse', 'trunk')
        self.assertEqual(self.git('rev-parse', 'trunk^'), head)
        self.assertEqual(self.git('rev-parse', result['branch']), registered)
        spec = self.git('show', f'{registered}:specs/001-owner-intent/spec.md')
        self.assertIn('Project custom marker', spec)
        self.assertIn('**Lifecycle**: draft', spec)
        self.assertIn('`feat/001-owner-intent`', spec)
        self.assertNotIn('[PACKAGE ID]', spec)
        for owner in ('spec.md', 'plan.md', 'tasks.md', 'reviews/CP1-request.md'):
            self.git('cat-file', '-e', f'{registered}:specs/001-owner-intent/{owner}')
        catalog = self.git('show', 'trunk:docs/specs.md')
        self.assertIn('001-owner-intent', catalog)
        self.assertEqual(self.git('status', '--porcelain'), '')

    def test_new_uses_fallback_project_template(self):
        self.initialize()
        override = self.repo / '.specify/templates/overrides/spec-template.md'
        fallback = self.repo / '.specify/templates/spec-template.md'
        fallback.write_text(override.read_text() + '\nFallback marker\n')
        override.unlink()
        self.git('add', '--', str(override), str(fallback))
        self.git('commit', '-m', 'fixture: fallback template')
        result = adoption.new(self.repo, 'Fallback', apply=True)
        self.assertIn('Fallback marker', self.git('show',
                      f'{result["branch"]}:specs/001-fallback/spec.md'))

    def test_new_reserves_package_catalog_and_remote_ref_numbers(self):
        self.initialize()
        (self.repo / 'specs/012-existing').mkdir(parents=True)
        self.git('update-ref', 'refs/remotes/origin/feat/019-remote', 'HEAD')
        result = adoption.new(self.repo, 'Numbering')
        self.assertEqual(result['branch'], 'feat/020-numbering')

    def test_new_does_not_reserve_dates_in_retained_package_reviews(self):
        self.initialize()
        path = self.repo / 'specs/012-existing/reviews/2026-10-18-findings.md'
        path.parent.mkdir(parents=True)
        path.write_text('historical evidence\n')
        self.git('add', '--', path)
        self.git('commit', '-m', 'fixture: old package evidence')
        self.assertEqual(adoption.new(self.repo, 'Next')['branch'], 'feat/013-next')

    def test_new_existing_local_ref_reserves_its_identity(self):
        self.initialize()
        self.git('branch', 'feat/001-existing')
        before = self.git('rev-parse', 'feat/001-existing')
        result = adoption.new(self.repo, 'Existing', apply=True)
        self.assertEqual(result['branch'], 'feat/002-existing')
        self.assertEqual(self.git('rev-parse', 'feat/001-existing'), before)

    def test_new_checks_real_lint_before_and_after_registration_commit(self):
        from wfk.workflow import lint
        self.initialize()
        original = adoption.git
        observed = []

        def inspect(repo, *args, **kwargs):
            if args[0] == 'commit':
                self.assertEqual(lint(repo)['errors'], [])
                self.assertIn('refs/heads/feat/001-lint', self.git('show-ref'))
            result = original(repo, *args, **kwargs)
            if args[0] == 'commit':
                self.assertEqual(lint(repo)['errors'], [])
                observed.append(result.returncode)
            return result

        with patch.object(adoption, 'git', side_effect=inspect):
            adoption.new(self.repo, 'Lint', apply=True)
        self.assertEqual(observed, [0])
        self.assertEqual(lint(self.repo)['errors'], [])

    def test_new_does_not_promote_sample_implementation_tasks_from_project_template(self):
        self.initialize()
        template = self.repo / '.specify/templates/overrides/tasks-template.md'
        template.write_text('# Sample only\n\n- [ ] T001 Implement everything\n')
        self.git('add', '--', template)
        self.git('commit', '-m', 'fixture: vendor sample task template')
        result = adoption.new(self.repo, 'Draft only', apply=True)
        tasks = self.git('show', f'{result["branch"]}:specs/001-draft-only/tasks.md')
        self.assertIn('**Entry checkpoint**: CP1', tasks)
        self.assertNotIn('Implement everything', tasks)

    def test_new_never_inherits_template_lifecycle_or_owner_clearance(self):
        self.initialize()
        template = self.repo / '.specify/templates/overrides/spec-template.md'
        content = template.read_text().replace('**Lifecycle**: draft', '**Lifecycle**: active')
        content = content.replace('| pending |', '| owner-cleared |')
        template.write_text(content)
        self.git('add', '--', template)
        self.git('commit', '-m', 'fixture: template metadata drift')
        result = adoption.new(self.repo, 'Still draft', apply=True)
        spec = self.git('show', f'{result["branch"]}:specs/001-still-draft/spec.md')
        self.assertIn('**Lifecycle**: draft', spec)
        self.assertIn('| pending |', spec)
        self.assertNotIn('owner-cleared', spec)

    def test_new_refuses_to_commit_an_unrelated_concurrently_staged_file(self):
        self.initialize()
        validate = adoption._validate
        checks = []

        def stage_owner_work(repo):
            validate(repo)
            checks.append(True)
            if len(checks) == 2:
                (Path(repo) / 'README.md').write_text('owner concurrent work\n')
                self.git('add', '--', 'README.md', repo=repo)

        head = self.git('rev-parse', 'HEAD')
        with patch.object(adoption, '_validate', side_effect=stage_owner_work):
            with self.assertRaisesRegex(ValueError, 'staged|index'):
                adoption.new(self.repo, 'Concurrent', apply=True)
        self.assertEqual(self.git('rev-parse', 'HEAD'), head)
        self.assertIn('README.md', self.git('diff', '--cached', '--name-only'))
        self.assertEqual((self.repo / 'README.md').read_text(), 'owner concurrent work\n')

    def test_new_commit_failure_preserves_recoverable_files_index_and_draft_ref(self):
        from wfk.git import GitError
        self.initialize()
        self.git('checkout', '-b', 'caller-feature')
        original = adoption.git
        target_head = self.git('rev-parse', 'trunk')

        def reject(repo, *args, **kwargs):
            if args[0] == 'commit':
                raise GitError('fixture pre-commit rejected registration')
            return original(repo, *args, **kwargs)

        with patch.object(adoption, 'git', side_effect=reject):
            with self.assertRaisesRegex(ValueError, 'Recovery checkout:.*draft branch: feat/001-recovery'):
                adoption.new(self.repo, 'Recovery', apply=True)
        self.assertEqual(self.git('rev-parse', 'trunk'), target_head)
        self.assertEqual(self.git('branch', '--show-current'), 'caller-feature')
        scratch = next(self.root.glob('wfk-new-*/target'))
        self.assertTrue((scratch / 'specs/001-recovery/spec.md').is_file())
        self.assertIn('docs/specs.md', self.git('diff', '--cached', '--name-only', repo=scratch))
        self.assertIn('specs/001-recovery/spec.md',
                      self.git('ls-tree', '-r', '--name-only', 'feat/001-recovery'))
        self.assertNotIn('001-recovery', self.git('show', 'feat/001-recovery:docs/specs.md'))

    def test_init_unknown_target_remains_a_manual_configuration_step(self):
        (self.root / 'user-config.json').unlink()
        result = adoption.initialize(self.repo, apply=True)
        self.assertNotIn('targetBranch', json.loads((self.repo / '.workflow-kit.json').read_text()))
        self.assertIn('targetBranch', '\n'.join(result['checklist']))

    def test_new_uses_configured_target_without_switching_feature_checkout(self):
        self.initialize()
        self.git('checkout', '-b', 'other-feature')
        (self.repo / 'only-feature.txt').write_text('feature work\n')
        self.git('add', '--', 'only-feature.txt')
        self.git('commit', '-m', 'fixture: other work')
        head = self.git('rev-parse', 'HEAD')
        result = adoption.new(self.repo, 'From target', apply=True)
        self.assertEqual(self.git('branch', '--show-current'), 'other-feature')
        self.assertEqual(self.git('rev-parse', 'HEAD'), head)
        self.assertEqual(self.git('cat-file', '-e', f'{result["branch"]}:only-feature.txt',
                                  check=False), '')
        self.assertNotIn('only-feature.txt', self.git('ls-tree', '-r', '--name-only', result['branch']))
        self.assertEqual(len(self.git('worktree', 'list', '--porcelain').split('worktree ')), 2)

    def test_new_refuses_target_checked_out_elsewhere(self):
        self.initialize()
        self.git('checkout', '-b', 'other-feature')
        target = self.root / 'busy-target'
        self.git('worktree', 'add', target, 'trunk')
        refs = self.git('show-ref')
        with self.assertRaisesRegex(ValueError, 'checked out|busy'):
            adoption.new(self.repo, 'Busy', apply=True)
        self.assertEqual(self.git('show-ref'), refs)
        self.assertFalse((target / 'specs/001-busy').exists())

    def test_new_refuses_dirty_target_and_preserves_index(self):
        self.initialize()
        (self.repo / 'README.md').write_text('owner staged change\n')
        self.git('add', '--', 'README.md')
        before, refs = self.snapshot(), self.git('show-ref')
        index = self.git('diff', '--cached')
        with self.assertRaisesRegex(ValueError, 'clean|dirty'):
            adoption.new(self.repo, 'Dirty', apply=True)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.git('show-ref'), refs)
        self.assertEqual(self.git('diff', '--cached'), index)

    def test_new_rejects_invalid_name_and_missing_template_without_mutation(self):
        self.initialize()
        before = self.snapshot()
        for name in ('', '../escape', '--flag', 'x/y', '   '):
            with self.assertRaises(ValueError):
                adoption.new(self.repo, name, apply=True)
        self.assertEqual(self.snapshot(), before)
        template = self.repo / '.specify/templates/overrides/spec-template.md'
        template.unlink()
        self.git('add', '--', template)
        self.git('commit', '-m', 'fixture: remove template')
        refs = self.git('show-ref')
        with self.assertRaisesRegex(ValueError, 'template'):
            adoption.new(self.repo, 'No template', apply=True)
        self.assertEqual(self.git('show-ref'), refs)


if __name__ == '__main__':
    unittest.main()
