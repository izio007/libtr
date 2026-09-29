"""Idempotent source markup normalization; no mathematical model changes."""
import re
from pathlib import Path

DOCS = Path(__file__).resolve().parents[2] / 'docs'
TOKEN = re.compile(r'`[^`\n]+`|\$\$.*?\$\$|\$[^$\n]+\$')


def normalize(text):
    lines = []
    code = False
    for line in text.splitlines():
        if line.startswith('```'):
            code = not code
        if code or line.startswith('```'):
            lines.append(line)
            continue
        line = line.rstrip()
        # Display math is a standalone block, not a Markdown bullet.
        line = re.sub(r'^\s*(?:\*\s+)?(\$\$.*\$\$)$', r'\1', line)

        def formula(match):
            token = match.group()
            if token.startswith('`'):
                return token
            n = 2 if token.startswith('$$') else 1
            tex = token[n:-n]
            if r'\frac' in tex and r'\sum' in tex and r'\displaystyle' not in tex:
                tex = r'\displaystyle ' + tex
            return '$' * n + tex + '$' * n

        lines.append(TOKEN.sub(formula, line))
    if code:
        raise ValueError('Unclosed code fence')
    return '\n'.join(lines).rstrip() + '\n'


if __name__ == '__main__':
    for path in sorted(DOCS.glob('*_theory.md')):
        original = path.read_text(encoding='utf-8-sig')
        updated = normalize(original)
        assert normalize(updated) == updated
        if updated != original:
            path.write_text(updated, encoding='utf-8')
            print(path.name)