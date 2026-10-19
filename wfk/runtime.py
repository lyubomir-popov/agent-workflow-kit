"""Frozen declarative worker profiles; no discovery invokes a live CLI."""
import copy
import json
import math
import os
from pathlib import Path
import re
import shutil
import string

from . import config

DEFAULTS = Path(__file__).resolve().parent.parent / 'templates/scheduler-defaults.json'


def positive(value, name, zero=False):
    if (type(value) not in (int, float) or not math.isfinite(value)
            or (value < 0 if zero else value <= 0)):
        raise ValueError(f'{name} must be finite and {"nonnegative" if zero else "positive"}')
    return value


def load(repo):
    result = json.loads(DEFAULTS.read_text(encoding='utf-8'))
    result['warnings'] = []
    user = Path(os.environ.get('WFK_CONFIG', '~/.config/wfk/config.json')).expanduser()
    for path in (user, Path(repo) / '.workflow-kit.json'):
        data = config._read(path)
        keys = {'workers', 'tierModels', 'scheduler', 'reviewer'} & data.keys()
        if data.get('workflowModelVersion', 2) == 1:
            if keys:
                result['warnings'].append(f'{path}: ignored v1 scheduler fields: ' + ', '.join(sorted(keys)))
            continue
        for key in keys:
            if key == 'reviewer':
                result[key] = data[key]
                continue
            if not isinstance(data[key], dict):
                raise ValueError(f'{key} must be an object')
            for name, value in data[key].items():
                if key in ('workers', 'tierModels'):
                    if not isinstance(value, dict):
                        raise ValueError(f'{key}.{name} must be an object')
                    result[key].setdefault(name, {}).update(copy.deepcopy(value))
                else:
                    result[key][name] = copy.deepcopy(value)
    positive(result['scheduler']['authTimeout'], 'authTimeout')
    positive(result['scheduler']['grace'], 'grace', zero=True)
    return result


def profile(settings, name):
    if not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', name):
        raise ValueError('Invalid worker profile name')
    if name not in settings['workers']:
        raise ValueError(f'Unknown worker profile: {name}')
    value = dict(settings['workers'][name])
    value.setdefault('input', 'stdin')
    if value['input'] not in ('stdin', 'argv'):
        raise ValueError(f'{name}: input must be stdin or argv')
    for key in ('command', 'authCommand', 'modelArgs'):
        argv = value.get(key)
        if argv is None and key != 'command':
            continue
        if not isinstance(argv, list) or not argv or any(not isinstance(a, str) or '\0' in a for a in argv):
            raise ValueError(f'{name}: {key} must be a nonempty argument array')
        for argument in argv:
            try:
                fields = [field for _, field, fmt, conversion in string.Formatter().parse(argument)
                          if field is not None]
            except ValueError as exc:
                raise ValueError(f'{name}: malformed {key} template') from exc
            if any(field not in ('prompt', 'repo', 'package', 'task', 'model', 'review') for field in fields):
                raise ValueError(f'{name}: unknown {key} placeholder')
            if key == 'authCommand' and fields:
                raise ValueError(f'{name}: authCommand must be a fixed cheap noninteractive probe')
    for key in ('quotaExitCodes', 'authExitCodes'):
        codes = value.get(key, [])
        if not isinstance(codes, list) or any(type(c) is not int or c == 0 for c in codes):
            raise ValueError(f'{name}: {key} must contain nonzero integer exit codes')
    for key in ('quotaPatterns', 'authPatterns'):
        patterns = value.get(key, [])
        if not isinstance(patterns, list) or any(not isinstance(s, str) or not s for s in patterns):
            raise ValueError(f'{name}: {key} must contain nonempty literal strings')
    return value


def executable(argv):
    if not shutil.which(argv[0]):
        raise ValueError(f'Worker executable unavailable: {argv[0]}')


def argv(settings, name, profile_value, context, auth=False):
    if auth:
        arguments = profile_value.get('authCommand')
        if not arguments:
            raise ValueError(f'{name}: configure a verified cheap noninteractive authCommand; '
                             'default authentication is unverified and dispatch is disabled')
        return list(arguments)
    model = settings['tierModels'].get(name, {}).get(context['tier'])
    if model is not None and (not isinstance(model, str) or not model):
        raise ValueError(f'{name}: tier model must be a nonempty string or null')
    values = dict(context, model=model or '')
    try:
        arguments = [a.format_map(values) for a in profile_value['command']]
        if model:
            model_args = profile_value.get('modelArgs')
            if not model_args:
                raise ValueError(f'{name}: configure modelArgs when selecting a tier model')
            arguments.extend(a.format_map(values) for a in model_args)
    except (KeyError, ValueError) as exc:
        raise ValueError(f'{name}: invalid worker arguments: {exc}') from exc
    return arguments


def failure(profile_value, result):
    if result['timed_out']:
        return 'timeout'
    if result['interrupted']:
        return 'interrupted'
    code = result['returncode']
    # Exit codes are authoritative. Literal patterns are checked only on failure,
    # so a successful worker quoting an error in its report is not misclassified.
    if code in profile_value.get('authExitCodes', []):
        return 'auth'
    if code in profile_value.get('quotaExitCodes', []):
        return 'quota'
    if code:
        patterns = {'auth': profile_value.get('authPatterns', []),
                    'quota': profile_value.get('quotaPatterns', [])}
        overlap = max((len(s) for needles in patterns.values() for s in needles), default=1) - 1
        tail = ''
        with Path(result['log']).open(encoding='utf-8', errors='replace') as stream:
            while True:
                chunk = stream.read(65536)
                if not chunk:
                    break
                content = (tail + chunk).casefold()
                for kind, needles in patterns.items():
                    if any(needle.casefold() in content for needle in needles):
                        return kind
                tail = (tail + chunk)[-overlap:] if overlap else ''
        return 'error'
    return None
