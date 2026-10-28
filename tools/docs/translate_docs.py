#!/usr/bin/env python3
"""Convert one Markdown document to HTML or MATLAB Live Editor text.

Examples:
  python tools/docs/translate_docs.py docs/filter2win_theory.md --format html
  python tools/docs/translate_docs.py docs/filter2win_theory.md --format liveeditor
  python tools/docs/translate_docs.py docs/tis_research_theory.md --format html --images runtime/my_run

Python 3.10+. HTML dependencies: tools/docs/requirements.txt; Live Editor: standard library. Source documents and calculation data are not changed.
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


def to_html(text, source, output, images):
    from markdown_it import MarkdownIt
    from mdit_py_plugins.dollarmath import dollarmath_plugin
    from urllib.parse import urlsplit, unquote

    # A real Markdown parser owns paragraphs, lists, tables and emphasis.
    md = MarkdownIt('commonmark', {'html': False, 'breaks': False})
    md.enable(['table', 'strikethrough']).use(dollarmath_plugin)
    def math_inline(tokens, index, options, env):
        return chr(92) + '(' + html.escape(tokens[index].content) + chr(92) + ')'
    def math_block(tokens, index, options, env):
        return '<div class="math">' + chr(92) + '[' + html.escape(tokens[index].content) + chr(92) + ']</div>'
    md.renderer.rules['math_inline'] = math_inline
    md.renderer.rules['math_block'] = math_block

    # Preserve the project's older image marker without interpreting code fences.
    lines = []; fenced = False
    for line in text.splitlines():
        if line.startswith('```'):
            fenced = not fenced
        picture = None if fenced else IMAGE.fullmatch(line)
        if picture:
            line = '![' + picture[1] + '](' + relative_url(images / picture[1], source) + ')'
        lines.append(line)
    tokens = md.parse(chr(10).join(lines))
    def relocate(items):
        for token in items:
            attribute = 'src' if token.type == 'image' else 'href' if token.type == 'link_open' else None
            if attribute:
                target = token.attrGet(attribute)
                parsed = urlsplit(target)
                if not parsed.scheme and not parsed.netloc and parsed.path:
                    target = relative_url(source.parent / unquote(parsed.path), output)
                    if parsed.query: target += '?' + parsed.query
                    if parsed.fragment: target += '#' + parsed.fragment
                    token.attrSet(attribute, target)
            if token.children:
                relocate(token.children)
    relocate(tokens)
    for index, token in enumerate(tokens):
        if token.type == 'heading_open':
            title = tokens[index + 1].content.lower()
            slug = ''.join(c for c in title if c.isalnum() or c in ' -_').replace(' ', '-')
            token.attrSet('id', slug)
    body = md.renderer.render(tokens, md.options, {})
    mathjax = html.escape(relative_url(ROOT / 'docs/html/assets/tex-svg.js', output), quote=True)
    config = json.dumps({'tex': {'inlineMath': [[chr(92)+'(', chr(92)+')']],
                                  'displayMath': [[chr(92)+'[', chr(92)+']']]}})
    title = html.escape(source.stem)
    return f'''<!doctype html>
<html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<script>window.MathJax={config};</script>
<script defer src="{mathjax}"></script>
<style>
body{{margin:0;background:#fff;color:#20252b;font:16px/1.25 -apple-system,BlinkMacSystemFont,"Segoe UI",Arial,sans-serif}}
main{{max-width:960px;margin:0 auto;padding:36px 28px 80px}}
h1,h2,h3{{line-height:1.3;margin:1.6em 0 .65em;font-weight:650;color:#17202a}}
h1{{font-size:2em;margin-top:0}}h2{{font-size:1.5em;border-bottom:1px solid #d8dee4;padding-bottom:.3em}}
h3{{font-size:1.18em}}p{{margin:0 0 .55em;text-indent:1.5em}}ul,ol{{margin:0 0 1em;padding-left:1.8em}}
li{{margin:.3em 0}}li p{{margin:.25em 0;text-indent:0}}td p,th p{{text-indent:0}}strong{{font-weight:700}}
a{{color:#0969da;text-decoration:none}}a:hover{{text-decoration:underline}}
img{{max-width:100%;height:auto;display:block;margin:1.3em auto}}
table{{display:block;max-width:100%;overflow-x:auto;border-collapse:collapse;margin:1em 0 1.5em;font-size:.95em}}
th,td{{border:1px solid #d0d7de;padding:9px 12px;text-align:left;vertical-align:top}}th{{background:#f3f5f7}}
tbody tr:nth-child(even){{background:#fafbfc}}blockquote{{margin:1em 0;border-left:4px solid #d0d7de;padding-left:1em;color:#57606a}}
code{{background:#f0f2f4;border-radius:4px;padding:.15em .3em;font-size:.9em}}pre{{overflow:auto;background:#f6f8fa;padding:16px}}
pre code{{background:none;padding:0}}.math{{overflow-x:auto;margin:1.3em 0;padding:.2em 0}}
@media(max-width:640px){{main{{padding:20px 16px}}body{{font-size:15px}}}}
@media print{{main{{max-width:none;padding:0}}h2,h3{{break-after:avoid}}img,table,.math{{break-inside:avoid}}}}
</style></head><body><main>
{body}
</main></body></html>
'''


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
