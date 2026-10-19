"""Offline workflow ownership, branch routing and gate regressions."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from wfk import workflow


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='wfk-workflow-')
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.environment = patch.dict(os.environ, {'WFK_CONFIG': str(self.repo / 'absent'),
            'GIT_CONFIG_NOSYSTEM': '1', 'GIT_CONFIG_GLOBAL': os.devnull})
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.git('init', '-b', 'main')
        self.git('config', 'user.name', 'Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'commit.gpgSign', 'false')
        self.write('.workflow-kit.json', json.dumps({'workflowModelVersion': 2,
            'targetBranch': 'main', 'autoLoadedFiles': [], 'hostBudgets': []}))
        self.write('docs/specs.md', '# Catalog\n## Current packages\n\n| Spec | Package | Branch |\n'
            '|---|---|---|\n| Test | [test](../specs/001-test/spec.md) | `feat/001-test` |\n')
        self.write('specs/001-test/spec.md', '# Spec\n\n**Feature branch**: `feat/001-test`\n'
            '**Lifecycle**: active\n**Scope**: `001/spec-r1`\n\n**Checkpoints**:\n\n'
            '| ID | Gate | Verdict link | State |\n|---|---|---|---|\n'
            '| CP1 | Owner | [decision](reviews/decision.md) | owner-cleared |\n'
            '| CP2 | Review | not requested | pending |\n')
        self.write('specs/001-test/plan.md', '# Plan\n')
        self.write('specs/001-test/tasks.md', '# Work\n**Entry checkpoint**: CP1\n\n'
            '- [ ] T001 [S] First task (gate: CP1).\n- [ ] T002 [H] Later (gate: CP2).\n')
        self.write('specs/001-test/reviews/decision.md', '**Reviewer**: Owner\n'
            '**Reviewed revision**: fixture\n**Verdict**: accept\n'
            '**Checkpoint**: CP1\n**Scope**: `001/spec-r1`\n**Accepted scope**: `001/spec-r1`\n')
        self.git('add', '.')
        self.git('commit', '-m', 'fixture')
        self.git('branch', 'feat/001-test')

    def git(self, *args):
        result = subprocess.run(['git', '-C', str(self.repo), *args],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def write(self, path, text):
        path = self.repo / path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8')

    def edit(self, old, new, path='specs/001-test/spec.md'):
        file = self.repo / path
        file.write_text(file.read_text(encoding='utf-8').replace(old, new), encoding='utf-8')

    def on_package(self):
        self.git('switch', 'feat/001-test')

    def errors(self):
        return '\n'.join(workflow.lint(self.repo)['errors'])

    def test_declared_branch_overrides_stale_primary_copy_and_is_read_only(self):
        self.edit('**Lifecycle**: active', '**Lifecycle**: nonsense')
        before = self.git('status', '--porcelain')
        self.assertEqual(self.errors(), '')
        self.assertEqual(self.git('status', '--porcelain'), before)

    def test_dirty_declared_worktree_is_the_owner(self):
        linked = self.repo.parent / (self.repo.name + '-linked')
        self.git('worktree', 'add', str(linked), 'feat/001-test')
        self.addCleanup(lambda: self.git('worktree', 'remove', '--force', str(linked)))
        file = linked / 'specs/001-test/spec.md'
        file.write_text(file.read_text().replace('active', 'bogus'), encoding='utf-8')
        self.assertIn('lifecycle', self.errors().lower())

    def test_missing_declared_branch_is_actionable(self):
        self.git('branch', '-D', 'feat/001-test')
        self.assertIn('branch', self.errors().lower())

    def test_invalid_lifecycle_checkpoint_and_duplicate_gate(self):
        self.on_package()
        self.edit('**Lifecycle**: active', '**Lifecycle**: unknown')
        self.assertIn('lifecycle', self.errors().lower())
        self.edit('**Lifecycle**: unknown', '**Lifecycle**: active')
        self.edit('| pending |', '| accepted |')
        self.assertIn('checkpoint', self.errors().lower())

    def test_missing_owner_and_broken_checkpoint_link(self):
        self.on_package()
        (self.repo / 'specs/001-test/plan.md').unlink()
        self.edit('reviews/decision.md', 'reviews/missing.md')
        errors = self.errors()
        self.assertIn('plan.md', errors)
        self.write('specs/001-test/plan.md', '# Plan\n')
        self.assertIn('missing.md', self.errors())

    def test_bad_review_headers_and_invalid_verdict(self):
        self.on_package()
        self.write('specs/001-test/reviews/2026-10-18-cp1-test-findings.md',
                   '**Reviewer**: GPT\n**Verdict**: maybe\n')
        errors = self.errors()
        self.assertIn('Reviewed revision', errors)
        self.assertIn('Verdict', errors)

    def test_gate_requires_scope_matching_acceptance_and_never_runs_past_pending(self):
        package = workflow.packages(self.repo)[0]
        self.assertIsNone(workflow.gate_problem(package, 'CP1'))
        self.assertIn('not owner-cleared', workflow.gate_problem(package, 'CP2'))
        self.assertEqual(workflow.next_task(package)['id'], 'T001')
        self.on_package()
        self.edit('**Accepted scope**: `001/spec-r1`', '**Accepted scope**: `001/spec-r0`',
                  'specs/001-test/reviews/decision.md')
        self.assertIn('scope', workflow.gate_problem(workflow.packages(self.repo)[0], 'CP1'))

    def test_unknown_task_gate_and_duplicate_identity_are_errors(self):
        self.on_package()
        self.edit('T002', 'T001', 'specs/001-test/tasks.md')
        self.assertIn('duplicate', self.errors())
        self.edit('T001 [H]', 'T002 [H]', 'specs/001-test/tasks.md')
        self.edit('(gate: CP2)', '(gate: CP9)', 'specs/001-test/tasks.md')
        self.assertIn('CP9', self.errors())

    def test_budgets_only_apply_to_auto_loaded_files_and_host_totals(self):
        self.write('AGENTS.md', 'one\ntwo\n')
        self.write('large.md', 'x\n' * 1000)
        self.write('.workflow-kit.json', json.dumps({'workflowModelVersion': 2,
            'autoLoadedFiles': [{'path': 'AGENTS.md', 'loading': 'full', 'hosts': ['codex'],
                                 'lines': 1, 'bytes': 100},
                                {'path': 'large.md', 'loading': 'on-demand'}],
            'hostBudgets': [{'host': 'codex', 'lines': 1, 'bytes': 100}]}))
        errors = self.errors()
        self.assertIn('AGENTS.md', errors)
        self.assertIn('codex', errors)
        self.assertNotIn('large.md', errors)

    def test_markers_and_feature_state_are_rejected_in_instructions(self):
        self.write('AGENTS.md', '<!-- MANUAL ADDITIONS START -->\n**Next tasks**: T001\n')
        self.assertIn('AGENTS.md', self.errors())

    def test_catalog_branches_are_cleanup_protected(self):
        from wfk.worktrees import _protected
        self.assertTrue(_protected(self.repo, 'feat/001-test', 'main'))

    def test_path_escape_is_rejected(self):
        self.edit('reviews/decision.md', '../../../outside.md')
        self.on_package()
        self.assertIn('escape', self.errors().lower())

    def test_checkpoint_anchor_must_resolve(self):
        self.on_package()
        self.edit('reviews/decision.md', 'reviews/decision.md#missing-anchor')
        self.assertIn('anchor', self.errors().lower())

    def test_v2_checkpoint_keeps_only_latest_two_links(self):
        self.on_package()
        self.edit('[decision](reviews/decision.md)',
                  '[one](reviews/decision.md); [two](reviews/decision.md); [three](reviews/decision.md)')
        self.assertIn('two links', self.errors())

    def test_findings_require_severity_and_headers(self):
        self.on_package()
        self.write('specs/001-test/reviews/2026-10-18-cp1-test-findings.md',
                   'Reviewer: GPT\nReviewed revision: fixture\nVerdict: changes\n\n1. Fix this.\n')
        self.assertIn('severity', self.errors())

    def test_cli_json_lint_failure_and_init_preview(self):
        import sys
        env = dict(os.environ, PYTHONPATH=str(Path(__file__).resolve().parents[1]))
        self.on_package()
        self.edit('**Lifecycle**: active', '**Lifecycle**: nonsense')
        result = subprocess.run([sys.executable, '-m', 'wfk', 'lint', '--json'],
            cwd=self.repo, env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertTrue(json.loads(result.stdout)['errors'])
        result = subprocess.run([sys.executable, '-m', 'wfk', 'init', '--json'],
            cwd=self.repo, env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)['dry_run'])
        self.assertFalse((self.repo / 'AGENTS.md').exists())

    def test_invalid_budget_schema_is_a_clear_value_error(self):
        self.write('AGENTS.md', 'instructions\n')
        self.write('.workflow-kit.json', json.dumps({'workflowModelVersion': 2,
            'autoLoadedFiles': [{'path': 'AGENTS.md', 'loading': 'full',
                                 'lines': 100, 'bytes': 1000, 'hosts': [{}]}]}))
        with self.assertRaisesRegex(ValueError, 'host'):
            workflow.lint(self.repo)

    def test_cleanup_protection_uses_target_catalog_from_stale_checkout(self):
        from wfk.worktrees import _protected
        text = (self.repo / 'docs/specs.md').read_text()
        self.write('docs/specs.md', text + '| New | [new](../specs/002-new/spec.md) | `feat/002-new` |\n')
        self.git('add', 'docs/specs.md')
        self.git('commit', '-m', 'fixture registration')
        self.on_package()
        self.assertTrue(_protected(self.repo, 'feat/002-new', 'main'))

    def test_latest_owner_acceptance_can_dispose_a_saved_blocker_finding(self):
        self.on_package()
        self.write('specs/001-test/reviews/2026-10-18-cp1-gpt-findings.md',
            'Reviewer: GPT\nReviewed revision: fixture\nVerdict: blocker\n\n'
            '1. **Blocker**: fixed later; keep this historical evidence.\n')
        self.edit('[decision](reviews/decision.md)',
            '[findings](reviews/2026-10-18-cp1-gpt-findings.md); [decision](reviews/decision.md)')
        package = workflow.packages(self.repo)[0]
        self.assertIsNone(workflow.gate_problem(package, 'CP1'))
        self.edit('**Verdict**: accept', '**Verdict**: blocker', 'specs/001-test/reviews/decision.md')
        self.assertIsNotNone(workflow.gate_problem(workflow.packages(self.repo)[0], 'CP1'))

    def test_v2_gate_cannot_combine_reviewer_and_owner_fields_between_records(self):
        self.on_package()
        self.write('specs/001-test/reviews/2026-10-18-cp1-gpt-findings.md',
            'Reviewer: GPT\nReviewed revision: fixture\nVerdict: accept\n\nNo findings.\n')
        self.write('specs/001-test/reviews/decision.md', 'Accepted scope: `001/spec-r1`\n')
        self.edit('[decision](reviews/decision.md)',
            '[findings](reviews/2026-10-18-cp1-gpt-findings.md); [decision](reviews/decision.md)')
        self.assertIsNotNone(workflow.gate_problem(workflow.packages(self.repo)[0], 'CP1'))
        self.assertTrue(workflow.lint(self.repo)['errors'])

    def test_lint_names_only_v1_fields_it_ignores(self):
        self.write('.workflow-kit.json', json.dumps({'workflowModelVersion': 1,
            'managedScratchRoot': '{temp}/old', 'disposablePatterns': ['build/'],
            'autoLoadedFiles': [], 'hostBudgets': [], 'budgetExceptions': []}))
        warnings = '\n'.join(workflow.lint(self.repo)['warnings'])
        self.assertIn('managedScratchRoot', warnings)
        self.assertIn('budgetExceptions', warnings)
        self.assertIn('disposablePatterns', warnings)
        self.assertNotIn('autoLoadedFiles', warnings)
        self.assertNotIn('hostBudgets', warnings)

    def test_v2_root_lints_declared_v1_branch_with_compatibility_warnings(self):
        self.on_package()
        self.write('.workflow-kit.json', json.dumps({'workflowModelVersion': 1,
            'targetBranch': 'main', 'autoLoadedFiles': [], 'hostBudgets': []}))
        self.edit('[decision](reviews/decision.md)',
            '[one](reviews/decision.md); [two](reviews/decision.md); [three](reviews/decision.md)')
        self.write('specs/001-test/reviews/2026-10-19-cp1-gpt-findings.md',
            'Reviewer: GPT\nReviewed revision: fixture\nVerdict: changes\n\n'
            '1. **Major**: historical finding was recorded after the linked decision.\n')
        self.git('add', '.')
        self.git('commit', '-m', 'legacy package evidence')
        self.git('switch', 'main')

        result = workflow.lint(self.repo)

        warnings = '\n'.join(result['warnings'])
        self.assertEqual(result['errors'], [])
        self.assertIn('specs/001-test: CP1 must link its latest findings', warnings)
        self.assertIn('specs/001-test CP1: checkpoint has more than latest two links', warnings)
        scheduled = workflow.packages(self.repo)[0]
        self.assertEqual(scheduled['version'], 2)
        self.assertIsNotNone(workflow.gate_problem(scheduled, 'CP1'))

    def test_v2_declared_branch_keeps_strict_lint_rules(self):
        self.on_package()
        self.edit('[decision](reviews/decision.md)',
            '[one](reviews/decision.md); [two](reviews/decision.md); [three](reviews/decision.md)')
        self.write('specs/001-test/reviews/2026-10-19-cp1-gpt-findings.md',
            'Reviewer: GPT\nReviewed revision: fixture\nVerdict: changes\n\n'
            '1. **Major**: current-model finding must be linked.\n')
        self.git('add', '.')
        self.git('commit', '-m', 'current package evidence')
        self.git('switch', 'main')

        errors = '\n'.join(workflow.lint(self.repo)['errors'])

        self.assertIn('specs/001-test: CP1 must link its latest findings', errors)
        self.assertIn('specs/001-test CP1: checkpoint has more than latest two links', errors)

    def archive_legacy_package(self):
        catalog = self.repo / 'docs/specs.md'
        catalog.write_text(catalog.read_text().replace(
            '| Test |', '## Archive\n\n| Spec | Package | Branch |\n|---|---|---|\n| Test |'),
            encoding='utf-8')
        self.edit('**Lifecycle**: active',
                  '**Lifecycle**: superseded\n**Review format version**: 1')
        self.edit('[decision](reviews/decision.md)',
            '[one](reviews/decision.md); [two](reviews/decision.md); [three](reviews/decision.md)')
        self.edit('**Verdict**: accept', '**Verdict**: accept (historical)',
                  'specs/001-test/reviews/decision.md')
        self.git('branch', '-D', 'feat/001-test')

    def test_archived_v1_evidence_is_preserved_without_branch_or_execution(self):
        self.archive_legacy_package()
        evidence = self.repo / 'specs/001-test/reviews/decision.md'
        before = evidence.read_bytes()
        result = workflow.lint(self.repo)
        self.assertEqual(result['errors'], [])
        self.assertIn('Invalid Verdict', '\n'.join(result['warnings']))
        self.assertIn('checkpoint has more than latest two links', '\n'.join(result['warnings']))
        self.assertEqual(evidence.read_bytes(), before)
        package = workflow.packages(self.repo)[0]
        self.assertEqual(package['version'], 2)
        with self.assertRaisesRegex(ValueError, 'superseded'):
            workflow.next_task(package)

    def test_archive_format_cannot_relax_active_or_new_findings(self):
        self.on_package()
        self.edit('**Lifecycle**: active',
                  '**Lifecycle**: active\n**Review format version**: 1')
        self.assertIn('terminal archive', self.errors())
        self.edit('\n**Review format version**: 1', '')
        self.git('switch', 'main')
        self.archive_legacy_package()
        self.write('specs/001-test/reviews/2026-10-20-cp2-test-findings.md',
                   'Reviewer: GPT\nReviewed revision: fixture\nVerdict: invalid\n\n1. No severity\n')
        errors = self.errors()
        self.assertIn('Invalid Verdict', errors)
        self.assertIn('severity', errors)
        self.edit('**Review format version**: 1', '**Review format version**: 3')
        self.assertIn('Invalid Review format version', self.errors())

    def test_declared_branch_config_must_exist_and_be_valid(self):
        cases = (
            ('missing-config', None, 'Missing workflow config'),
            ('missing-version', '{}', 'Missing workflowModelVersion'),
            ('malformed', '{', 'Cannot read workflow config'),
            ('unsupported', '{"workflowModelVersion": 3}', 'Unsupported workflowModelVersion'),
        )
        for label, content, expected in cases:
            with self.subTest(label=label):
                self.on_package()
                path = self.repo / '.workflow-kit.json'
                if content is None:
                    path.unlink()
                else:
                    path.write_text(content, encoding='utf-8')
                self.git('add', '-A')
                self.git('commit', '-m', f'{label} source config')
                self.git('switch', 'main')
                errors = '\n'.join(workflow.lint(self.repo)['errors'])
                self.assertIn(expected, errors)

    def test_mixed_case_or_malformed_gate_never_falls_back_to_entry(self):
        self.on_package()
        self.edit('- [ ] T001', '- [x] T001', 'specs/001-test/tasks.md')
        path = self.repo / 'specs/001-test/tasks.md'
        canonical = path.read_text()
        for annotation in ('(Gate: CP2)', '(gate: cp2)', '( gate : CP2)', '(gate CP2)'):
            with self.subTest(annotation=annotation):
                path.write_text(canonical.replace('(gate: CP2)', annotation), encoding='utf-8')
                with self.assertRaises(ValueError):
                    workflow.next_task(workflow.packages(self.repo)[0])

    def test_legacy_config_requires_explicit_adoption_for_workflow_commands(self):
        for content in ('{}', '{"canonicalMirrorMode":"external"}'):
            self.write('.workflow-kit.json', content)
            with self.assertRaisesRegex(ValueError, 'wfk init'):
                workflow.lint(self.repo)
            with self.assertRaisesRegex(ValueError, 'wfk init'):
                workflow.packages(self.repo)

    def test_catalog_requires_its_current_table_header_and_separator(self):
        path = self.repo / 'docs/specs.md'
        original = path.read_text()
        for damaged in (original.replace('|---|---|---|\n', ''),
                        original.replace('| Spec | Package | Branch |\n', '')):
            path.write_text(damaged, encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'catalog|Catalog'):
                workflow.catalog(self.repo)

    def test_unlinked_newer_findings_block_v2_gate_and_lint(self):
        self.on_package()
        self.write('specs/001-test/reviews/2026-10-19-cp1-gpt-findings.md',
            'Reviewer: GPT\nReviewed revision: fixture\nVerdict: blocker\n\n'
            '1. **Blocker**: later evidence must be routed.\n')
        package = workflow.packages(self.repo)[0]
        self.assertIsNotNone(workflow.gate_problem(package, 'CP1'))
        self.assertIn('latest findings', self.errors())

    def test_same_date_reviews_report_order_ambiguity(self):
        self.on_package()
        for reviewer in ('gpt', 'opus'):
            self.write(f'specs/001-test/reviews/2026-10-18-cp1-{reviewer}-findings.md',
                f'Reviewer: {reviewer}\nReviewed revision: fixture\nVerdict: accept\nNo findings.\n')
        self.edit('[decision](reviews/decision.md)',
            '[findings](reviews/2026-10-18-cp1-opus-findings.md); [decision](reviews/decision.md)')
        self.assertIn('ambiguous', '\n'.join(workflow.lint(self.repo)['warnings']))


if __name__ == '__main__':
    unittest.main()
