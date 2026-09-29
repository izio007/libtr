"""Translate all *_theory.md sources without editing mathematical content.

Run with Python 3. Standard library only. PNGs must be generated beforehand.
"""
from pathlib import Path
import html
import re
import hashlib

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / 'docs'
TOKEN = re.compile(r'(`[^`\n]+`|\$\$.*?\$\$|\$[^$\n]+\$)')
IMAGE = re.compile(r'^\[image: ([A-Za-z0-9_-]+\.png)\]$')


def validate_prose(line, location='text'):
    plain = TOKEN.sub('', line)
    if '$' in plain:
        raise ValueError(f'Unbalanced formula: {location}: {line}')
    if re.search(r'\\[A-Za-z]+|\bif\s+rcond\s*\(', plain):
        raise ValueError(f'Unmarked mathematics: {location}: {line}')


def inline(text):
    parts = []
    for part in TOKEN.split(text):
        if part.startswith('`'):
            parts.append('<code>' + html.escape(part[1:-1]) + '</code>')
        elif part.startswith('$'):
            display = part.startswith('$$')
            n = 2 if display else 1
            tex = part[n:-n]
            # HTML text encoding, never Live Editor backslash doubling.
            tag = 'div' if display else 'span'
            delim = ('\\[', '\\]') if display else ('\\(', '\\)')
            parts.append(f'<{tag} class="math">{delim[0]}{html.escape(tex)}{delim[1]}</{tag}>')
        else:
            parts.append(html.escape(part))
    return ''.join(parts)


def clean_output(text):
    """Normalize generated line endings and remove trailing whitespace."""
    return '\n'.join(line.rstrip() for line in text.splitlines()) + '\n'


def live_math(match):
    token = match.group()
    if token.startswith('`'):
        return token
    n = 2 if token.startswith('$$') else 1
    tex = token[n:-n]
    # Live Editor's equation renderer does not implement operatorname.
    tex = tex.replace(r'\operatorname{rcond}', r'\mathrm{rcond}')
    # MATLAB text format: display formulas use one dollar pair.
    # Preserve matrix rows and columns; transport escaping happens below.
    if r'\frac' in tex and r'\sum' in tex and r'\displaystyle' not in tex:
        tex = r'\displaystyle ' + tex
    tex = tex.replace('\\', '\\\\')
    tex = re.sub(r'(?<!\\)_', r'\\_', tex)
    tex = tex.replace('[', r'\[').replace(']', r'\]')
    tex = tex.replace('<', r'\<').replace('>', r'\>')
    # Fail at generation, not in a later MATLAB gate, if a matrix is flattened.
    original = token[n:-n]
    for environment in ('bmatrix', 'cases'):
        if '\\begin{' + environment + '}' in original:
            if ('\\\\begin{' + environment + '}' not in tex or
                    '\\\\end{' + environment + '}' not in tex or
                    tex.count('&') != original.count('&') or
                    tex.count('\\\\\\\\') != original.count('\\\\')):
                raise ValueError('Matrix structure lost during Live Editor serialization')
    return '$' + tex + '$'


def build(source):
    text = source.read_text(encoding='utf-8-sig')
    if re.search(r'[┌┐└┘│─]|[•_x]{5,}', text):
        raise ValueError(f'{source}: replace text drawings with [image: name.png]')
    if '&dollar&' in text or r'\Target' in text:
        raise ValueError(f'{source}: corrupted formula source')
    name = source.stem.removesuffix('_theory')
    body, live = [], []
    code = False
    table = False
    formulas = 0
    for line in text.splitlines():
        if line.startswith('```'):
            body.append('</code></pre>' if code else '<pre><code>')
            code = not code
            continue
        if code:
            body.append(html.escape(line))
            live.append(line)
            continue
        image = IMAGE.fullmatch(line)
        if image:
            filename = image[1]
            path = ROOT / 'runtime' / filename
            if not path.is_file() or path.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
                raise ValueError(f'Missing real PNG: {path}')
            body.append(f'<figure><img src="../../runtime/{filename}" alt="{filename}"></figure>')
            live.append(f'%[text] ![{filename}](../../runtime/{filename})')
            continue
        if '[image:' in line:
            raise ValueError(f'Invalid image marker: {line}')
        tokens = list(TOKEN.finditer(line))
        formulas += sum(m[0].startswith('$') for m in tokens)
        validate_prose(line, source)
        if line.startswith('|'):
            if not table:
                body.append('<table>')
                table = True
            if not re.fullmatch(r'\|[\s:|\-]+\|', line):
                body.append('<tr>' + ''.join('<td>' + inline(c.strip()) + '</td>'
                    for c in line.strip('|').split('|')) + '</tr>')
        else:
            if table:
                body.append('</table>')
                table = False
            heading = re.match(r'^(#{1,6}) (.*)', line)
            if heading:
                level = len(heading[1])
                body.append(f'<h{level}>' + inline(heading[2]) + f'</h{level}>')
                # Section titles are not a math-rendering layer. The complete
                # heading, including formulas, is emitted once in %[text].
                live.append('%%')
            elif re.fullmatch(r'-{3,}', line):
                body.append('<hr>')
            elif line.startswith('$$') and line.rstrip().endswith('$$'):
                body.append(inline(line.rstrip()))
            else:
                body.append('<p>' + inline(line) + '</p>' if line else '')
        converted = TOKEN.sub(live_math, line)
        converted = re.sub(r'^\s*\* ', '- ', converted)
        converted = re.sub(r'^\s+(\d+\. )', r'\1', converted)
        live.append('%[text] ' + converted)
    if table:
        body.append('</table>')
    if code:
        raise ValueError('Unclosed code fence')
    head = '''<!DOCTYPE html>
<html lang="ru"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>NAME — математический паспорт</title>
<script>window.MathJax={tex:{inlineMath:[['\\\\(','\\\\)']],displayMath:[['\\\\[','\\\\]']]},startup:{ready:()=>{MathJax.startup.defaultReady();MathJax.startup.promise.then(()=>{document.body.dataset.mathReady='true';});}}};</script>
<script defer src="assets/tex-svg.js"></script>
<style>body{max-width:1100px;margin:auto;padding:24px;line-height:1.6}img{max-width:100%;height:auto}table{border-collapse:collapse}td{border:1px solid #888;padding:8px}pre,.math{overflow-x:auto}p{overflow-wrap:anywhere}</style>
</head><body><main>
'''.replace('NAME', name)
    output = head + '\n'.join(body) + '\n</main></body></html>\n'
    (DOCS / 'html' / f'{name}.html').write_text(clean_output(output), encoding='utf-8')
    for i, line in enumerate(live):
        if re.match(r'%\[text\] (?:- |\d+\. )', line):
            live[i] = re.sub(r'(?<!\\)\\_(?!\\)', r'\\\\\\_', line)
            following = live[i+1] if i+1 < len(live) else ''
            if not re.match(r'%\[text\] (?:- |\d+\. )', following):
                live[i] += ' \\'
    live.extend(['%[appendix]{"version":"1.0"}', '%---', '%[metadata:view]',
                 '%   data: {"layout":"hidecode","rightPanelPercent":6.7}', '%---'])
    (DOCS / 'liveeditor' / f'{name}_theory.m').write_text(clean_output('\n'.join(live)), encoding='utf-8')
    assert output.count('class="math"') == formulas
    print(f'{name}: {formulas} formulas; HTML and Live Editor generated; source SHA256 {hashlib.sha256(text.encode()).hexdigest()}')


if __name__ == '__main__':
    for source in sorted(DOCS.glob('*_theory.md')):
        build(source)