"""Exact JSON result identity and declarative expectations; no numerical policy."""
import hashlib
import json
import math


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'),
                      ensure_ascii=False, allow_nan=False).encode('utf-8')


def validate(expectations):
    if not isinstance(expectations, dict):
        raise ValueError('expectations must map stage names to rules')
    for stage, rules in expectations.items():
        if not isinstance(stage, str) or not isinstance(rules, list):
            raise ValueError('Invalid expectation stage')
        for rule in rules:
            if not isinstance(rule, dict):
                raise ValueError('Invalid expectation rule')
            kind = rule.get('kind')
            fields = {'path', 'kind', 'value'} if kind == 'equal' else {'path', 'kind', 'min', 'max'}
            if kind not in ('equal', 'range', 'delta') or set(rule) != fields:
                raise ValueError('Invalid expectation fields')
            if not isinstance(rule['path'], list) or any(
                    type(k) not in (str, int) or (type(k) is int and k < 0) for k in rule['path']):
                raise ValueError('Invalid metric path')
            if kind != 'equal':
                if not all(numeric(rule[k]) for k in ('min', 'max')) or rule['min'] > rule['max']:
                    raise ValueError('Invalid expectation bounds')
            encoded(rule)


def numeric(value):
    return type(value) in (int, float) and math.isfinite(value)


def at(value, path):
    for key in path:
        value = value[key]
    return value


def assess(value, previous, rules):
    checks = []
    for rule in rules:
        actual = None
        try:
            actual = at(value, rule['path'])
            if rule['kind'] == 'equal':
                passed = encoded(actual) == encoded(rule['value'])
            else:
                if not numeric(actual):
                    raise ValueError('Expected finite numeric metric')
                if rule['kind'] == 'delta':
                    old = at(previous, rule['path'])
                    if not numeric(old):
                        raise ValueError('Expected finite previous metric')
                    actual -= old
                passed = rule['min'] <= actual <= rule['max']
            reason = '' if passed else 'Expectation violated'
        except (KeyError, IndexError, TypeError, ValueError) as error:
            passed, reason = False, str(error)
        checks.append(dict(expected=rule, actual=actual,
                           status='PASS' if passed else 'FAILED', reason=reason))
    return dict(status=('FAILED' if any(c['status'] == 'FAILED' for c in checks)
                        else 'PASS' if checks else 'NOT_RUN'), checks=checks)


def store(root, suite, stage, value, rules, write_json):
    data = encoded(value)
    digest = hashlib.sha256(data).hexdigest()
    folder = root / 'runtime/pipeline_results'
    target = folder / (digest + '.json')
    key = hashlib.sha256(encoded([suite, stage])).hexdigest()
    latest = folder / 'latest' / (key + '.json')
    prior = json.loads(latest.read_text(encoding='utf-8')) if latest.exists() else None
    previous = json.loads((folder / (prior['sha256'] + '.json')).read_text(encoding='utf-8')) if prior else None
    if not target.exists():
        write_json(target, value)
    assessment = assess(value, previous, rules)
    result = dict(sha256=digest, path=str(target), previous_sha256=prior['sha256'] if prior else None,
                  change='FIRST' if prior is None else 'UNCHANGED' if prior['sha256'] == digest else 'CHANGED',
                  assessment=assessment)
    if assessment['status'] != 'FAILED':
        write_json(latest, dict(sha256=digest))
    return result