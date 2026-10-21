#!/usr/bin/env python3
"""Print one existing HTML file to PDF using an installed Chrome/Chromium.

Usage: python tools/docs/html_to_pdf.py source.html output.pdf [--browser PATH]
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def find_browser():
    for name in ('google-chrome', 'chromium', 'chromium-browser', 'chrome', 'msedge'):
        found = shutil.which(name)
        if found:
            return found
    candidates = [Path('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')]
    for base in ('PROGRAMFILES', 'PROGRAMFILES(X86)', 'LOCALAPPDATA'):
        if os.environ.get(base):
            candidates.append(Path(os.environ[base]) / 'Google/Chrome/Application/chrome.exe')
            candidates.append(Path(os.environ[base]) / 'Microsoft/Edge/Application/msedge.exe')
    return next((str(path) for path in candidates if path.is_file()), None)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--browser', help='Chrome/Chromium executable')
    args = parser.parse_args()
    browser = args.browser or find_browser()
    if not browser:
        parser.error('Chrome/Chromium not found; provide --browser PATH')
    source, output = args.source.resolve(), args.output.resolve()
    if not source.is_file():
        parser.error('HTML file not found: ' + str(source))
    if output == source:
        parser.error('Output must differ from the HTML source')
    output.parent.mkdir(parents=True, exist_ok=True)
    profile = tempfile.mkdtemp(prefix='libtr-pdf-')
    try:
        rendered = Path(profile) / 'document.pdf'
        subprocess.run([browser, '--headless', '--disable-gpu', '--no-first-run',
                        '--no-default-browser-check', '--no-pdf-header-footer',
                        '--user-data-dir=' + profile, '--virtual-time-budget=10000',
                        '--print-to-pdf=' + str(rendered), source.as_uri()], check=True, timeout=60)
        if not rendered.is_file() or rendered.stat().st_size == 0:
            raise RuntimeError('Browser did not create the PDF')
        shutil.copyfile(rendered, output)
    finally:
        shutil.rmtree(profile, ignore_errors=True)
    print(output)


if __name__ == '__main__':
    main()
