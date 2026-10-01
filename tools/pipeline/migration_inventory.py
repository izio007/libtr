"""Read-only inventory of MATLAB root files; not a relocation command."""
import argparse
import hashlib
from pathlib import Path
import re

from traceability_builder import publish


def inventory(root):
    root = Path(root).resolve()
    sources = sorted(p for p in (root / 'matlab').rglob('*.m') if p.is_file())
    texts = {p: p.read_text(encoding='utf-8-sig') for p in sources}
    items = []
    for path in sorted((root / 'matlab').iterdir()):
        if not path.is_file():
            continue
        raw = path.read_bytes()
        text = texts.get(path, '')
        definitions = re.findall(r'^\s*function\s+([^\r\n]+)', text, re.MULTILINE)
        name = path.stem
        references = [p.relative_to(root).as_posix() for p, content in texts.items()
                      if p != path and re.search(r'\b' + re.escape(name) + r'\b', content)]
        candidate = bool(definitions) and not name.endswith('_theory')
        items.append(dict(path=path.relative_to(root).as_posix(),
                          sha256=hashlib.sha256(raw).hexdigest(),
                          definitions=definitions,
                          proposed_target=('matlab/function/' + path.name) if candidate else None,
                          classification='kernel_candidate' if candidate else 'review_required',
                          textual_references=references,
                          relocation_check='same bytes; resolve paths; targeted tests',
                          verification_status='NOT_RUN'))
    return dict(schema_version=1, coverage='matlab_root_and_matlab_text_references',
                limitations=['Text references include comments and omit dynamic calls.',
                             'Classification is provisional; no files moved.'], files=items)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    publish(args.root, args.output, inventory(args.root))


if __name__ == '__main__':
    main()