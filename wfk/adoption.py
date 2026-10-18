"""Non-overwriting adoption and offline, target-owned draft registration."""

from datetime import date
import json
import os
from pathlib import Path
import re
import stat
import tempfile

from .config import load, resolve_target
from .git import commit, git, repo_root


_KIT = Path(__file__).resolve().parents[1]
_TEMPLATES = _KIT / 'templates' / 'init'


def _safe_destination(repo, relative):
    path = repo / relative
    # Do not follow an existing directory link even when it resolves inside the
    # checkout: an exclusive leaf create alone cannot protect parent traversal.
    for part in (path, *path.parents):
        if part == repo:
            break
        try:
            attributes = getattr(part.lstat(), 'st_file_attributes', 0)
        except FileNotFoundError:
            attributes = 0
        if part.is_symlink() or attributes & getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 0):
            raise ValueError(f'Unsafe symlink destination: {relative}')
        if part != path and part.exists() and not part.is_dir():
            raise ValueError(f'Unsafe parent file collision: {relative}')
    if not path.resolve().is_relative_to(repo):
        raise ValueError(f'Unsafe destination outside repository: {relative}')
    return path


def initialize(repo, apply=False):
    repo = repo_root(repo)
    # A malformed existing local file still belongs to its owner. Validate user
    # defaults separately so only repository-config problems become manual work.
    settings = load()
    problem = None
    try:
        settings = load(repo)
    except ValueError as exc:
        target = None
        problem = f'Preserved .workflow-kit.json; manual configuration repair required: {exc}'
        settings['warnings'].append(problem)
    else:
        target, _ = resolve_target(repo)
    config = json.loads((_TEMPLATES / 'config.json').read_text(encoding='utf-8'))
    if target:
        config['targetBranch'] = target
    files = {
        '.workflow-kit.json': json.dumps(config, indent=2) + '\n',
        'AGENTS.md': (_KIT / 'templates' / 'AGENTS.md').read_text(encoding='utf-8'),
        'docs/specs.md': (_TEMPLATES / 'specs.md').read_text(encoding='utf-8'),
        'CLAUDE.md': (_TEMPLATES / 'CLAUDE.md').read_text(encoding='utf-8'),
        '.github/copilot-instructions.md': (
            _TEMPLATES / 'copilot-instructions.md').read_text(encoding='utf-8'),
    }
    for name in ('INBOX.md', 'AGENT-INBOX.md'):
        files[name] = (_TEMPLATES / name).read_text(encoding='utf-8')
    for name in ('spec-template.md', 'plan-template.md', 'tasks-template.md'):
        files[f'.specify/templates/overrides/{name}'] = (
            _TEMPLATES / name).read_text(encoding='utf-8')
    # Validate all paths before any write, including paths already present.
    paths = {name: _safe_destination(repo, name) for name in files}
    result = {'items': [], 'warnings': settings['warnings'], 'checklist': [],
              'dry_run': not apply}
    if problem:
        result['checklist'].append(problem)
    if not target:
        result['checklist'].append('Set targetBranch in .workflow-kit.json; target is unknown.')
    if os.path.lexists(paths['.workflow-kit.json']):
        try:
            existing = json.loads(paths['.workflow-kit.json'].read_text(encoding='utf-8-sig'))
        except (OSError, ValueError):
            existing = {}
        if not isinstance(existing, dict):
            existing = {}
        missing = [name for name in ('autoLoadedFiles', 'hostBudgets') if not existing.get(name)]
        if missing:
            result['checklist'].append(
                'Manually merge missing budget fields (' + ', '.join(missing) +
                ") from the kit's templates/init/config.json into existing .workflow-kit.json.")
    for name, content in files.items():
        path = paths[name]
        exists = os.path.lexists(path)
        status = 'preserved' if exists else 'planned'
        if exists:
            result['checklist'].append(f'Manually merge kit guidance into existing {name}.')
        elif apply:
            path.parent.mkdir(parents=True, exist_ok=True)
            try:
                with path.open('x', encoding='utf-8', newline='\n') as stream:
                    stream.write(content)
                status = 'created'
            except FileExistsError:
                status = 'preserved'
                result['checklist'].append(f'Manually merge kit guidance into existing {name}.')
        result['items'].append({'path': name, 'status': status})
    result['checklist'].append('Review the new files and commit the adopted kit owners when ready.')
    return result


def _read_revision(repo, revision, path):
    result = git(repo, 'show', f'{revision}:{path}', check=False)
    return result.stdout if result.returncode == 0 else None


def _number(repo, target):
    names = [segment for ref in git(repo, 'for-each-ref', '--format=%(refname)').stdout.splitlines()
             for segment in ref.split('/')]
    names += [path.split('/')[1] for path in git(
        repo, 'ls-tree', '-r', '--name-only', target, '--', 'specs').stdout.splitlines()
        if '/' in path]
    specs = repo / 'specs'
    if specs.is_dir():
        names += [p.name for p in specs.iterdir()]
    for revision in ('HEAD', target):
        names.extend(re.findall(r'specs/([0-9]{3,}-[^/)]+)',
                                _read_revision(repo, revision, 'docs/specs.md') or ''))
    numbers = [int(match.group(1)) for name in names
               for match in re.finditer(r'^([0-9]{3,})-(?![0-9]{6}-)', name)]
    return max(numbers, default=0) + 1


def _template(repo, target, name, required=False):
    for path in (f'.specify/templates/overrides/{name}', f'.specify/templates/{name}'):
        content = _read_revision(repo, target, path)
        if content is not None:
            return content
    if required:
        raise ValueError(f'Missing project {name}; run wfk init or restore the template.')
    return (_TEMPLATES / name).read_text(encoding='utf-8')


def _render(content, title, branch, number):
    values = {'[FEATURE NAME]': title, '[DECLARED CATALOG BRANCH]': branch,
              '[BRANCH_NAME]': branch, '[PACKAGE ID]': f'{number:03}',
              '[DATE]': date.today().isoformat(), '[OWNER INTENT]': title}
    for placeholder, value in values.items():
        content = content.replace(placeholder, value)
    return content


def _register(catalog, number, package, branch, title):
    heading = re.search(r'^## Current packages\s*$', catalog, re.MULTILINE)
    if not heading:
        raise ValueError('Catalog lacks a Current packages section; merge the init catalog manually.')
    tail = catalog[heading.end():]
    next_section = re.search(r'^## ', tail, re.MULTILINE)
    if next_section:
        tail = tail[:next_section.start()]
    separator = re.search(
        r'^\|[ \t]*Spec[ \t]*\|[ \t]*Package[ \t]*\|[ \t]*Branch[ \t]*\|[ \t]*\r?\n'
        r'\|[ \t]*:?-+:?[ \t]*\|[ \t]*:?-+:?[ \t]*\|[ \t]*:?-+:?[ \t]*\|[ \t]*$',
        tail, re.MULTILINE)
    if not separator:
        raise ValueError('Catalog Current packages table is missing its header separator.')
    position = heading.end() + separator.end()
    row = f'\n| {number:03} {title} | [{package}](../specs/{package}/spec.md) | `{branch}` |'
    return catalog[:position] + row + catalog[position:]


def _validate(repo):
    # Import only when needed, so adoption stays independent of CLI wiring.
    from .workflow import lint
    errors = lint(repo)['errors']
    if errors:
        raise ValueError(f'Workflow lint failed: {errors}')


def _check_index(repo, paths):
    staged = set(git(repo, 'diff', '--cached', '--name-only', '-z').stdout.rstrip('\0').split('\0'))
    if staged != set(paths):
        raise ValueError('Unexpected staged paths in index; preserve concurrent work and inspect before retrying.')


def _target_checkout(repo, target):
    local = f'refs/heads/{target}'
    if not commit(repo, local):
        raise ValueError(f'Target must be a local branch: {target}')
    records = git(repo, 'worktree', 'list', '--porcelain', '-z').stdout.split('\0\0')
    for record in records:
        fields = record.split('\0')
        if f'branch {local}' in fields:
            path = Path(next(field[9:] for field in fields if field.startswith('worktree '))).resolve()
            if path != repo:
                raise ValueError(f'Target branch is checked out elsewhere (busy): {path}')
            if git(repo, 'status', '--porcelain', '--untracked-files=all').stdout:
                raise ValueError('Package creation requires a clean target checkout and index.')
            return repo, None
    return None, None


def new(repo, short_name, apply=False):
    repo = repo_root(repo)
    if (not isinstance(short_name, str) or not short_name.strip() or
            short_name.startswith('-') or re.search(r'[/\\\r\n|`\[\]]', short_name) or
            '..' in short_name):
        raise ValueError('Provide a nonempty short name without paths or Markdown delimiters.')
    slug = re.sub(r'[^a-z0-9]+', '-', short_name.lower()).strip('-')
    if not slug or len(slug) > 180:
        raise ValueError('Short name must produce an ASCII branch slug of at most 180 characters.')
    target, source = resolve_target(repo)
    if not target:
        raise ValueError('Target branch is unknown; set targetBranch before package creation.')
    checkout, _ = _target_checkout(repo, target)
    number = _number(repo, target)
    package = f'{number:03}-{slug}'
    branch = f'feat/{package}'
    base = commit(repo, f'refs/heads/{target}')
    if commit(repo, f'refs/heads/{branch}'):
        raise ValueError(f'Package branch already exists: {branch}')
    spec = _render(_template(repo, target, 'spec-template.md', required=True),
                   short_name.strip(), branch, number)
    # Vendor defaults lack workflow metadata. Retain their content while adding
    # the kit's owning header; project overrides already supply it themselves.
    if not re.search(r'^\*\*Lifecycle\*\*:', spec, re.MULTILINE):
        spec = _render((_TEMPLATES / 'spec-template.md').read_text(encoding='utf-8'),
                       short_name.strip(), branch, number) + '\n' + spec
    # A copied template is never evidence of owner authorization for a new scope.
    spec = re.sub(r'^\*\*Lifecycle\*\*:[^\n]*', '**Lifecycle**: draft', spec, flags=re.MULTILINE)
    checkpoints = []

    def pending_checkpoint(match):
        identity, gate = match.groups()
        checkpoints.append(identity)
        return f'| {identity} | {gate.strip()} | [request](reviews/{identity}-request.md) | pending |'

    spec = re.sub(r'^\|\s*(CP[0-9]+)\s*\|([^|]+)\|[^\n]*\|\s*$',
                  pending_checkpoint, spec, flags=re.MULTILINE)
    catalog = _read_revision(repo, target, 'docs/specs.md')
    if catalog is None:
        raise ValueError('Missing docs/specs.md on target; commit wfk init adoption first.')
    catalog = _register(catalog, number, package, branch, short_name.strip())
    owners = {f'specs/{package}/spec.md': spec}
    for name in ('plan', 'tasks'):
        owners[f'specs/{package}/{name}.md'] = _render(
            (_TEMPLATES / f'{name}-template.md').read_text(encoding='utf-8'),
            short_name.strip(), branch, number)
    for identity in checkpoints:
        owners[f'specs/{package}/reviews/{identity}-request.md'] = (
            f'# {identity} review request\n\nReview [the draft](../spec.md) for '
            'owner acceptance before work requiring this checkpoint.\n')
    result = {'items': [{'path': name, 'status': 'planned'} for name in owners],
              'warnings': load(repo)['warnings'], 'checklist': [], 'dry_run': not apply,
              'branch': branch, 'package': f'specs/{package}', 'target': target,
              'commits': []}
    result['items'].append({'path': 'docs/specs.md', 'status': 'planned'})
    if not apply:
        return result

    temporary_parent = None
    if checkout is None:
        temporary_parent = Path(tempfile.mkdtemp(prefix='wfk-new-'))
        checkout = temporary_parent / 'target'
        try:
            git(repo, 'worktree', 'add', str(checkout), target)
        except ValueError:
            temporary_parent.rmdir()
            raise
    provisional = None
    try:
        # Verify target records before changing files or creating the new ref.
        _validate(checkout)
        for name in owners:
            destination = _safe_destination(checkout, name)
            if os.path.lexists(destination):
                raise ValueError(f'Package file already exists: {name}')
        _safe_destination(checkout, 'docs/specs.md')
        if commit(repo, f'refs/heads/{target}') != base:
            raise ValueError('Target moved during package planning; preview again.')
        if git(checkout, 'status', '--porcelain', '--untracked-files=all').stdout:
            raise ValueError('Target became dirty during package planning; preserve the checkout.')
        for name, content in owners.items():
            path = checkout / name
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open('x', encoding='utf-8', newline='\n') as stream:
                stream.write(content)
        git(checkout, 'add', '--', *owners)
        _check_index(checkout, owners)
        tree = git(checkout, 'write-tree').stdout.strip()
        # A provisional local draft ref makes branch-aware lint resolvable before
        # the catalog registration commit. The draft tree retains the OLD catalog,
        # so it does not introduce a commit with a dangling catalog row.
        provisional = git(checkout, 'commit-tree', tree, '-p', base, '-m',
                          f'specs: prepare draft package {number:03}').stdout.strip()
        git(repo, 'update-ref', f'refs/heads/{branch}', provisional, '0' * len(base))
        (checkout / 'docs/specs.md').write_text(catalog, encoding='utf-8', newline='\n')
        git(checkout, 'add', '--', 'docs/specs.md')
        _validate(checkout)
        _check_index(checkout, [*owners, 'docs/specs.md'])
        git(checkout, 'commit', '-m', f'specs: register draft package {number:03}')
        registered = commit(checkout, 'HEAD')
        result['commits'].append(registered)
        git(repo, 'update-ref', f'refs/heads/{branch}', registered, provisional)
        _validate(checkout)
        for item in result['items']:
            item['status'] = 'created' if item['path'] in owners else 'registered'
        result['checklist'].append(
            f'Review {result["package"]}/spec.md on {branch}; CP1 remains pending.')
    except (OSError, ValueError) as exc:
        raise ValueError(
            f'Package creation incomplete: {exc}. Recovery checkout: {checkout}; '
            f'target: {target}; draft branch: {branch}. Partial files, index and '
            'local commits are preserved; inspect them before retrying.') from exc
    if temporary_parent is not None:
        try:
            git(repo, 'worktree', 'remove', str(checkout))
            temporary_parent.rmdir()
        except (OSError, ValueError) as exc:
            result['warnings'].append(f'Package created; temporary checkout retained at {checkout}: {exc}')
    return result
