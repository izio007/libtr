# Запуск тестов

## В MATLAB: результат и открытые графики

Откройте каталог репозитория в MATLAB и выполните:

```matlab
addpath('matlab');
status = run_tests;
```

Можно открыть `matlab/run_tests.m` в редакторе и нажать **Run**. Для сохранения
возвращаемого результата используйте вызов с `status` в Command Window.
Python, TCP-сервер и JSON-конфигурация для этого не нужны.

Функция выполняет все `matlab/tests/unit_test_*.m`, печатает результат каждого
теста и общий итог. Ошибки не останавливают оставшиеся тесты. Затем она открывает
лёгкие примеры filter2win: восемь сценариев с измерениями, окнами и статусами,
а также два графика траектории и заполнения альтернативного окна.
Фигуры остаются открытыми. Большие Monte Carlo эксперименты автоматически
не запускаются после unit-тестов.

```matlab
status.unit.state             % 'passed' или 'failed' только для unit-тестов
status.unit.failures          % число не прошедших тестов
struct2table(status.unit.results)
status.plots                  % выполнение двух графических примеров
status.state                  % общий итог unit-тестов и примеров
status.output_dir             % каталог отчёта, логов, MAT и PNG
```

Каждый запуск создаёт новую папку `runtime/matlab_tests/...`. В ней находятся
`report.json`, `unit_results.json` и лог каждого теста. Проверки сохраняют свои
assertions; недоступное оборудование, например GPU для GPU-тестов, даёт ошибку
соответствующего теста, а не условный PASS. Статус графического примера отражает
его выполнение и проверки; сами графики вы оцениваете визуально.

Запуск не очищает workspace или globals и не закрывает ваши фигуры. Рабочий
каталог, path и состояние RNG восстанавливаются; перед каждым unit-тестом
устанавливается seed 1729. Общий исполнитель unit-тестов используется и MATLAB,
и серверным запуском.

## Из терминала

Если удобнее работать из shell, один раз запустите **отдельную** MATLAB-сессию
с `tools/matlab/tcpserver5555.m`, затем используйте прежние команды:

```sh
tools/runner.sh matlab/tests/configs/all_unit_runner.json
tools/runner.sh matlab/tests/configs/filter2win_runner.json
tools/runner.sh matlab/tests/configs/filter2win_consumers_runner.json
tools/runner.sh matlab/tests/configs/filter2win_integration_runner.json
```

`all_unit` выполняет все unit-тесты и собирает ошибки. `filter2win` выполняет
settings, persistent/schema-3 и schema-2; consumers — scenario, model и plot;
integration добавляет к ним проверку изоляции. Python останавливает такую
составную suite после первого неуспешного этапа.

Клиентский отчёт: `runtime/pipeline_runs/<id>/report.json`. В каждом этапе
находятся статус, время, `value` и ошибка при наличии. MATLAB сохраняет отчёт,
логи и данные в `runtime/pipeline/<job-id>`. Таймаут клиента не отменяет задание.

Выделенный сервер очищает свою сессию перед заданием; для интерактивной работы
с вашими переменными и фигурами используйте `run_tests`. Сервер работает
последовательно на `127.0.0.1:5555`; отмена кооперативная между этапами.
`pipeline_client.py` — внутренний клиент протокола. Служебные расчётные actions:
`all`, `environment`, `unit`, `integration`, `mapping`, `mapping5000`.
`all` выполняет environment, unit и integration. Экспорт документов к тестам
не относится. Для остановки свободного сервера создайте
`runtime/pipeline/stop-server` и удалите этот marker перед следующим стартом.

Проверки самого Python runner не требуют MATLAB:

```sh
tools/runner.sh matlab/tests/configs/pipeline_engine_runner.json
tools/runner.sh matlab/tests/configs/runner_contract.json
```
