import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from wfk.protection import audit, quarantine


class ProtectionFixture(unittest.TestCase):
    def setUp(self):
        environment = patch.dict(os.environ, {'GIT_CONFIG_GLOBAL': os.devnull,
                                               'GIT_CONFIG_NOSYSTEM': '1'})
        environment.start()
        self.addCleanup(environment.stop)
        self.temporary = tempfile.TemporaryDirectory()
        self.repo = Path(self.temporary.name)
        self.git('init', '-b', 'feature')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'user.name', 'Fixture')
        self.write('.workflow-kit.json', '{"targetBranch":"main"}\n')
        self.write('docs/specs.md', '# Catalog\n\n| Spec | Package | Branch |\n')
        self.write('ordinary.txt', 'base bytes\n')
        self.write('specs/001-demo/spec.md', self.spec('001', 'Demo'))
        self.write('specs/001-demo/tasks.md', self.tasks())
        self.write('specs/001-demo/reviews/existing.md', '# Owner evidence\nKeep this.\n')
        self.write('specs/001-demo/reviews/rename me.md', '# Owner evidence\n')
        self.write('specs/001-demo/reviews/delete me.md', '# Owner evidence\n')
        self.write('specs/002-other/spec.md', self.spec('002', 'Other'))
        self.write('specs/002-other/tasks.md', self.tasks())
        self.write('specs/002-other/reviews/révision δ.md', '# Other owner evidence\n')
        self.base = self.save('fixture base')

    def tearDown(self):
        self.temporary.cleanup()

    def git(self, *args, check=True, input=None):
        result = subprocess.run(
            ['git', '-C', str(self.repo), *args], input=input, capture_output=True,
            text=True, encoding='utf-8', errors='surrogateescape',
        )
        if check and result.returncode:
            self.fail(result.stderr or result.stdout)
        return result

    def write(self, relative, text):
        path = self.repo / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8')

    def save(self, message):
        self.git('add', '-A')
        self.git('commit', '-m', message)
        return self.git('rev-parse', 'HEAD').stdout.strip()

    @staticmethod
    def spec(number, name):
        return (
            f'# Feature specification: {name}\n\n'
            f'**Feature branch**: `feature/{number}`\n'
            '**Lifecycle**: active\n'
            f'**Scope**: `{number}/spec-r1`\n\n'
            '**Checkpoints**:\n\n'
            '| ID | Gate | Verdict link | State |\n'
            '|---|---|---|---|\n'
            '| CP1 | Entry | owner decision | owner-cleared |\n'
            '| CP2 | Later | pending | pending |\n\n'
            '## Body\n\nImplementation details.\n'
        )

    @staticmethod
    def tasks():
        return (
            '# Current work\n\n'
            '**Next tasks**: T001.\n'
            '**Entry checkpoint**: CP1\n\n'
            '## Work\n\n'
            '- [ ] T001 Implement the dispatched change (gate: CP1).\n'
            '- [ ] T002 Wait for the owner (gate: CP2) (manual).\n'
            '- [x] T003 Earlier completed work (gate: CP1).\n'
        )

    def reasons(self, tip=None, **kwargs):
        return audit(
            self.repo, self.base, tip or self.git('rev-parse', 'HEAD').stdout.strip(),
            'specs/001-demo', 'T001', **kwargs,
        )

    def assertReason(self, reasons, fragment):
        self.assertTrue(any(fragment in reason for reason in reasons), reasons)

    def test_allows_focused_completion_human_header_body_and_plain_new_notes(self):
        self.write('specs/001-demo/tasks.md', self.tasks().replace(
            '**Next tasks**: T001.', '**Next tasks**: T002.').replace(
            '- [ ] T001', '- [x] T001') + '\nHuman progress note.\n')
        self.write('specs/001-demo/spec.md', self.spec('001', 'Demo').replace(
            'Implementation details.', 'Updated implementation details.'))
        self.write('specs/001-demo/reviews/worker notes 終.md',
                   '# Implementation observations\nNo gate fields.\n')
        self.write('nested/unicode δ file.txt', 'ordinary worker output\n')
        self.save('allowed worker commit')
        self.assertEqual([], self.reasons())

    def test_rejects_policy_deletion_and_mode_change(self):
        (self.repo / '.workflow-kit.json').unlink()
        tip = self.save('delete policy')
        self.assertReason(self.reasons(tip), 'owner workflow policy')

        # Audit a separate descendant range whose first commit changes only the
        # protected file mode. update-index works even when core.filemode is false.
        self.write('.workflow-kit.json', '{"targetBranch":"main"}\n')
        restored = self.save('restore policy outside audited range')
        self.git('update-index', '--chmod=+x', '.workflow-kit.json')
        # Commit the staged mode directly. `add -A` on a filemode-aware POSIX
        # filesystem would correctly restore the unchanged on-disk mode.
        self.git('commit', '-m', 'change policy mode')
        mode_tip = self.git('rev-parse', 'HEAD').stdout.strip()
        reasons = audit(self.repo, restored, mode_tip, 'specs/001-demo', 'T001')
        self.assertReason(reasons, 'mode')

    def test_rejects_catalog_authorization_change(self):
        self.write('docs/specs.md', '# Worker-selected catalog\n')
        self.save('edit catalog')
        self.assertReason(self.reasons(), 'catalog authorization')

    def test_protects_every_spec_header_but_allows_body_changes(self):
        self.write('specs/002-other/spec.md', self.spec('002', 'Other').replace(
            '**Lifecycle**: active', '**Lifecycle**: delivered'))
        self.write('specs/001-demo/spec.md', self.spec('001', 'Demo').replace(
            'Implementation details.', 'Legitimate body update.'))
        self.save('spec edits')
        reasons = self.reasons()
        self.assertReason(reasons, 'owner spec header/checkpoint table')
        self.assertTrue(any('specs/002-other/spec.md' in reason for reason in reasons), reasons)
        self.assertFalse(any('specs/001-demo/spec.md' in reason for reason in reasons), reasons)

    def test_rejects_existing_review_edit_delete_rename_and_unicode_path(self):
        self.write('specs/001-demo/reviews/existing.md', '# Rewritten evidence\n')
        (self.repo / 'specs/001-demo/reviews/delete me.md').unlink()
        self.git('mv', 'specs/001-demo/reviews/rename me.md',
                 'specs/001-demo/reviews/renamed.md')
        self.write('specs/002-other/reviews/révision δ.md', '# Rewritten other evidence\n')
        self.save('tamper with reviews')
        reasons = self.reasons()
        for path in ('existing.md', 'delete me.md', 'rename me.md', 'révision δ.md'):
            self.assertTrue(any(path in reason for reason in reasons), (path, reasons))

    def test_new_reviews_need_no_gate_labels_unless_exactly_whitelisted(self):
        labels = ('Verdict', 'Accepted scope', 'Checkpoint', 'Scope', 'Reviewer',
                  'Reviewed revision')
        for index, label in enumerate(labels):
            self.write(f'specs/001-demo/reviews/fabricated-{index}.md',
                       f'- **{label}**: worker supplied\n')
        allowed = 'specs/001-demo/reviews/requested findings.md'
        self.write(allowed,
                   'Reviewer: Requested reviewer\nReviewed revision: fixture\nVerdict: changes\n')
        self.save('add review records')
        reasons = self.reasons(allowed_new_reviews=(allowed,))
        for index in range(len(labels)):
            self.assertTrue(any(f'fabricated-{index}.md' in reason for reason in reasons), reasons)
        self.assertFalse(any(allowed in reason for reason in reasons), reasons)

    def test_encoded_gate_metadata_and_new_review_symlink_cannot_bypass_audit(self):
        encoded = self.repo / 'specs/001-demo/reviews/encoded.md'
        encoded.write_bytes('Verdict: accept\n'.encode('utf-16'))
        self.git('add', 'specs/001-demo/reviews/encoded.md')
        target = self.git('hash-object', '-w', '--stdin',
                          input='ordinary.txt\n').stdout.strip()
        linked = 'specs/001-demo/reviews/linked.md'
        self.git('update-index', '--add', '--cacheinfo', '120000', target, linked)
        self.git('commit', '-m', 'attempt encoded and symlink review bypasses')
        reasons = self.reasons()
        self.assertTrue(any('encoded.md' in reason and 'gate metadata' in reason
                            for reason in reasons), reasons)
        self.assertTrue(any('linked.md' in reason and 'unsafe mode' in reason
                            for reason in reasons), reasons)

    def test_whitelist_never_allows_modifying_an_existing_review(self):
        existing = 'specs/001-demo/reviews/existing.md'
        self.write(existing, 'Reviewer: Worker\nVerdict: accept\n')
        self.save('rewrite whitelisted existing review')
        self.assertReason(self.reasons(allowed_new_reviews=(existing,)),
                          'existing review record')

    def test_rejects_other_checkbox_and_new_completed_task(self):
        text = self.tasks().replace('- [ ] T002', '- [x] T002')
        text += '- [x] T004 Worker-created completed task (gate: CP1).\n'
        self.write('specs/001-demo/tasks.md', text)
        self.save('complete unauthorized work')
        reasons = self.reasons()
        self.assertReason(reasons, 'unrelated task T002 newly completed')
        self.assertReason(reasons, 'task IDs added, removed or reordered')

    def test_rejects_task_identity_order_gate_manual_and_entry_changes(self):
        changed = self.tasks().replace('**Entry checkpoint**: CP1',
                                       '**Entry checkpoint**: CP2')
        changed = changed.replace(
            '- [ ] T001 Implement the dispatched change (gate: CP1).\n'
            '- [ ] T002 Wait for the owner (gate: CP2) (manual).',
            '- [ ] T002 Wait for the owner (gate: CP1).\n'
            '- [ ] T001 Implement the dispatched change (manual).')
        self.write('specs/001-demo/tasks.md', changed)
        self.save('rewrite task declarations')
        reasons = self.reasons()
        for fragment in ('entry checkpoint', 'IDs added, removed or reordered',
                         'gate annotation changed', 'manual annotation changed'):
            self.assertReason(reasons, fragment)

    def test_rejects_task_checkbox_changed_from_done_to_undone(self):
        self.write('specs/001-demo/tasks.md', self.tasks().replace('- [x] T003', '- [ ] T003'))
        self.save('undo completed task')
        self.assertReason(self.reasons(), 'checkbox changed outside dispatched completion')

    def test_inspects_intermediate_commits_even_when_violation_is_reverted(self):
        original = (self.repo / '.workflow-kit.json').read_text(encoding='utf-8')
        self.write('.workflow-kit.json', '{"targetBranch":"worker-selected"}\n')
        self.save('temporary policy violation')
        self.write('.workflow-kit.json', original)
        self.write('specs/001-demo/tasks.md', self.tasks().replace('- [ ] T001', '- [x] T001'))
        self.save('restore policy and finish task')
        self.assertReason(self.reasons(), 'owner workflow policy')

    def test_fails_closed_for_non_descendant_and_merge_history(self):
        tree = self.git('rev-parse', f'{self.base}^{{tree}}').stdout.strip()
        rewritten = self.git('commit-tree', tree, input='rewritten root\n').stdout.strip()
        self.assertReason(self.reasons(rewritten), 'does not descend from base')

        self.write('left.txt', 'left\n')
        self.save('left commit')
        self.git('switch', '-c', 'side', self.base)
        self.write('right.txt', 'right\n')
        self.save('right commit')
        self.git('switch', 'feature')
        self.git('merge', '--no-ff', 'side', '-m', 'merge worker histories')
        merge_tip = self.git('rev-parse', 'HEAD').stdout.strip()
        self.assertReason(self.reasons(merge_tip), 'merge/non-linear history')

    def test_successful_quarantine_preserves_ref_index_worktree_and_untracked_bytes(self):
        self.write('.workflow-kit.json', '{"targetBranch":"worker-selected"}\n')
        tip = self.save('rejected worker commit')
        self.write('ordinary.txt', 'staged inspection bytes\n')
        self.git('add', 'ordinary.txt')
        self.write('untracked evidence.txt', 'untracked inspection bytes\n')

        recovery = quarantine(self.repo, self.base, tip, 'T001')

        self.assertRegex(recovery, r'^refs/wfk/rejected/T001-[0-9]{8}T[0-9]+Z(?:-[0-9]+)?$')
        self.assertEqual(tip, self.git('rev-parse', recovery).stdout.strip())
        self.assertEqual(self.base, self.git('rev-parse', 'HEAD').stdout.strip())
        self.assertEqual('staged inspection bytes\n',
                         (self.repo / 'ordinary.txt').read_text(encoding='utf-8'))
        self.assertEqual('staged inspection bytes\n',
                         self.git('show', ':ordinary.txt').stdout)
        self.assertEqual('untracked inspection bytes\n',
                         (self.repo / 'untracked evidence.txt').read_text(encoding='utf-8'))
        self.assertTrue(self.git('status', '--porcelain').stdout)

    def test_quarantine_refuses_detached_or_unsafe_head(self):
        self.write('.workflow-kit.json', '{}\n')
        tip = self.save('worker commit')
        self.git('switch', '--detach', tip)
        with self.assertRaisesRegex(ValueError, 'detached'):
            quarantine(self.repo, self.base, tip, 'T001')
        self.assertEqual('', self.git('for-each-ref', '--format=%(refname)',
                                      'refs/wfk/rejected/').stdout)

        self.git('symbolic-ref', 'HEAD', 'refs/remotes/origin/unsafe')
        with self.assertRaisesRegex(ValueError, 'unsafe'):
            quarantine(self.repo, self.base, tip, 'T001')

    def test_explicit_branch_quarantine_works_after_worker_switches_branch(self):
        self.write('.workflow-kit.json', '{}\n')
        tip = self.save('worker commit on package branch')
        self.git('switch', '-c', 'worker-escape')
        self.write('ordinary.txt', 'staged bytes on escaped checkout\n')
        self.git('add', 'ordinary.txt')
        self.write('escaped untracked.txt', 'keep escaped evidence\n')

        recovery = quarantine(
            self.repo, self.base, tip, 'T001', branch='refs/heads/feature'
        )

        self.assertEqual(tip, self.git('rev-parse', recovery).stdout.strip())
        self.assertEqual(self.base,
                         self.git('rev-parse', 'refs/heads/feature').stdout.strip())
        self.assertEqual('refs/heads/worker-escape',
                         self.git('symbolic-ref', 'HEAD').stdout.strip())
        self.assertEqual(tip, self.git('rev-parse', 'HEAD').stdout.strip())
        self.assertEqual('staged bytes on escaped checkout\n',
                         (self.repo / 'ordinary.txt').read_text(encoding='utf-8'))
        self.assertEqual('keep escaped evidence\n',
                         (self.repo / 'escaped untracked.txt').read_text(encoding='utf-8'))

    def test_explicit_branch_quarantine_works_from_detached_head(self):
        self.write('.workflow-kit.json', '{}\n')
        tip = self.save('worker commit before detach')
        self.git('switch', '--detach', tip)

        recovery = quarantine(
            self.repo, self.base, tip, 'T001', branch='refs/heads/feature'
        )

        self.assertEqual(tip, self.git('rev-parse', recovery).stdout.strip())
        self.assertEqual(self.base,
                         self.git('rev-parse', 'refs/heads/feature').stdout.strip())
        self.assertEqual(tip, self.git('rev-parse', 'HEAD').stdout.strip())
        self.assertNotEqual(0, self.git('symbolic-ref', '--quiet', 'HEAD',
                                        check=False).returncode)

    def test_explicit_branch_requires_safe_full_local_ref(self):
        self.write('.workflow-kit.json', '{}\n')
        tip = self.save('worker commit')
        for branch in ('feature', 'refs/tags/feature', 'refs/heads/bad..name'):
            with self.subTest(branch=branch):
                with self.assertRaisesRegex(ValueError, 'unsafe'):
                    quarantine(self.repo, self.base, tip, 'T001', branch=branch)
        self.assertEqual('', self.git('for-each-ref', '--format=%(refname)',
                                      'refs/wfk/rejected/').stdout)

    def test_explicit_branch_refuses_symbolic_branch_ref_without_dereferencing_it(self):
        self.write('.workflow-kit.json', '{}\n')
        tip = self.save('worker commit')
        self.git('symbolic-ref', 'refs/heads/alias', 'refs/heads/feature')

        with self.assertRaisesRegex(ValueError, 'unsafe.*symbolic'):
            quarantine(self.repo, self.base, tip, 'T001',
                       branch='refs/heads/alias')

        self.assertEqual(tip,
                         self.git('rev-parse', 'refs/heads/feature').stdout.strip())
        self.assertEqual('refs/heads/feature',
                         self.git('symbolic-ref', 'refs/heads/alias').stdout.strip())
        self.assertEqual('', self.git('for-each-ref', '--format=%(refname)',
                                      'refs/wfk/rejected/').stdout)

    def test_explicit_branch_stale_tip_preserves_recovery_ref(self):
        self.write('.workflow-kit.json', '{}\n')
        tip = self.save('worker commit to preserve')
        self.write('ordinary.txt', 'package branch advanced\n')
        stale_head = self.save('unexpected package branch advance')
        self.git('switch', '-c', 'worker-escape')

        with self.assertRaisesRegex(RuntimeError, 'recovery ref preserved'):
            quarantine(self.repo, self.base, tip, 'T001',
                       branch='refs/heads/feature')

        self.assertEqual(stale_head,
                         self.git('rev-parse', 'refs/heads/feature').stdout.strip())
        refs = self.git('for-each-ref', '--format=%(refname) %(objectname)',
                        'refs/wfk/rejected/').stdout.splitlines()
        self.assertEqual(1, len(refs), refs)
        self.assertEqual(tip, refs[0].split()[1])

    def test_stale_tip_cas_failure_keeps_recovery_ref_and_branch(self):
        self.write('.workflow-kit.json', '{}\n')
        tip = self.save('worker commit to preserve')
        self.write('ordinary.txt', 'later branch commit\n')
        stale_head = self.save('branch advanced unexpectedly')

        with self.assertRaisesRegex(RuntimeError, 'recovery ref preserved'):
            quarantine(self.repo, self.base, tip, 'T001')

        self.assertEqual(stale_head, self.git('rev-parse', 'HEAD').stdout.strip())
        refs = self.git('for-each-ref', '--format=%(refname) %(objectname)',
                        'refs/wfk/rejected/').stdout.splitlines()
        self.assertEqual(1, len(refs), refs)
        self.assertEqual(tip, refs[0].split()[1])


if __name__ == '__main__':
    unittest.main()
