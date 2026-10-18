"""Offline catalog, package and gate owners; no vendor-content inspection."""

import re
from pathlib import Path, PurePosixPath
from urllib.parse import unquote

from . import config
from .git import commit, git, repo_root

LINK = re.compile(r'\[[^\]]*\]\(([^)]+)\)')
LIFECYCLES = {'draft', 'review', 'ready', 'active', 'parked', 'delivered', 'closed', 'superseded'}
STATES = {'pending', 'findings-received', 'owner-cleared', 'superseded'}


def _relative(base, name):
    name = unquote(name.split('#', 1)[0])
    if not name or '\\' in name or ':' in name or name.startswith('/'):
        raise ValueError(f'Invalid relative owner path: {name}')
    parts = list(PurePosixPath(base).parts)
    for part in PurePosixPath(name).parts:
        if part == '..':
            if not parts:
                raise ValueError(f'Owner path escape: {name}')
            parts.pop()
        elif part != '.':
            parts.append(part)
    return '/'.join(parts)


def catalog(repo, text=None):
    """Current and archived catalog rows; candidate tables are not work."""
    path = Path(repo) / 'docs/specs.md'
    if text is None:
        text = path.read_text(encoding='utf-8-sig')
    rows, section, seen = [], '', set()
    header, separator, current_seen = False, False, False
    def finish():
        if ((section == 'current packages' or header) and
                section in ('current packages', 'archive') and not separator):
            raise ValueError(f'Catalog {section} needs its header and separator')
    for line in text.splitlines():
        if line.startswith('## '):
            finish()
            section = line[3:].strip().lower()
            header, separator = False, False
            current_seen = current_seen or section == 'current packages'
        if section not in ('current packages', 'archive') or not line.startswith('|'):
            continue
        cells = [s.strip() for s in line.strip('|').split('|')]
        if cells == ['Spec', 'Package', 'Branch']:
            if header:
                raise ValueError('Duplicate catalog table header')
            header = True
            continue
        if len(cells) == 3 and all(re.fullmatch(r':?-+:?', cell) for cell in cells):
            if not header or separator:
                raise ValueError('Catalog separator needs exactly one preceding header')
            separator = True
            continue
        if not separator:
            raise ValueError('Catalog data needs its section header and separator')
        links = LINK.findall(line)
        if len(cells) != 3 or len(links) != 1:
            raise ValueError(f'Invalid catalog row: {line}')
        path = _relative('docs', links[0])
        if not path.startswith('specs/') or not path.endswith('/spec.md'):
            raise ValueError(f'Catalog must link a package spec: {path}')
        package = path.removesuffix('/spec.md')
        branch = cells[2].strip('`')
        if package in seen or not branch:
            raise ValueError(f'Duplicate package or missing branch: {package}')
        seen.add(package)
        rows.append(dict(package=package, branch=branch, archive=section == 'archive'))
    finish()
    if not current_seen:
        raise ValueError('Catalog lacks Current packages section')
    return rows


def _source(repo, row):
    if row['archive']:
        return Path(repo), None
    from .worktrees import records
    for entry in records(repo):
        if entry.get('branch') == 'refs/heads/' + row['branch']:
            path = Path(entry['worktree'])
            if not path.is_dir():
                raise ValueError(f"Declared branch checkout unavailable: {row['branch']} ({path})")
            return path, None
    ref = 'refs/heads/' + row['branch']
    if commit(repo, ref):
        return None, ref
    remote = git(repo, 'for-each-ref', '--format=%(refname)', 'refs/remotes').stdout.splitlines()
    hint = ('fetch the declared branch' if any(r.endswith('/' + row['branch']) for r in remote)
            else 'create or fetch the declared branch; offline inventory has no local ref')
    raise ValueError(f"Missing declared branch {row['branch']}: {hint}")


def read(package, name):
    relative = _relative(package['package'], name)
    if not relative.startswith(package['package'] + '/'):
        raise ValueError(f'Package owner path escape: {name}')
    if package['source'] is not None:
        root = Path(package['source']).resolve()
        path = root / relative
        if not path.resolve().is_relative_to(root / package['package']):
            raise ValueError(f'Package owner symlink escape: {name}')
        return path.read_text(encoding='utf-8-sig') if path.is_file() else None
    result = git(package['repo'], 'show', f"{package['ref']}:{relative}", check=False)
    return result.stdout.lstrip('\ufeff') if result.returncode == 0 else None


def labels(text):
    result = {}
    for match in re.finditer(r'(?im)^[ \t]*(?:[-*][ \t]+)?\*{0,2}'
            r'(Reviewer|Reviewed revision|Verdict|Scope|Accepted scope|Checkpoint)\*{0,2}:'
            r'[ \t]*([^\r\n]+)', text):
        key, value = match.groups()
        key = key.lower()
        if key in result:
            raise ValueError(f'Duplicate review header: {key}')
        result[key] = value.strip().strip('*` ')
    return result


def _field(text, name):
    matches = re.findall(r'(?m)^\*\*' + re.escape(name) + r'\*\*:[ \t]*([^\r\n]+)', text)
    if len(matches) != 1:
        raise ValueError(f'Missing or duplicate {name}')
    return matches[0].strip().strip('`')


def _parse(package):
    text = read(package, 'spec.md')
    if text is None:
        raise ValueError('Missing spec.md')
    package['lifecycle'] = _field(text, 'Lifecycle')
    if package['lifecycle'] not in LIFECYCLES:
        raise ValueError(f"Invalid lifecycle: {package['lifecycle']}")
    if _field(text, 'Feature branch') != package['branch']:
        raise ValueError('Feature branch differs from catalog')
    package['scope'] = _field(text, 'Scope').split('`', 1)[0]
    checkpoints = {}
    header = re.split(r'(?m)^## ', text, maxsplit=1)[0]
    for line in header.splitlines():
        if not re.match(r'^\|\s*CP\d+\s*\|', line):
            continue
        cells = [s.strip() for s in line.strip('|').split('|')]
        if len(cells) != 4 or cells[3] not in STATES or cells[0] in checkpoints:
            raise ValueError(f'Invalid/duplicate checkpoint: {line}')
        checkpoints[cells[0]] = dict(state=cells[3], links=LINK.findall(cells[2]))
    if not checkpoints:
        raise ValueError('Missing checkpoint table')
    package['checkpoints'] = checkpoints
    tasks = read(package, 'tasks.md')
    if tasks is None or read(package, 'plan.md') is None:
        raise ValueError('Missing package owner: plan.md or tasks.md')
    entry = _field(tasks, 'Entry checkpoint')
    if entry not in checkpoints:
        raise ValueError(f'Unknown entry checkpoint: {entry}')
    package['entry'] = entry
    package['tasks'] = []
    seen = set()
    for index, line in enumerate(tasks.splitlines()):
        if not re.match(r'^\s*- \[[ xX]\]', line):
            continue
        match = re.match(r'^\s*- \[([ xX])\] (T\d{3,})\s+(.+)$', line)
        if not match:
            raise ValueError(f'Task needs stable identity: {line}')
        done, identity, description = match.groups()
        if identity in seen:
            raise ValueError(f'duplicate task: {identity}')
        seen.add(identity)
        gates = re.findall(r'\(gate:\s*(CP\d+)\)', description, re.I)
        annotations = re.findall(r'\(\s*gate\b', description, re.I)
        if len(gates) > 1 or len(annotations) != len(gates):
            raise ValueError(f'Invalid task gate: {identity}')
        gate = gates[0].upper() if gates else entry
        if gate not in checkpoints:
            raise ValueError(f'Unknown task gate {gate}: {identity}')
        package['tasks'].append(dict(id=identity, complete=done != ' ', gate=gate,
            description=description, line=index, manual='(manual)' in description.lower()))
    return package


def _settings(repo):
    settings = config._read(Path(repo) / '.workflow-kit.json')
    if 'workflowModelVersion' not in settings:
        raise ValueError('Legacy/unadopted repository: workflow commands require workflowModelVersion '
                         '1 or 2; preview wfk init and manually merge existing config')
    return settings


def packages(repo):
    repo = repo_root(repo)
    version = _settings(repo)['workflowModelVersion']
    result = []
    for row in catalog(repo):
        source, ref = _source(repo, row)
        result.append(_parse(dict(row, repo=repo, source=source, ref=ref, version=version)))
    return result


def _identity(value):
    return value.strip('`').split('`', 1)[0].split()[0] if value else ''


def _linked_review(package, link):
    name, _, anchor = link.partition('#')
    text = read(package, name)
    if text is None:
        raise ValueError(f'Missing checkpoint link: {link}')
    if anchor:
        anchors = set(re.findall(r'<a\s+(?:id|name)=["\']([^"\']+)["\']', text, re.I))
        counts = {}
        for heading in re.findall(r'(?m)^#{1,6}\s+(.+?)\s*#*$', text):
            slug = re.sub(r'[^\w\- ]', '', heading.lower()).replace(' ', '-')
            suffix = counts.get(slug, 0)
            counts[slug] = suffix + 1
            anchors.add(slug + (f'-{suffix}' if suffix else ''))
        if unquote(anchor) not in anchors:
            raise ValueError(f'Missing checkpoint anchor: {link}')
    return text


def gate_problem(package, gate):
    checkpoint = package['checkpoints'].get(gate)
    if not checkpoint or checkpoint['state'] != 'owner-cleared':
        return f'{gate} is not owner-cleared; stop for owner acceptance'
    if package.get('version', 2) == 2:
        problem = _latest_findings_problem(package, gate, checkpoint)
        if problem:
            return problem
    accepted, accepted_scope, owner_decision = False, False, False
    for link in checkpoint['links']:
        path = link.split('#', 1)[0]
        if not path.startswith('reviews/') or '..' in PurePosixPath(path).parts:
            return f'{gate} decision must stay in package reviews/'
        text = _linked_review(package, link)
        if not text:
            return f'{gate} saved decision missing: {path}'
        fields = labels(text)
        if 'checkpoint' in fields and _identity(fields['checkpoint']) != gate:
            return f'{gate} decision names a different checkpoint'
        verdict = fields.get('verdict', '')
        if ('accepted scope' in fields and
                re.match(r'^(?:blocker|blocking|reject|superseded|changes)\b', verdict)):
            return f'{gate} saved verdict is blocking or superseded'
        if re.match(r'^accept\b', verdict):
            if not fields.get('reviewer') or not fields.get('reviewed revision'):
                return f'{gate} accept verdict lacks Reviewer or Reviewed revision'
            accepted = True
        if 'accepted scope' in fields:
            if _identity(fields['accepted scope']) == package['scope']:
                accepted_scope = True
                owner_decision = owner_decision or (verdict == 'accept' and
                    bool(fields.get('reviewer')) and bool(fields.get('reviewed revision')))
    valid = owner_decision if package.get('version', 2) == 2 else accepted and accepted_scope
    return None if valid else f'{gate} lacks an accept verdict with matching Accepted scope in a complete owner decision'


def next_task(package):
    if package['lifecycle'] != 'active':
        raise ValueError(f"Package lifecycle is {package['lifecycle']}; no executable task")
    problem = gate_problem(package, package['entry'])
    if problem:
        raise ValueError(problem)
    for task in package['tasks']:
        if task['complete']:
            continue
        problem = gate_problem(package, task['gate'])
        if problem or task['manual']:
            raise ValueError(problem or f"{task['id']} is manual; stop for owner action")
        return task
    return None


def _review_files(package):
    if package['source'] is not None:
        root = Path(package['source']) / package['package'] / 'reviews'
        return [p.relative_to(root).as_posix() for p in root.rglob('*.md')]
    prefix = package['package'] + '/reviews/'
    names = git(package['repo'], 'ls-tree', '-r', '--name-only', package['ref'], '--', prefix).stdout
    return [name.removeprefix(prefix) for name in names.splitlines() if name.endswith('.md')]


def _latest_findings_problem(package, gate, checkpoint):
    pattern = re.compile(r'^(\d{4}-\d{2}-\d{2})-' + re.escape(gate) + r'-.+-findings\.md$', re.I)
    findings = {name: pattern.match(name).group(1) for name in _review_files(package)
                if pattern.match(name)}
    if not findings:
        return None
    linked = [link.split('#', 1)[0].removeprefix('reviews/') for link in checkpoint['links']]
    dates = [findings[name] for name in linked if name in findings]
    if not dates or max(dates) < max(findings.values()):
        return f'{gate} must link its latest findings before owner clearance'
    return None


def _budgets(repo, settings, errors):
    totals, seen = {}, set()
    files = settings.get('autoLoadedFiles', [])
    hosts = settings.get('hostBudgets', [])
    if not isinstance(files, list) or not isinstance(hosts, list):
        raise ValueError('autoLoadedFiles and hostBudgets must be lists')
    for entry in files:
        if not isinstance(entry, dict) or entry.get('loading') not in ('full', 'on-demand', 'unknown'):
            raise ValueError('Invalid autoLoadedFiles declaration')
        if entry['loading'] != 'full':
            continue
        if not isinstance(entry.get('path'), str):
            raise ValueError('Auto-loaded file path must be a string')
        loaded_hosts = entry.get('hosts')
        if (not isinstance(loaded_hosts, list) or not loaded_hosts or
                any(not isinstance(host, str) or not host for host in loaded_hosts) or
                len(set(loaded_hosts)) != len(loaded_hosts)):
            raise ValueError('Auto-loaded hosts must be a nonempty list of unique host names')
        name = _relative('', entry.get('path', ''))
        if name in seen:
            raise ValueError(f'Duplicate auto-loaded file: {name}')
        seen.add(name)
        path = Path(repo) / name
        if not path.resolve().is_relative_to(Path(repo).resolve()):
            raise ValueError(f'Auto-loaded path escape: {name}')
        if not path.is_file():
            errors.append(f'Missing auto-loaded file: {name}')
            continue
        raw = path.read_bytes()
        count = (len(raw.decode('utf-8-sig').splitlines()), len(raw))
        for i, key in enumerate(('lines', 'bytes')):
            limit = entry.get(key)
            if type(limit) is not int or limit <= 0:
                raise ValueError(f'Invalid {key} budget: {name}')
            if count[i] > limit:
                errors.append(f'{name}: {key} budget exceeded ({count[i]} > {limit})')
        for host in loaded_hosts:
            total = totals.setdefault(host, [0, 0])
            for i in range(2):
                total[i] += count[i]
    declared = set()
    for entry in hosts:
        if (not isinstance(entry, dict) or not isinstance(entry.get('host'), str)
                or not entry['host'] or entry['host'] in declared):
            raise ValueError('Invalid/duplicate host budget')
        host = entry['host']
        declared.add(host)
        for i, key in enumerate(('lines', 'bytes')):
            limit = entry.get(key)
            if type(limit) is not int or limit <= 0:
                raise ValueError(f'Invalid host budget: {host}')
            if totals.get(host, [0, 0])[i] > limit:
                errors.append(f'Host {host}: {key} budget exceeded')
    for host in totals.keys() - declared:
        errors.append(f'Missing budget for host: {host}')


def lint(repo):
    repo = repo_root(repo)
    errors, warnings, items = [], [], []
    # Lint consumes the shared inventory/budgets in either config generation;
    # worktree commands still name fields whose v1 semantics they do not use.
    settings = _settings(repo)
    if settings.get('workflowModelVersion') == 1:
        ignored = sorted(set(settings) - {'workflowModelVersion', 'targetBranch',
                                         'autoLoadedFiles', 'hostBudgets'})
        if ignored:
            warnings.append('lint: ignored v1 fields: ' + ', '.join(ignored))
    _budgets(repo, settings, errors)
    for name in ('AGENTS.md', 'CLAUDE.md'):
        path = repo / name
        if not path.is_file():
            continue
        text = path.read_text(encoding='utf-8-sig')
        if re.search(r'MANUAL ADDITIONS (?:START|END)|AUTO-GENERATED|'
                     r'BEGIN[^\n]*(?:SPEC.?KIT|FEATURE)|END[^\n]*SPEC.?KIT|'
                     r'^\*\*(?:Next tasks|Blockers|Lifecycle|Entry checkpoint)\*\*:', text,
                     re.I | re.M):
            errors.append(f'{name}: feature state or vendor marker in auto-loaded instructions')
    for row in catalog(repo):
        try:
            source, ref = _source(repo, row)
            package = _parse(dict(row, repo=repo, source=source, ref=ref,
                                  version=settings.get('workflowModelVersion', 2)))
            for gate, checkpoint in package['checkpoints'].items():
                latest_problem = _latest_findings_problem(package, gate, checkpoint)
                if latest_problem:
                    target = warnings if settings.get('workflowModelVersion') == 1 else errors
                    target.append(f"{row['package']}: {latest_problem}")
                dated_findings = [name[:10] for name in _review_files(package)
                    if re.match(r'^\d{4}-\d{2}-\d{2}-' + re.escape(gate) +
                                r'-.+-findings\.md$', name, re.I)]
                if dated_findings and dated_findings.count(max(dated_findings)) > 1:
                    warnings.append(f"{row['package']} {gate}: same-date findings order is ambiguous; "
                                    'owner must select the latest record explicitly')
                if len(checkpoint['links']) > 2:
                    target = warnings if settings.get('workflowModelVersion') == 1 else errors
                    target.append(f"{row['package']} {gate}: checkpoint has more than latest two links")
                for link in checkpoint['links']:
                    _linked_review(package, link)
                if checkpoint['state'] == 'owner-cleared':
                    problem = gate_problem(package, gate)
                    if problem:
                        errors.append(f"{row['package']}: {problem}")
            for name in _review_files(package):
                text = read(package, 'reviews/' + name)
                fields = labels(text)
                is_findings = name.endswith('-findings.md')
                if is_findings or 'reviewer' in fields or 'verdict' in fields:
                    problems = []
                    for key in ('reviewer', 'reviewed revision', 'verdict'):
                        if not fields.get(key):
                            problems.append('Missing ' + key.capitalize())
                    if 'verdict' in fields and fields['verdict'] not in ('accept', 'changes', 'blocker'):
                        problems.append('Invalid Verdict')
                    if is_findings:
                        for finding in re.findall(r'(?m)^\d+\.\s+(.+)$', text):
                            if not re.match(r'\W*(blocker|major|minor)\b', finding, re.I):
                                problems.append('Finding missing blocker/major/minor severity')
                    for problem in problems:
                        target = errors if is_findings or settings.get('workflowModelVersion') != 1 else warnings
                        target.append(f"{row['package']}/reviews/{name}: {problem}")
            items.append(dict(package=row['package'], branch=row['branch'],
                              lifecycle=package['lifecycle'], action='checked'))
        except (ValueError, OSError) as exc:
            errors.append(f"{row['package']}: {exc}")
    return dict(items=items, errors=errors, warnings=warnings)
