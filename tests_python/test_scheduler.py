"""Scheduler acceptance fixtures use Python workers in disposable Git repos."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from wfk import scheduler

WORKER = Path(__file__).parent / 'fixtures/scheduler_worker.py'
PACKAGE = 'specs/001-test'


class SchedulerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='wfk-run-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / 'primary'
        self.repo.mkdir()
        self.calls = self.root / 'calls.jsonl'
        self.env = patch.dict(os.environ, {'WFK_CONFIG': str(self.root / 'absent'),
            'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_CONFIG_NOSYSTEM': '1',
            'WFK_FIXTURE_CALLS': str(self.calls)})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.git('init', '-b', 'main')
        for key, value in [('user.name', 'Fixture'), ('user.email', 'test@example.invalid'),
                           ('commit.gpgSign', 'false'), ('core.autocrlf', 'false')]:
            self.git('config', key, value)
        self.settings = {'workflowModelVersion': 2, 'targetBranch': 'main',
            'worktreeRoot': str(self.root / 'workers'), 'workers': {},
            'scheduler': {'authTimeout': 5, 'grace': .05}}
        for mode in ('done', 'no-progress', 'uncommitted', 'timeout', 'quota', 'auth',
                     'error', 'protected', 'other-task', 'revert-protected', 'late-auth', 'package-failure',
                     'protected-switch', 'foreign-ref', 'hidden-gate', 'review-accept',
                     'review-changes', 'review-extra', 'review-undo'):
            self.settings['workers'][mode] = {'command': [sys.executable, str(WORKER), mode, 'work'],
                'authCommand': [sys.executable, str(WORKER), mode, 'auth'],
                'input': 'stdin', 'quotaExitCodes': [7], 'authExitCodes': [3]}
        self.write('.workflow-kit.json', json.dumps(self.settings))
        self.write('docs/specs.md', '# Catalog\n## Current packages\n\n| Spec | Package | Branch |\n'
            '|---|---|---|\n| Test | [test](../' + PACKAGE + '/spec.md) | `feat/001-test` |\n')
        self.write(PACKAGE + '/spec.md', '# Test\n**Feature branch**: `feat/001-test`\n'
            '**Lifecycle**: active\n**Scope**: `001/spec-r1`\n\n**Checkpoints**:\n\n'
            '| ID | Gate | Verdict link | State |\n|---|---|---|---|\n'
            '| CP1 | Owner | [decision](reviews/decision.md) | owner-cleared |\n'
            '| CP2 | Next | not requested | pending |\n\n## Requirements\nWork.\n')
        self.write(PACKAGE + '/plan.md', '# Plan\n')
        self.write(PACKAGE + '/tasks.md', '# Work\n**Entry checkpoint**: CP1\n\n'
            '- [ ] T001 [S] First (gate: CP1).\n- [ ] T002 [H] Later (gate: CP2).\n')
        self.write(PACKAGE + '/reviews/decision.md', '**Reviewer**: Owner\n'
            '**Reviewed revision**: fixture\n**Verdict**: accept\n'
            '**Checkpoint**: CP1\n**Accepted scope**: `001/spec-r1`\n')
        self.git('add', '.')
        self.git('commit', '-m', 'fixture')
        self.git('branch', 'feat/001-test')
        self.base = self.git('rev-parse', 'HEAD')

    def git(self, *args, repo=None):
        result = subprocess.run(['git', '-C', str(repo or self.repo), *args],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def write(self, name, text):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8')

    def run_worker(self, mode='done', **options):
        return scheduler.run(self.repo, packages=[PACKAGE], agents=[mode], apply=True,
                             task_timeout=5, **options)

    def add_second_package(self):
        name = 'specs/002-next'
        for path in (self.repo / PACKAGE).rglob('*'):
            if path.is_file():
                self.write(name + '/' + path.relative_to(self.repo / PACKAGE).as_posix(),
                    path.read_text(encoding='utf-8').replace('feat/001-test', 'feat/002-next'))
        path = self.repo / 'docs/specs.md'
        path.write_text(path.read_text() + '| Next | [next](../specs/002-next/spec.md) | `feat/002-next` |\n')
        self.git('add', '.')
        self.git('commit', '-m', 'fixture: second package')
        self.git('branch', 'feat/002-next')
        return name

    def test_preview_is_read_only_and_never_probes(self):
        before = self.git('status', '--porcelain')
        result = scheduler.run(self.repo, packages=[PACKAGE], agents=['done'])
        self.assertTrue(result['dry_run'])
        self.assertEqual(result['items'][0]['task'], 'T001')
        self.assertFalse(self.calls.exists())
        self.assertFalse((self.repo / '.git/wfk').exists())
        self.assertEqual(self.git('status', '--porcelain'), before)

    def test_done_commits_directly_in_package_worktree_and_stops_at_gate(self):
        result = self.run_worker(max_tasks=5)
        self.assertEqual(result['items'][0]['outcome'], 'done', result)
        self.assertTrue(Path(result['report']).is_file())
        self.assertIn('CP2', Path(result['report']).read_text(encoding='utf-8'))
        self.assertEqual(self.git('rev-parse', 'HEAD'), self.base)
        self.assertEqual(self.git('status', '--porcelain'), '')
        self.assertNotEqual(self.git('rev-parse', 'feat/001-test'), self.base)
        self.assertEqual(len(self.calls.read_text().splitlines()), 2)

    def test_basic_outcomes(self):
        for mode in ('no-progress', 'uncommitted', 'error'):
            with self.subTest(mode=mode):
                result = self.run_worker(mode)
                self.assertEqual(result['items'][0]['outcome'], mode, result)
                self.assertTrue(Path(result['report']).exists())
                # Restore this disposable fixture by removing its worker via Git.
                worker = Path(result['items'][0]['worktree'])
                self.git('worktree', 'remove', '--force', str(worker))
                self.git('update-ref', 'refs/heads/feat/001-test', self.base)

    def test_quota_falls_back_in_explicit_order(self):
        result = scheduler.run(self.repo, packages=[PACKAGE], agents=['quota', 'done'],
                               apply=True, task_timeout=5)
        row = result['items'][0]
        self.assertEqual(row['outcome'], 'done', result)
        self.assertEqual([a['outcome'] for a in row['attempts']], ['quota', 'done'])

    def test_auth_preflight_stops_before_task(self):
        result = self.run_worker('auth')
        self.assertEqual(result['status'], 'auth', result)
        self.assertFalse(result['items'])
        self.assertEqual(len(self.calls.read_text().splitlines()), 1)

    def test_timeout_preserves_checkout_and_finalizes_report(self):
        result = scheduler.run(self.repo, packages=[PACKAGE], agents=['timeout'],
                               apply=True, task_timeout=.3)
        self.assertEqual(result['items'][0]['outcome'], 'timeout', result)
        self.assertTrue(Path(result['items'][0]['worktree']).is_dir())
        self.assertIn('timeout', Path(result['report']).read_text(encoding='utf-8'))

    def test_protected_commit_and_reverted_change_are_quarantined(self):
        for mode in ('protected', 'other-task', 'revert-protected'):
            with self.subTest(mode=mode):
                result = self.run_worker(mode)
                row = result['items'][0]
                self.assertEqual(row['outcome'], 'gate-violation', result)
                self.assertTrue(self.git('rev-parse', row['rejected_ref']))
                self.assertEqual(self.git('rev-parse', 'feat/001-test'), self.base)
                worker = Path(row['worktree'])
                self.assertNotEqual(self.git('status', '--porcelain', repo=worker), '')
                self.git('worktree', 'remove', '--force', str(worker))

    def test_primary_checked_out_on_package_branch_is_refused(self):
        self.git('switch', 'feat/001-test')
        result = self.run_worker()
        self.assertIn('primary', ' '.join(result['errors']).lower())
        self.assertFalse(self.calls.exists())

    def test_missing_auth_probe_fails_closed_with_report(self):
        self.settings['workers']['done']['authCommand'] = None
        self.write('.workflow-kit.json', json.dumps(self.settings))
        self.git('add', '.')
        self.git('commit', '-m', 'fixture config')
        result = self.run_worker()
        self.assertEqual(result['status'], 'auth', result)
        self.assertFalse(self.calls.exists())
        self.assertTrue(Path(result['report']).exists())

    def test_apply_requires_explicit_package_and_valid_limits(self):
        result = scheduler.run(self.repo, agents=['done'], apply=True)
        self.assertTrue(result['errors'])
        for kwargs in ({'max_tasks': 0}, {'max_hours': float('nan')}, {'task_timeout': -1}):
            with self.subTest(kwargs=kwargs):
                result = scheduler.run(self.repo, packages=[PACKAGE], apply=True,
                                       agents=['done'], **kwargs)
                self.assertTrue(result['errors'])
                self.assertTrue(Path(result['report']).exists())

    def test_crash_and_interrupt_keep_a_report(self):
        for exception in (RuntimeError('fixture crash'), KeyboardInterrupt()):
            with self.subTest(exception=type(exception).__name__):
                with patch('wfk.scheduler._dispatch', side_effect=exception):
                    result = self.run_worker()
                self.assertTrue(Path(result['report']).exists())
                self.assertIn(result['status'], ('error', 'interrupted'))

    def test_existing_clean_checkout_is_reused_but_dirty_or_locked_is_refused(self):
        worker = self.root / 'existing'
        self.git('worktree', 'add', str(worker), 'feat/001-test')
        (worker / 'notes').write_text('keep me')
        result = self.run_worker()
        self.assertIn('local changes', ' '.join(result['errors']))
        self.assertFalse(self.calls.exists())
        (worker / 'notes').unlink()
        self.git('worktree', 'lock', str(worker))
        self.assertIn('locked', ' '.join(self.run_worker()['errors']))
        self.git('worktree', 'unlock', str(worker))
        result = self.run_worker()
        self.assertEqual(result['items'][0]['worktree'], str(worker.resolve()))
        self.assertEqual(result['cleanup'], [])
        self.assertTrue(worker.is_dir())

    def test_package_lease_prevents_duplicate_dispatch_and_is_not_stolen(self):
        package = scheduler._select(self.repo, [PACKAGE])[0]
        with scheduler._lease(self.repo, package, 'fixture-owner'):
            result = self.run_worker()
            self.assertIn('locked', ' '.join(result['errors']))
            self.assertFalse(self.calls.exists())
        self.assertFalse(list((self.repo / '.git/wfk/locks').glob('*.lock')))

    def test_task_failure_continues_only_explicit_next_package(self):
        second = self.add_second_package()
        result = scheduler.run(self.repo, packages=[PACKAGE, second], agents=['package-failure'],
                               apply=True, max_tasks=5, task_timeout=5)
        self.assertEqual([r['outcome'] for r in result['items']], ['error', 'done'], result)
        self.assertEqual([r['package'] for r in result['items']], [PACKAGE, second])

    def test_task_auth_failure_stops_entire_run_without_fallback(self):
        second = self.add_second_package()
        result = scheduler.run(self.repo, packages=[PACKAGE, second], agents=['late-auth', 'done'],
                               apply=True, max_tasks=5, task_timeout=5)
        self.assertEqual(result['status'], 'auth', result)
        self.assertEqual(len(result['items']), 1)
        self.assertEqual(len(result['items'][0]['attempts']), 1)
        self.assertEqual(len(self.calls.read_text().splitlines()), 2)

    def test_missing_executable_and_inactive_package_never_invoke_worker(self):
        self.settings['workers']['done']['command'] = ['wfk-missing-fixture-executable-937128']
        self.write('.workflow-kit.json', json.dumps(self.settings))
        result = self.run_worker()
        self.assertIn('executable unavailable', ' '.join(result['errors']))
        self.assertFalse(self.calls.exists())
        worker = self.root / 'workers/feat-001-test'
        path = worker / PACKAGE / 'spec.md'
        path.write_text(path.read_text().replace('**Lifecycle**: active', '**Lifecycle**: parked'))
        self.git('add', '.', repo=worker)
        self.git('commit', '-m', 'fixture: parked', repo=worker)
        result = self.run_worker()
        self.assertIn('parked', ' '.join(result['errors']))

    def test_fallback_auth_failure_preserves_earlier_attempt_in_final_report(self):
        result = scheduler.run(self.repo, packages=[PACKAGE], agents=['quota', 'auth'],
                               apply=True, task_timeout=5)
        self.assertEqual(result['status'], 'auth', result)
        self.assertEqual(result['items'][0]['attempts'][0]['outcome'], 'quota', result)
        self.assertIn('quota', Path(result['report']).read_text(encoding='utf-8'))

    def test_exhausted_quota_agent_is_not_retried_on_later_task(self):
        self.git('switch', 'feat/001-test')
        path = self.repo / PACKAGE / 'tasks.md'
        path.write_text(path.read_text().replace('Later (gate: CP2)', 'Later (gate: CP1)'))
        self.git('add', '.')
        self.git('commit', '-m', 'fixture: two eligible tasks')
        self.git('switch', 'main')
        result = scheduler.run(self.repo, packages=[PACKAGE], agents=['quota', 'done'],
                               apply=True, task_timeout=5, max_tasks=2)
        self.assertEqual([[a['agent'] for a in r['attempts']] for r in result['items']],
                         [['quota', 'done'], ['done']], result)

    def test_branch_switch_cannot_escape_quarantine_and_primary_ref_is_restored(self):
        for mode in ('protected-switch', 'foreign-ref'):
            with self.subTest(mode=mode):
                result = self.run_worker(mode)
                row = result['items'][0]
                self.assertEqual(row['outcome'], 'gate-violation', result)
                self.assertEqual(self.git('rev-parse', 'feat/001-test'), self.base)
                self.assertEqual(self.git('rev-parse', 'main'), self.base)
                self.assertEqual(self.git('status', '--porcelain'), '')
                worker = Path(row['worktree'])
                self.git('worktree', 'remove', '--force', str(worker))
                if mode == 'protected-switch':
                    self.git('branch', '-D', 'escaped')

    def test_hidden_dirty_gate_cannot_authorize_next_task(self):
        result = self.run_worker('hidden-gate', max_tasks=2)
        self.assertEqual(len(result['items']), 1, result)
        self.assertEqual(result['items'][0]['outcome'], 'uncommitted', result)

    def test_optional_review_saves_findings_but_does_not_clear_owner_gate(self):
        result = self.run_worker(review=True, reviewer='review-accept', review_checkpoint='CP2')
        self.assertEqual(result['reviews'][0]['outcome'], 'accept', result)
        source = Path(result['items'][0]['worktree'])
        self.assertEqual(scheduler._select(self.repo, [PACKAGE])[0]['checkpoints']['CP2']['state'], 'pending')
        findings = list((source / PACKAGE / 'reviews').glob('*-findings.md'))
        self.assertEqual(len(findings), 1)
        self.assertEqual(self.git('status', '--porcelain', repo=source), '')

    def test_review_changes_address_and_second_round_are_bounded(self):
        result = self.run_worker(review=True, reviewer='review-changes', review_checkpoint='CP2')
        reviewed = result['reviews'][0]
        self.assertEqual(reviewed['outcome'], 'accept', result)
        self.assertEqual([r['phase'] for r in reviewed['rounds']], ['review', 'address', 'review'])
        self.assertEqual(reviewed['review_rounds'], 2)

    def test_review_missing_and_committed_code_scope_violation_are_reported(self):
        result = self.run_worker(review=True, reviewer='no-progress', review_checkpoint='CP2')
        self.assertEqual(result['reviews'][0]['outcome'], 'review-missing', result)
        # Fresh package branch fixtures for each reviewer violation.
        worker = Path(result['items'][0]['worktree'])
        self.git('worktree', 'remove', '--force', str(worker))
        self.git('update-ref', 'refs/heads/feat/001-test', self.base)
        for mode in ('review-extra', 'review-undo'):
            with self.subTest(mode=mode):
                result = self.run_worker(review=True, reviewer=mode, review_checkpoint='CP2')
                reviewed = result['reviews'][0]
                self.assertEqual(reviewed['outcome'], 'gate-violation', result)
                response = reviewed['rounds'][0]
                self.assertTrue(response['rejected_ref'])
                self.assertEqual(self.git('rev-parse', 'feat/001-test'), response['base'])
                worker = Path(result['items'][0]['worktree'])
                self.git('worktree', 'remove', '--force', str(worker))
                self.git('update-ref', 'refs/heads/feat/001-test', self.base)

    def test_exhausted_quota_stops_run_before_next_authorized_package(self):
        second = self.add_second_package()
        result = scheduler.run(self.repo, packages=[PACKAGE, second], agents=['quota'],
                               apply=True, max_tasks=5, task_timeout=5)
        self.assertEqual(result['status'], 'quota', result)
        self.assertEqual(len(result['items']), 1)

    def test_task_cap_and_expired_run_bound_stop_dispatch(self):
        second = self.add_second_package()
        result = scheduler.run(self.repo, packages=[PACKAGE, second], agents=['done'],
                               apply=True, max_tasks=1, task_timeout=5)
        self.assertEqual(len(result['items']), 1, result)
        self.assertEqual(result['stops'], ['Task limit reached'])
        self.calls.unlink()
        result = scheduler.run(self.repo, packages=[second], agents=['done'], apply=True,
                               max_hours=1e-12, task_timeout=5)
        self.assertFalse(self.calls.exists())
        self.assertIn('Run time limit reached', result['stops'])

    def test_cli_preview_and_json_report_path(self):
        result = subprocess.run([sys.executable, '-m', 'wfk', 'run', '--repo', str(self.repo),
            '--package', PACKAGE, '--agents', 'done', '--json'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)['dry_run'])
        result = subprocess.run([sys.executable, '-m', 'wfk', 'run', '--repo', str(self.repo),
            '--package', PACKAGE, '--agents', 'done', '--apply', '--json'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(Path(json.loads(result.stdout)['report']).is_file())


if __name__ == '__main__':
    unittest.main()
