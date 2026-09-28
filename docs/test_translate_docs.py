"""Static regression checks for source-preserving documentation translation."""
import html
import re
import tempfile
import unittest
import sys
from pathlib import Path
sys.dont_write_bytecode = True
import translate_docs as tr


class TranslationTests(unittest.TestCase):
    def test_matrix_preserved(self):
        source = r'$$A=\begin{bmatrix}a&b\\c&d\end{bmatrix}$$'
        result = tr.live_math(tr.TOKEN.search(source))
        self.assertIn(r'\\begin{bmatrix}', result)
        self.assertIn(r'\\\\', result)
        self.assertEqual(result.count('&'), 2)

    def test_live_operator_compatibility(self):
        match = tr.TOKEN.search(r'$\operatorname{rcond}(A)$')
        result = tr.live_math(match)
        self.assertNotIn('operatorname', result)
        self.assertIn(r'\\mathrm{rcond}', result)

    def test_unmarked_mathematics_rejected(self):
        for text in [r'Вектор \mathbf{q}', "if rcond(J'*J) < 1e-16"]:
            with self.assertRaisesRegex(ValueError, 'Unmarked mathematics'):
                tr.validate_prose(text)
        tr.validate_prose(r'Вектор $\mathbf{q}$ и `C:\temp`')

    def test_section_headers_contain_no_tex(self):
        for path in (tr.DOCS/'liveeditor').glob('*_theory.m'):
            for line in path.read_text(encoding='utf-8').splitlines():
                if line.startswith('%%'):
                    self.assertEqual(line, '%%')

    def test_formula_encoding(self):
        result = tr.inline(r'Текст $x_i < 2$ и `A*B`, $$\sum_{i=1}^n x_i$$')
        self.assertIn(r'\(x_i &lt; 2\)', result)
        self.assertIn(r'\[\sum_{i=1}^n x_i\]', result)
        self.assertNotIn(r'\\sum', result)
        self.assertIn('<code>A*B</code>', result)

    def test_sources_and_outputs(self):
        for source in sorted(tr.DOCS.glob('*_theory.txt')):
            with self.subTest(source=source.name):
                text = source.read_text(encoding='utf-8-sig')
                code = False
                for line in text.splitlines():
                    if line.startswith('```'):
                        code = not code
                    elif not code:
                        tr.validate_prose(line, source)
                name = source.stem.removesuffix('_theory')
                page = (tr.DOCS/'html'/f'{name}.html').read_text(encoding='utf-8')
                expected = []
                for token in tr.TOKEN.findall(text):
                    if token.startswith('$'):
                        n = 2 if token.startswith('$$') else 1
                        expected.append(token[n:-n])
                actual = re.findall(r'class="math">\\[\[(](.*?)\\[\])]</(?:div|span)>', page)
                self.assertEqual(expected, [html.unescape(x) for x in actual])
                self.assertNotRegex(text, r'[┌┐└┘│─]|[•_x]{5,}')
                for filename in re.findall(r'^\[image: (.*?)\]$', text, re.M):
                    self.assertIn(f'src="../../runtime/{filename}"', page)
                    self.assertEqual((tr.ROOT/'runtime'/filename).read_bytes()[:8], b'\x89PNG\r\n\x1a\n')
                live = (tr.DOCS/'liveeditor'/f'{name}_theory.m').read_text(encoding='utf-8')
                self.assertNotIn('%[output:', live)
                self.assertNotIn('&dollar&', live)
                self.assertNotIn('data:image', live)

    def test_reject_pseudographics(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)/'bad_theory.txt'
            p.write_text('25 | •••••••', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'text drawings'):
                tr.build(p)

    def test_reject_missing_image(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)/'bad_theory.txt'
            p.write_text('[image: deliberately_absent_image.png]', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'Missing real PNG'):
                tr.build(p)


if __name__ == '__main__':
    unittest.main()