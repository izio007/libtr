# Автономный выпуск filter2win 0.3.0

Команда Шефа: отдельный выпуск filter2win. Выбран текущий профиль схемы 3
с совместимостью схемы 2; прежние архивы не изменяются.
Состав: явные FILES/PRODUCTION в tools/package_filter2win.py.
Конфигурация: matlab/tests/configs/filter2win_package_case.json.
Staging: runtime/Release/filter2win/0.3.0-staging.
Итоговый каталог: runtime/Release/filter2win/0.3.0.

До исполнения: ядра, сценарии, эталоны и допуски не изменять. Проверить
runner_contract; распакованный пакет на изолированном path через штатный
filter2win_package.json; FIFO, настройки, схему 3, совместимость схемы 2,
демо, отрицательные зависимости, HTML/PDF/MLX и хеши ZIP.
Не переносить прежние PASS на новые байты. Визуальный аудит и новый процесс
учитывать отдельно; постоянный сервер без отдельного разрешения не заменять.
Неполную приёмку не объявлять PASS.

## Результат

Архив: runtime/Release/filter2win/0.3.0/filter2win-0.3.0.zip, 87 файлов.
SHA-256: cc358588951c667bc81a3ade40469c305e4727d3b2023771ddce4ca1cb047b84.
runner_contract: 7/7 PASS. Распакованный пакет: 19 групп PASS,
MATLAB PID 25744, new_server=false, время MATLAB 26.7636071 s.
HTML/PDF/MLX созданы; сигнатуры и контейнеры проверены. ZIP и хеши
повторной распаковки PASS. Отчёт: runtime/Release/filter2win/0.3.0/archive_report.json.
Это выполненный автономный пакет, не полностью принятый Release:
fresh_process, readability, html_visual, pdf_visual, mlx_visual, png_visual
остаются NOT_RUN. Наличие файлов не заменяет визуальный аудит.
Постоянный сервер сохранён; повторный запуск расчётов ради отсутствующего
аудита не требуется. Старые архивы и расчётные ядра не изменены.

## Продолжение: свежий процесс и архив со свидетельством

Предыдущий раздел описывает первоначальный архив, не текущий остаток.
В staging записан release_review.json с fresh_process PASS: PID 1512,
new_server=true, 19 групп PASS. Финализатор принял привязку review к байтам
кандидата и проверил новый архив и хеши его распаковки:
runtime/Release/filter2win/0.3.0-fresh-verified/filter2win-0.3.0.zip.
SHA-256: 24038adf202fcdbcd9674e476f0614e9ad4ea286e9e7c8e7754f6e317eaed4af.
Первоначальный архив не перезаписан. Расчёты повторно не запускались.
Остаток gate: readability, html_visual, pdf_visual, mlx_visual, png_visual.
Просмотренные ранее растровые страницы не доказывают отображение MLX
в Live Editor. Для этого требуется GUI-свидетельство, недоступное через
текущие инструменты агента. Повторение чтения PDF-снимков этот пункт не закрывает.