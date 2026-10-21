# Преобразование документов

Исходники — Markdown в `docs/`. Каждый инструмент выполняет одну указанную
операцию и печатает путь к результату. Повторный запуск обновляет выходной файл.
MATLAB-расчёты, unit-тесты и упаковка к преобразованию документов не относятся.

## Markdown → HTML

Из корня репозитория:

```sh
python tools/docs/translate_docs.py docs/filter2win_theory.md --format html
```

Результат: `docs/html/filter2win.html`. Открыть в браузере.
Для формул используется существующий локальный MathJax из `docs/html/assets/`.
Инструмент поддерживает используемый в математических документах простой
Markdown: заголовки, абзацы, таблицы, блоки кода и формулы `$...$` / `$$...$$`.

## Markdown → Live Editor

```sh
python tools/docs/translate_docs.py docs/filter2win_theory.md --format liveeditor
```

Результат: `docs/liveeditor/filter2win_theory.m`. Открыть в MATLAB Live Editor.
Для обоих форматов можно задать свой путь через `--output`.

## Изображения

Существующие строки `[image: name.png]` ссылаются на файлы в `runtime/`.
Другую папку с готовыми графиками можно указать явно:

```sh
python tools/docs/translate_docs.py docs/tis_research_theory.md --format html --images runtime/my_run
```

Преобразователь вставляет ссылки на эти файлы. Отсутствующий график можно
создать отдельно и открыть документ снова; расчёт автоматически не запускается.

## HTML → PDF

Нужен установленный Chrome, Chromium или Edge:

```sh
python tools/docs/html_to_pdf.py docs/html/filter2win.html runtime/filter2win.pdf
```

Если браузер не найден, указать исполняемый файл через `--browser`.

## Live Editor → PDF

В MATLAB, из корня репозитория:

```matlab
addpath('tools/docs');
export_liveeditor('docs/liveeditor/filter2win_theory.m', 'runtime/filter2win.pdf');
```

Код примеров при экспорте не выполняется. Используется установленный MATLAB
с поддержкой `export` для Live Editor.

У преобразователей нет тестовой системы, профиля допустимых формул,
отдельного этапа приёмки, отчётов с PASS или связи с TCP-сервером.
Если конкретный результат выглядит неправильно, исправляется соответствующий
скрипт или исходная разметка; полный расчётный прогон для этого не нужен.
