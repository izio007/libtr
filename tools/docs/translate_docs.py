#!/usr/bin/env python3
"""Convert one Markdown document to HTML or MATLAB Live Editor text.

Examples:
  python tools/docs/translate_docs.py docs/filter2win_theory.md --format html
  python tools/docs/translate_docs.py docs/filter2win_theory.md --format liveeditor
  python tools/docs/translate_docs.py docs/tis_research_theory.md --format html --images runtime/my_run

Python 3.9+, standard library. Source documents and calculation data are not changed.
Mermaid and other non-MATLAB fenced blocks become comments in Live Editor.
"""
import argparse
import html
import json
import os
from pathlib import Path
import re
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[2]
TOKEN = re.compile(r'(`[^`\n]+`|\$\$.*?\$\$|\$[^$\n]+\$)')
IMAGE = re.compile(r'^\[image: (.+)\]$')


def relative_url(path, output):
    try:
        return quote(os.path.relpath(path, output.parent).replace(os.sep, '/'), safe='/')
    except ValueError:  # Different Windows drives.
        return path.resolve().as_uri()


def html_inline(text, source=None, output=None):
    parts = []
    for part in TOKEN.split(text):
        if part.startswith('`'):
            parts.append('<code>' + html.escape(part[1:-1]) + '</code>')
        elif part.startswith('$'):
            display = part.startswith('$$')
            n = 2 if display else 1
            left, right = (r'\[', r'\]') if display else (r'\(', r'\)')
            parts.append(left + html.escape(part[n:-n]) + right)
        else:
            escaped = html.escape(part)
            pattern = re.escape('[') + r'([^]]+)' + re.escape('](') + r'([^)]*)' + re.escape(')')
            def link(match):
                target = html.unescape(match[2])
                if re.match(r'^(https?://|mailto:|#)', target):
                    url = target
                elif source is not None and output is not None:
                    path, mark, anchor = target.partition('#')
                    url = relative_url(source.parent / path, output) + (mark + anchor if mark else '')
                else:
                    return match[0]
                return '<a href="' + html.escape(url, quote=True) + '">' + match[1] + '</a>'
            parts.append(re.sub(pattern, link, escaped))
    return ''.join(parts)


def to_html(text, source, output, images):
    body = []
    code = table = False
    display_lines = None
    for line in text.splitlines():
        if line.startswith('```'):
            if table:
                body.append('</table>'); table = False
            body.append('</code></pre>' if code else '<pre><code>')
            code = not code
            continue
        if code:
            body.append(html.escape(line))
            continue
        if line.strip() == '$$':
            if display_lines is None:
                display_lines = []
            else:
                formula = html.escape(chr(10).join(display_lines))
                body.append('<div class="math">' + chr(92) + '[' + formula + chr(92) + ']</div>')
                display_lines = None
            continue
        if display_lines is not None:
            display_lines.append(line)
            continue
        if line.startswith('|'):
            if not table:
                body.append('<table>'); table = True
            if not re.fullmatch(r'\|[\s:|\-]+\|', line):
                body.append('<tr>' + ''.join('<td>' + html_inline(c.strip(), source, output) + '</td>'
                                             for c in line.strip('|').split('|')) + '</tr>')
            continue
        if table:
            body.append('</table>'); table = False
        markdown_picture = re.fullmatch(r'!\[(.*?)\]\(([^)]+)\)', line.strip())
        if markdown_picture:
            target = markdown_picture[2]
            url = target if re.match(r'https?://', target) else relative_url(source.parent / target, output)
            body.append('<figure><img src="' + html.escape(url, quote=True) + '" alt="' + html.escape(markdown_picture[1], quote=True) + '"></figure>')
            continue
        picture = IMAGE.fullmatch(line)
        heading = re.match(r'^(#{1,6}) (.*)', line)
        if picture:
            url = html.escape(relative_url(images / picture[1], output), quote=True)
            body.append(f'<figure><img src="{url}" alt="{html.escape(picture[1], quote=True)}"></figure>')
        elif heading:
            level = len(heading[1])
            body.append(f'<h{level}>' + html_inline(heading[2], source, output) + f'</h{level}>')
        elif re.fullmatch(r'-{3,}', line):
            body.append('<hr>')
        elif line.startswith('$$') and line.rstrip().endswith('$$'):
            body.append('<div class="math">' + html_inline(line.rstrip(), source, output) + '</div>')
        else:
            body.append('<p>' + html_inline(line, source, output) + '</p>' if line else '')
    if table:
        body.append('</table>')
    if code:
        body.append('</code></pre>')
    if display_lines is not None:
        raise ValueError('Unclosed display formula ($$)')
    math_config = json.dumps({'tex': {
        'inlineMath': [[chr(92)+'(', chr(92)+')'], ['$', '$']],
        'displayMath': [[chr(92)+'[', chr(92)+']'], ['$$', '$$']],
        'processEscapes': True
    }})
    mathjax = html.escape(relative_url(ROOT / 'docs/html/assets/tex-svg.js', output), quote=True)
    title = html.escape(source.stem)
    header = f'''<!doctype html>
<html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<script>window.MathJax={math_config};</script>
<script defer src="{mathjax}"></script>
<style>body{{max-width:1100px;margin:auto;padding:24px;line-height:1.6}}img{{max-width:100%;height:auto}}table{{border-collapse:collapse}}td{{border:1px solid #888;padding:8px}}pre,.math{{overflow-x:auto}}p{{overflow-wrap:anywhere}}</style>
</head><body><main>
'''
    return header + '\n'.join(body) + '\n</main></body></html>\n'


def live_formula(match):
    token = match[0]
    if token.startswith('`'):
        return token
    n = 2 if token.startswith('$$') else 1
    tex = token[n:-n].replace(r'\operatorname{rcond}', r'\mathrm{rcond}')
    tex = tex.replace('\\', '\\\\')
    tex = re.sub(r'(?<!\\)_', r'\\_', tex)
    tex = tex.replace('[', r'\[').replace(']', r'\]')
    tex = tex.replace('<', r'\<').replace('>', r'\>')
    return '$' + tex + '$'


def to_liveeditor(text, output, images):
    lines = []
    code = False
    executable = False
    for line in text.splitlines():
        if line.startswith('```'):
            if not code:
                executable = line[3:].strip().lower() == 'matlab'
            code = not code
            continue
        if code:
            lines.append(line if executable else '% ' + line)
            continue
        picture = IMAGE.fullmatch(line)
        if picture:
            lines.append(f'%[text] ![{picture[1]}]({relative_url(images / picture[1], output)})')
            continue
        if re.match(r'^#{1,6} ', line):
            lines.append('%%')
        converted = TOKEN.sub(live_formula, line)
        converted = re.sub(r'^\s*\* ', '- ', converted)
        converted = re.sub(r'^\s+(\d+\. )', r'\1', converted)
        lines.append('%[text] ' + converted)
    for i, line in enumerate(lines):
        if re.match(r'%\[text\] (?:- |\d+\. )', line):
            lines[i] = re.sub(r'(?<!\\)\\_(?!\\)', r'\\\\\\_', line)
            following = lines[i+1] if i+1 < len(lines) else ''
            if not re.match(r'%\[text\] (?:- |\d+\. )', following):
                lines[i] += ' \\'
    lines.extend(['%[appendix]{"version":"1.0"}', '%---', '%[metadata:view]',
                  '%   data: {"layout":"hidecode","rightPanelPercent":6.7}', '%---'])
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--format', choices=('html', 'liveeditor'), required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--images', type=Path, default=ROOT / 'runtime')
    args = parser.parse_args()
    source = args.source.resolve()
    if args.output:
        output = args.output.resolve()
    elif args.format == 'html':
        output = ROOT / 'docs/html' / (source.stem.removesuffix('_theory') + '.html')
    else:
        output = ROOT / 'docs/liveeditor' / (source.stem + '.m')
    if output == source:
        parser.error('Output must differ from the source document')
    text = source.read_text(encoding='utf-8-sig')
    images = args.images.resolve()
    rendered = to_html(text, source, output, images) if args.format == 'html' else to_liveeditor(text, output, images)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(rendered, encoding='utf-8')
    print(output)


if __name__ == '__main__':
    main()
