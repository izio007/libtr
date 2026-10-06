# Одна команда выпуска filter2win

Запускать через Cygwin Bash из корня репозитория. Используются стандартная
библиотека Python, общий Pipeline и существующие build/acceptance/finalize.

Новый выпуск (каталоги должны отсутствовать; сервер должен работать и быть свободен):

```bash
bash tools/release_filter2win.sh --version 0.3.1 --staging runtime/Release/filter2win/0.3.1-staging --output runtime/Release/filter2win/0.3.1 --allow-host-replacement
```

Флаг явно разрешает существующему acceptance-адаптеру временно заменить
службу, проверить пакет в новом MATLAB-процессе и восстановить службу.
Проверки MATLAB идут через пакетный tools/runner.sh. Ошибка этапа останавливает
pipeline; его отчёт и defect сохраняются общим движком. Автоматического
повторного submit после ошибки нет.

Упаковка проверенного кандидата без повторных расчётов:

```bash
bash tools/release_filter2win.sh --version 0.3.0 --package runtime/Release/filter2win/0.3.0-staging/verification/filter2win-0.3.0 --output runtime/Release/filter2win/0.3.0-reviewed
```

Перед этим фактические аудиты записываются в results/release_review.json по
контракту tools/filter2win_acceptance.py. Скрипт проверяет привязку к байтам,
но не выдумывает визуальную приёмку. Exit 0 — принят выпуск, 2 — архив создан,
обязательная приёмка неполна, другая ошибка — исполнение не завершено.
Последняя JSON-строка содержит archive, release_status, remaining и execution_report.
PASS этапов упаковки не означает PASS приёмки. Старые архивы не перезаписываются.

Проверено живое выполнение ветви существующего кандидата 0.3.0: архив создан,
распакован, хеши проверены, неполная приёмка возвращена явно. Новая ветвь build
и замена сервера в рамках проверки этого адаптера повторно не запускались.