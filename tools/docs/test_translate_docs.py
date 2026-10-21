"""Translator unit tests using temporary fixtures, not project-passport acceptance."""
import base64
import contextlib
import html
import io
import re
import tempfile
import unittest
import sys
from pathlib import Path
sys.dont_write_bytecode = True
import translate_docs as tr


FIXTURE_MARKDOWN = '# Пример $x_i$\n\nТекст $x_i < 2$ и значение $x_i$.\n$$A = \\begin{bmatrix} a_{11} & a_{12} \\\\ a_{21} & a_{22} \\end{bmatrix}$$\n$$f(x) = \\begin{cases} 0 & x < 0 \\\\ 1 & x \\ge 0 \\end{cases}$$\n\n| Величина | Определение |\n| --- | --- |\n| Норма | $\\Vert x\\Vert$ |\n\n```matlab\nx = [1, 2];\ny = x(1) < x(2);\n```\n\n[image: fixture.png]\n'

# A transparent 1 x 1 PNG, independent of calculation artifacts.
FIXTURE_PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII='


class TranslationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.addCleanup(setattr, tr, 'ROOT', tr.ROOT)
        self.addCleanup(setattr, tr, 'DOCS', tr.DOCS)
        tr.ROOT = Path(temporary.name)
        tr.DOCS = tr.ROOT / 'docs'
        tr.DOCS.mkdir()
        (tr.ROOT / 'runtime').mkdir()
        self.source = tr.DOCS / 'fixture_theory.md'
        self.source.write_text(FIXTURE_MARKDOWN, encoding='utf-8')
        (tr.ROOT / 'runtime' / 'fixture.png').write_bytes(base64.b64decode(FIXTURE_PNG))
        self.page = tr.DOCS / 'html' / 'fixture.html'
        self.live = tr.DOCS / 'liveeditor' / 'fixture_theory.m'
        # build must work without pre-existing generated-output directories.
        with contextlib.redirect_stdout(io.StringIO()):
            tr.build(self.source)

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

    def test_fixture_generated_matrix_structure(self):
        live = self.live.read_text(encoding='utf-8')
        checked = 0
        for token in tr.TOKEN.finditer(FIXTURE_MARKDOWN):
            if r'\begin{bmatrix}' in token[0] or r'\begin{cases}' in token[0]:
                rendered = tr.live_math(token)
                self.assertIn(rendered, live)
                self.assertEqual(rendered.count('&'), token[0].count('&'))
                self.assertEqual(rendered.count('\\' * 4), token[0].count('\\' * 2))
                checked += 1
        self.assertEqual(checked, 2)

    def test_unmarked_mathematics_rejected(self):
        for text in [r'Вектор \mathbf{q}', "if rcond(J'*J) < 1e-16"]:
            with self.assertRaisesRegex(ValueError, 'Unmarked mathematics'):
                tr.validate_prose(text)
        tr.validate_prose(r'Вектор $\mathbf{q}$ и `C:\temp`')

    def test_fixture_section_headers_contain_no_tex(self):
        headers = [line for line in self.live.read_text(encoding='utf-8').splitlines()
                   if line.startswith('%%')]
        self.assertTrue(headers)
        self.assertTrue(all(line == '%%' for line in headers))

    def test_formula_encoding(self):
        result = tr.inline(r'Текст $x_i < 2$ и `A*B`, $$\sum_{i=1}^n x_i$$')
        self.assertIn(r'\(x_i &lt; 2\)', result)
        self.assertIn(r'\[\sum_{i=1}^n x_i\]', result)
        self.assertNotIn(r'\\sum', result)
        self.assertIn('<code>A*B</code>', result)

    def test_fixture_sources_and_outputs(self):
        # This checks translation of a controlled fixture, not real passports.
        text = self.source.read_text(encoding='utf-8')
        page = self.page.read_text(encoding='utf-8')
        expected = []
        for token in tr.TOKEN.findall(text):
            if token.startswith('$'):
                n = 2 if token.startswith('$$') else 1
                expected.append(token[n:-n])
        actual = re.findall(r'class="math">\\[\[(](.*?)\\[\])]</(?:div|span)>', page)
        self.assertEqual(expected, [html.unescape(x) for x in actual])
        self.assertIn('<table>', page)
        self.assertIn('<td>Норма</td>', page)
        self.assertIn('<pre><code>', page)
        self.assertIn('x = [1, 2];', page)
        self.assertIn('y = x(1) &lt; x(2);', page)
        self.assertIn('src="../../runtime/fixture.png"', page)
        self.assertEqual((tr.ROOT / 'runtime' / 'fixture.png').read_bytes()[:8],
                         b'\x89PNG\r\n\x1a\n')
        live = self.live.read_text(encoding='utf-8')
        self.assertIn('x = [1, 2];', live)
        self.assertIn('y = x(1) < x(2);', live)
        self.assertIn('%[text] ![fixture.png](../../runtime/fixture.png)', live)
        self.assertNotIn('%[output:', live)
        self.assertNotIn('&dollar&', live)
        self.assertNotIn('data:image', live)

    def test_reject_pseudographics(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)/'bad_theory.md'
            p.write_text('25 | •••••••', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'text drawings'):
                tr.build(p)

    def test_reject_missing_image(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)/'bad_theory.md'
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
