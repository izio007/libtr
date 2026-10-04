"""Fail-closed release gate; evidence is bound to one immutable candidate."""
import hashlib
import json
from pathlib import Path

REQUIRED = ('fresh_process', 'readability', 'html_visual', 'pdf_visual',
            'mlx_visual', 'png_visual')


def fingerprint(package):
    """Bind reviews to code, configurations, documents and execution results.

    Sealing metadata is excluded because finalization itself rewrites it.
    """
    excluded = {'manifest.json', 'README.md', 'results/acceptance.json',
                'results/release_review.json'}
    entries = []
    for path in sorted(Path(package).rglob('*')):
        relative = path.relative_to(package).as_posix()
        if path.is_file() and relative not in excluded:
            entries.append([relative, hashlib.sha256(path.read_bytes()).hexdigest()])
    return hashlib.sha256(json.dumps(entries, ensure_ascii=True).encode()).hexdigest()


def evaluate(package, report):
    """Missing reviews remain NOT_RUN; malformed/stale evidence is rejected."""
    identity = fingerprint(package)
    checks = {name: 'NOT_RUN' for name in REQUIRED}
    review_file = Path(package) / 'results/release_review.json'
    if review_file.is_file():
        review = json.loads(review_file.read_text(encoding='utf-8'))
        if (review.get('schema_version') != 1 or
                review.get('candidate_sha256') != identity or
                review.get('package_version') != report['package_version']):
            raise ValueError('Stale or incompatible release review')
        if set(review.get('checks', {})) != set(REQUIRED):
            raise ValueError('Incomplete review contract')
        for name, item in review['checks'].items():
            status = item.get('status')
            if status not in ('NOT_RUN', 'PASS', 'FAILED'):
                raise ValueError('Invalid review status: ' + name)
            if status != 'NOT_RUN' and not all(
                    isinstance(item.get(key), str) and item[key].strip()
                    for key in ('reviewer', 'evidence', 'criterion')):
                raise ValueError('Review lacks attribution or evidence: ' + name)
            checks[name] = status
    if checks['fresh_process'] == 'PASS' and report.get('new_server') is not True:
        raise ValueError('Fresh-process review contradicts execution report')
    checks['matlab_execution'] = report['status']
    status = ('FAILED' if 'FAILED' in checks.values() else
              'PASS' if all(value == 'PASS' for value in checks.values()) else 'NOT_RUN')
    return dict(status=status, release_accepted=status == 'PASS', checks=checks,
                candidate_sha256=identity,
                remaining=[name for name, value in checks.items() if value != 'PASS'])