import tempfile
import unittest
from pathlib import Path

from wfk import reviews
from wfk.git import git


class ReviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='wfk reviews spaces ')
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        git(self.repo, 'init', '-q')
        git(self.repo, 'config', 'user.name', 'Fixture')
        git(self.repo, 'config', 'user.email', 'fixture@example.invalid')
        self.name = 'specs/003-example'
        self.directory = self.repo / self.name / 'reviews'
        self.directory.mkdir(parents=True)
        (self.repo / 'code.txt').write_text('initial\n')
        git(self.repo, 'add', '.')
        git(self.repo, 'commit', '-qm', 'fixture')
        self.package = dict(source=self.repo, package=self.name,
                            checkpoints={'CP4': {'state': 'pending', 'links': []}})
        self.task = dict(id='T011', complete=True, description='fixture work')
        self.calls = []

    def run_reviews(self, callback, **kwargs):
        return reviews.run(self.repo, self.package, self.task, 'CP4', 'reviewer',
                           'implementer', callback, kwargs.get('run_id', 'run 1'))

    def write_findings(self, path, verdict='accept', revision=None, reviewer='reviewer'):
        revision = revision or git(self.repo, 'rev-parse', 'HEAD').stdout.strip()
        (self.repo / path).write_text(f'# Checkpoint review\n\nReviewer: {reviewer}\n'
            f'Reviewed revision: {revision}\nVerdict: {verdict}\n\n'
            + ('No findings.\n' if verdict == 'accept' else '1. **Major**: fix code.\n'))

    def callback(self, phase, agent, prompt, allowed_new_reviews=()):
        self.calls.append((phase, agent, prompt, allowed_new_reviews))
        self.write_findings(allowed_new_reviews[0])
        return {'outcome': 'done'}

    def test_accept_saves_only_named_findings_and_preserves_owner_gate(self):
        result = self.run_reviews(self.callback)
        self.assertEqual(result['outcome'], 'accept')
        phase, agent, prompt, paths = self.calls[0]
        self.assertEqual((phase, agent), ('review', 'reviewer'))
        self.assertEqual(len(paths), 1)
        self.assertIn(paths[0], prompt)
        self.assertIn('Reviewed revision:', prompt)
        self.assertIn('/review', prompt)
        self.assertEqual(git(self.repo, 'status', '--porcelain').stdout, '')
        self.assertEqual(self.package['checkpoints']['CP4']['state'], 'pending')
        self.assertTrue(git(self.repo, 'show', 'HEAD:' + paths[0]).stdout)

    def test_missing_or_invalid_findings_are_review_missing(self):
        for text in (None, 'Verdict: accept\n', 'Reviewer: reviewer\n'
                     'Reviewed revision: stale\nVerdict: accept\n'):
            with self.subTest(text=text):
                def callback(phase, agent, prompt, allowed_new_reviews=()):
                    if text is not None:
                        (self.repo / allowed_new_reviews[0]).write_text(text)
                    return {'outcome': 'done'}
                result = self.run_reviews(callback, run_id=str(text))
                self.assertEqual(result['outcome'], 'review-missing')
                for path in self.directory.iterdir():
                    path.unlink()

    def test_changes_address_commit_dispositions_and_second_review(self):
        count = 0
        def callback(phase, agent, prompt, allowed_new_reviews=()):
            nonlocal count
            self.calls.append(phase)
            if phase == 'review':
                count += 1
                self.write_findings(allowed_new_reviews[0], 'changes' if count == 1 else 'accept')
            else:
                (self.repo / 'code.txt').write_text('fixed\n')
                git(self.repo, 'add', 'code.txt')
                git(self.repo, 'commit', '-qm', 'fix fixture')
                (self.repo / allowed_new_reviews[0]).write_text(
                    '# Dispositions\n\nResponse to [' + 'findings](' +
                    next(self.directory.glob('*findings.md')).name + ')\n\n'
                    '1. Fixed: code and validation.\n')
            return {'outcome': 'done'}
        result = self.run_reviews(callback)
        self.assertEqual(result['outcome'], 'accept')
        self.assertEqual(self.calls, ['review', 'address', 'review'])
        self.assertEqual(len(list(self.directory.glob('*dispositions.md'))), 1)

    def test_two_changes_stop_without_third_round_across_runs(self):
        for name in ('2020-01-01-CP4-opus-findings.md',
                     '2020-01-01-CP4-integration-findings.md',
                     '2020-01-01-CP4-self-findings.md'):
            identity = ('integration review' if '-integration-' in name else
                        'self review' if '-self-' in name else 'reviewer')
            self.write_findings(f'{self.name}/reviews/{name}', 'changes', reviewer=identity)
        git(self.repo, 'add', '.')
        git(self.repo, 'commit', '-qm', 'existing review')
        def callback(phase, agent, prompt, allowed_new_reviews=()):
            self.calls.append(phase)
            self.write_findings(allowed_new_reviews[0], 'changes')
            return {'outcome': 'done'}
        result = self.run_reviews(callback)
        self.assertEqual(result['outcome'], 'changes')
        self.assertEqual(self.calls, ['review'])
        result = self.run_reviews(callback, run_id='another')
        self.assertEqual(result['outcome'], 'changes')
        self.assertEqual(self.calls, ['review'])

    def test_failures_stop_immediately(self):
        for failure in ('auth', 'quota', 'timeout', 'gate-violation', 'error'):
            with self.subTest(failure=failure):
                result = self.run_reviews(lambda *a, **k: {'outcome': failure})
                self.assertEqual(result['outcome'], failure)

    def test_unknown_cleared_gate_and_dirty_checkout_do_not_dispatch(self):
        def forbidden(*a, **k):
            self.fail('unexpected dispatch')
        self.package['checkpoints'] = {}
        self.assertEqual(self.run_reviews(forbidden)['outcome'], 'error')
        self.package['checkpoints'] = {'CP4': {'state': 'owner-cleared'}}
        self.assertEqual(self.run_reviews(forbidden)['outcome'], 'error')
        self.package['checkpoints']['CP4']['state'] = 'pending'
        (self.repo / 'unrelated').write_text('preserve')
        self.assertEqual(self.run_reviews(forbidden)['outcome'], 'error')

    def test_extra_dirty_file_is_not_staged_or_committed(self):
        before = git(self.repo, 'rev-parse', 'HEAD').stdout
        def callback(*args, **kwargs):
            self.callback(*args, **kwargs)
            (self.repo / 'extra').write_text('preserve')
            return {'outcome': 'done'}
        self.assertEqual(self.run_reviews(callback)['outcome'], 'gate-violation')
        self.assertEqual(git(self.repo, 'rev-parse', 'HEAD').stdout, before)
        self.assertEqual(git(self.repo, 'diff', '--cached', '--name-only').stdout, '')

    def test_address_requires_implementation_commit_and_valid_dispositions(self):
        def callback(phase, agent, prompt, allowed_new_reviews=()):
            if phase == 'review':
                self.write_findings(allowed_new_reviews[0], 'changes')
            else:
                (self.repo / allowed_new_reviews[0]).write_text('unstructured response')
            return {'outcome': 'done'}
        self.assertEqual(self.run_reviews(callback)['outcome'], 'review-missing')

    def test_reused_run_id_creates_distinct_round_without_overwriting(self):
        self.run_reviews(self.callback)
        original = next(self.directory.glob('*findings.md'))
        data = original.read_bytes()
        result = self.run_reviews(self.callback)
        self.assertEqual(result['outcome'], 'accept')
        self.assertEqual(original.read_bytes(), data)
        self.assertEqual(len(list(self.directory.glob('*findings.md'))), 2)

    def test_new_findings_must_identify_dispatched_independent_profile(self):
        for identity in ('self review', 'integration review', 'unrelated-profile'):
            with self.subTest(identity=identity):
                def callback(phase, agent, prompt, allowed_new_reviews=()):
                    self.write_findings(allowed_new_reviews[0], reviewer=identity)
                    return {'outcome': 'done'}
                self.assertEqual(self.run_reviews(callback)['outcome'], 'review-missing')
                for path in self.directory.iterdir():
                    path.unlink()

    def test_exclusion_words_in_identifiers_do_not_bypass_cap_across_runs(self):
        def callback(phase, agent, prompt, allowed_new_reviews=()):
            self.calls.append(phase)
            self.write_findings(allowed_new_reviews[0], reviewer=agent)
            return {'outcome': 'done'}
        for index in range(3):
            result = reviews.run(self.repo, self.package, self.task, 'CP4',
                'integration', 'implementer', callback, f'self-{index}')
            self.assertEqual(result['outcome'], 'accept' if index < 2 else 'changes')
        self.assertEqual(self.calls, ['review', 'review'])

    def test_generated_record_with_spoofed_identity_still_consumes_round(self):
        def callback(phase, agent, prompt, allowed_new_reviews=()):
            self.write_findings(allowed_new_reviews[0], reviewer='self review')
            git(self.repo, 'add', allowed_new_reviews[0])
            git(self.repo, 'commit', '-qm', 'invalid precommitted review')
            return {'outcome': 'done'}
        self.assertEqual(self.run_reviews(callback)['outcome'], 'review-missing')
        self.assertEqual(self.run_reviews(self.callback, run_id='second')['outcome'], 'accept')
        self.assertEqual(self.run_reviews(self.callback, run_id='third')['outcome'], 'changes')
        self.assertEqual(len(self.calls), 1)

    def test_legacy_exclusions_require_explicit_header_not_filename(self):
        for name in ('2020-01-01-CP4-integration-findings.md',
                     '2020-01-01-CP4-self-findings.md'):
            self.write_findings(f'{self.name}/reviews/{name}')
        git(self.repo, 'add', '.')
        git(self.repo, 'commit', '-qm', 'independent records with misleading names')
        self.assertEqual(self.run_reviews(self.callback)['outcome'], 'changes')
        self.assertEqual(self.calls, [])

    def test_nonindependent_configured_identity_never_dispatches(self):
        for identity in ('self review', 'GPT orchestrator (self-review, not Opus)',
                         'integration-review'):
            with self.subTest(identity=identity):
                result = reviews.run(self.repo, self.package, self.task, 'CP4',
                    identity, 'implementer', self.callback, 'run')
                self.assertEqual(result['outcome'], 'error')
        self.assertEqual(self.calls, [])

    def test_precommitted_findings_use_predispatch_revision(self):
        def callback(*args, **kwargs):
            self.callback(*args, **kwargs)
            git(self.repo, 'add', kwargs['allowed_new_reviews'][0])
            git(self.repo, 'commit', '-qm', 'reviewer saved findings')
            return {'outcome': 'done'}
        self.assertEqual(self.run_reviews(callback)['outcome'], 'accept')

    def test_duplicate_headers_are_invalid(self):
        def callback(*args, **kwargs):
            self.callback(*args, **kwargs)
            path = self.repo / kwargs['allowed_new_reviews'][0]
            path.write_text(path.read_text() + '\nVerdict: changes\n')
            return {'outcome': 'done'}
        self.assertEqual(self.run_reviews(callback)['outcome'], 'review-missing')

    def test_existing_evidence_change_is_rejected(self):
        previous = self.directory / 'owner-decision.md'
        previous.write_text('immutable owner evidence')
        git(self.repo, 'add', '.')
        git(self.repo, 'commit', '-qm', 'saved owner evidence')
        def callback(*args, **kwargs):
            self.callback(*args, **kwargs)
            previous.write_text('changed')
            return {'outcome': 'done'}
        self.assertEqual(self.run_reviews(callback)['outcome'], 'gate-violation')

    def test_missing_dispositions_and_address_failure_stop_before_second_review(self):
        def callback(phase, agent, prompt, allowed_new_reviews=()):
            self.calls.append(phase)
            if phase == 'review':
                self.write_findings(allowed_new_reviews[0], 'blocker')
                return {'outcome': 'done'}
            return {'outcome': 'auth'}
        self.assertEqual(self.run_reviews(callback)['outcome'], 'auth')
        self.assertEqual(self.calls, ['review', 'address'])

    def test_package_path_escape_is_rejected_before_dispatch(self):
        self.package['package'] = '../outside'
        self.assertEqual(self.run_reviews(self.callback)['outcome'], 'error')
        self.assertEqual(self.calls, [])

    def test_address_implementation_without_dispositions_is_incomplete(self):
        def callback(phase, agent, prompt, allowed_new_reviews=()):
            if phase == 'review':
                self.write_findings(allowed_new_reviews[0], 'changes')
            else:
                (self.repo / 'code.txt').write_text('fixed\n')
                git(self.repo, 'add', 'code.txt')
                git(self.repo, 'commit', '-qm', 'implementation')
            return {'outcome': 'done'}
        self.assertEqual(self.run_reviews(callback)['outcome'], 'review-missing')

    def test_unsafe_run_id_cannot_escape_review_directory(self):
        result = self.run_reviews(self.callback, run_id='../../outside / & weird')
        self.assertEqual(result['outcome'], 'accept')
        path = self.repo / self.calls[0][3][0]
        self.assertEqual(path.parent, self.directory)

    def test_review_symlink_is_rejected(self):
        outside = self.repo / 'outside.md'
        outside.write_text('preserve')
        def callback(phase, agent, prompt, allowed_new_reviews=()):
            try:
                (self.repo / allowed_new_reviews[0]).symlink_to(outside)
            except OSError:
                self.skipTest('symlinks unavailable')
            return {'outcome': 'done'}
        git(self.repo, 'add', 'outside.md')
        git(self.repo, 'commit', '-qm', 'outside fixture')
        self.assertEqual(self.run_reviews(callback)['outcome'], 'review-missing')
        self.assertEqual(outside.read_text(), 'preserve')


if __name__ == '__main__':
    unittest.main()
