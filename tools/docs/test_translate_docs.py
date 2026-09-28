"""Run directly beside translate_docs.py; no working-directory dependency."""
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

    def test_generated_matrix_structure_entire_package(self):
        checked = 0
        for source in tr.DOCS.glob('*_theory.txt'):
            live = (tr.DOCS/'liveeditor'/f'{source.stem}.m').read_text(encoding='utf-8')
            for token in tr.TOKEN.finditer(source.read_text(encoding='utf-8-sig')):
                if r'\begin{bmatrix}' in token[0] or r'\begin{cases}' in token[0]:
                    rendered = tr.live_math(token)
                    self.assertIn(rendered, live, source.name)
                    self.assertEqual(rendered.count('&'), token[0].count('&'))
                    self.assertEqual(rendered.count('\\\\\\\\'), token[0].count('\\\\'))
                    checked += 1
        self.assertGreater(checked, 0)

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


class OutputHygieneTests(unittest.TestCase):
    def test_trailing_whitespace_and_idempotence(self):
        original = '%[text]   \r\n%[text] $x$ \t\r\ncode = 1;\n'
        expected = '%[text]\n%[text] $x$\ncode = 1;\n'
        self.assertEqual(tr.clean_output(original), expected)
        self.assertEqual(tr.clean_output(expected), expected)

    def test_matrix_serialization_exact(self):
        source = r'$$A = \begin{bmatrix} a_{11} & a_{12} \\ a_{21} & a_{22} \end{bmatrix}$$'
        expected = r'$A = \\begin{bmatrix} a\_{11} & a\_{12} \\\\ a\_{21} & a\_{22} \\end{bmatrix}$'
        self.assertEqual(tr.live_math(tr.TOKEN.fullmatch(source)), expected)
        # This proves transport conformance, NOT successful equation rendering.


if __name__ == '__main__':
    unittest.main()