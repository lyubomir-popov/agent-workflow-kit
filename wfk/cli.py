"""Command line interface for the portable kit."""

import argparse
import json
import sys
from pathlib import Path

from . import config, worktrees
from .git import repo_root


def _options(parser, roots=False):
    parser.add_argument('--repo', type=Path, help='repository (default: current directory)')
    parser.add_argument('--json', action='store_true', help='machine-readable output')
    if roots:
        parser.add_argument('--root', action='append', type=Path, help='discover repositories below root')
        parser.add_argument('--size', action='store_true', help='include disk use (slower)')


def parser():
    root = argparse.ArgumentParser(prog='wfk', description='Portable workflow kit')
    commands = root.add_subparsers(dest='command', required=True)
    wt = commands.add_parser('wt', help='worktree hygiene').add_subparsers(dest='operation', required=True)
    create = wt.add_parser('new', help='create a worktree')
    create.add_argument('branch')
    create.add_argument('--from', dest='start')
    _options(create)
    listing = wt.add_parser('ls', help='list Git worktrees and landed branches')
    _options(listing, roots=True)
    clean = wt.add_parser('clean', help='preview cleanup; use --apply to act')
    _options(clean, roots=True)
    clean.add_argument('--apply', action='store_true')
    clean.add_argument('--quiet', action='store_true')
    clean.add_argument('--branches', action='store_true', help='also delete eligible standalone local branches')
    hooks = commands.add_parser('hooks', help='composing cleanup hooks').add_subparsers(
        dest='operation', required=True)
    install = hooks.add_parser('install', help='preview hook installation')
    _options(install)
    install.add_argument('--apply', action='store_true')
    hook_run = hooks.add_parser('run', help=argparse.SUPPRESS)
    _options(hook_run)
    hook_run.add_argument('--apply', action='store_true')
    lint = commands.add_parser('lint', help='check workflow owners offline and read-only')
    _options(lint)
    create = commands.add_parser('new', help='preview a draft package and local branch')
    create.add_argument('short_name')
    _options(create)
    create.add_argument('--apply', action='store_true')
    initialize = commands.add_parser('init', help='add missing workflow files without overwriting')
    _options(initialize)
    initialize.add_argument('--apply', action='store_true')
    prompt = commands.add_parser('prompts', help='user prompt installation').add_subparsers(
        dest='operation', required=True)
    install = prompt.add_parser('install', help='preview VS Code and Insiders prompt installation')
    install.add_argument('--json', action='store_true')
    install.add_argument('--apply', action='store_true')
    run = commands.add_parser('run', help='preview bounded package scheduling; --apply to dispatch')
    _options(run)
    run.add_argument('--package', action='append', help='authorize this catalog package (repeatable)')
    run.add_argument('--agents', default='codex', help='ordered comma-separated worker profiles')
    run.add_argument('--apply', action='store_true')
    run.add_argument('--max-tasks', type=int, default=1)
    run.add_argument('--max-hours', type=float, default=8)
    run.add_argument('--task-timeout', type=float, default=1800, help='seconds per worker')
    run.add_argument('--review', action='store_true', help='request a bounded saved review after progress')
    run.add_argument('--reviewer', help='reviewer profile (default: configured reviewer)')
    run.add_argument('--review-checkpoint', help='uncleared checkpoint to review, e.g. CP4')
    return root


def _repos(args):
    if args.repo and args.root:
        raise ValueError('Choose --repo or --root')
    roots = args.root
    if not roots and not args.repo:
        roots = config.load()['repoRoots']
    if roots:
        return worktrees.discover(roots)
    root = worktrees.primary(repo_root(args.repo or Path.cwd()))
    return [root], []


def _human(result):
    if 'items' not in result:
        print(result.get('path', result.get('reason', 'Done')))
    for row in result.get('items', []):
        if 'kind' not in row:
            action = row.get('action', row.get('status', ''))
            path = row.get('path', row.get('package', row.get('hook', '')))
            print(f'{action}: {path}')
            continue
        label = row['branch'] or (row['commit'] or '')[:12] or 'orphan'
        flags = ', '.join(k for k in ('tracked', 'untracked', 'locked', 'prunable') if row[k]) or row['status']
        landing = 'landed' if row['landed'] else 'unlanded'
        action = row.get('action', row['kind'])
        size = f" | {row['size_bytes']} bytes" if row['size_bytes'] is not None else ''
        print(f"{action}: {row['repo']} | {row['path'] or '(no worktree)'} | {label} | "
              f"{flags} | {landing} | target={row['target']} ({row['target_source']}) | "
              f"{row['last_commit'] or 'unknown date'}{size} | {row['reason']}")
    if result.get('dry_run'):
        print('Dry run; use --apply to act.')
    if result.get('report'):
        print('Report: ' + result['report'])
    for item in result.get('checklist', []):
        print(f'Manual: {item}')
    if 'errors' in result:
        print(f"{len(result['errors'])} error(s), {len(result.get('warnings', []))} warning(s)")


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if args.command == 'wt' and args.operation == 'new':
            result = worktrees.new(args.repo or Path.cwd(), args.branch, args.start)
        elif args.command == 'wt':
            repos, warnings = _repos(args)
            if args.operation == 'ls':
                result = worktrees.inventory(repos, size=args.size,
                                             scratch_roots=config.load()['scratchRoots'])
            else:
                result = worktrees.clean(repos, apply=args.apply, quiet=args.quiet,
                                         scratch_roots=config.load()['scratchRoots'], branches=args.branches)
            result['warnings'] = warnings + result['warnings']
        elif args.command == 'hooks':
            from . import hooks
            repo = repo_root(args.repo or Path.cwd())
            result = (hooks.install(repo, apply=args.apply) if args.operation == 'install'
                      else hooks.run(repo, apply=args.apply))
        elif args.command == 'lint':
            from .workflow import lint
            result = lint(args.repo or Path.cwd())
        elif args.command in ('init', 'new'):
            from . import adoption
            result = (adoption.initialize(args.repo or Path.cwd(), apply=args.apply)
                      if args.command == 'init' else adoption.new(
                          args.repo or Path.cwd(), args.short_name, apply=args.apply))
        elif args.command == 'prompts':
            from . import prompts
            result = prompts.install(apply=args.apply)
        elif args.command == 'run':
            from . import scheduler
            agents = [name.strip() for name in args.agents.split(',')]
            if any(not name for name in agents):
                raise ValueError('--agents requires nonempty profile names')
            result = scheduler.run(args.repo or Path.cwd(), packages=args.package, agents=agents,
                apply=args.apply, max_tasks=args.max_tasks, max_hours=args.max_hours,
                task_timeout=args.task_timeout, review=args.review, reviewer=args.reviewer,
                review_checkpoint=args.review_checkpoint)
        else:
            raise ValueError(f'{args.command} awaits slice C and its owner gate')
        for warning in result.get('warnings', []):
            print(warning, file=sys.stderr)
        for error in result.get('errors', []):
            print(error, file=sys.stderr)
        if args.json:
            print(json.dumps(result, ensure_ascii=True))
        elif not getattr(args, 'quiet', False):
            _human(result)
        return 1 if result.get('errors') else 0
    except (ValueError, OSError) as exc:
        if args.json:
            print(json.dumps({'error': str(exc)}))
        else:
            print(f'wfk: {exc}', file=sys.stderr)
        return 1
