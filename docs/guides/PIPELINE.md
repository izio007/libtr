# Запуск тестов

## В MATLAB

Из корня репозитория:

```matlab
addpath('matlab');
status = run_tests;                         % только unit, без открытых окон
status = run_tests('integration');          % выбрать интеграции в списке
status = run_tests('all');                  % выбрать интеграции и выполнить unit
```

В списке можно выбрать несколько строк. По умолчанию выбрана только
`filter2win`. **Cancel** возвращает `state='cancelled'` без запуска тестов.
Для запуска из скрипта укажите имена явно:

```matlab
status = run_tests('integration', {'filter2win'});
status = run_tests('integration', {'context30', 'tis'});
status = run_tests('all', {'filter2win', 'context450'});
```

| Имя | Что рассчитывается и показывается |
| --- | --- |
| `filter2win` | Измерения станций → WLLS → три координатных filter2win; истинная, исходная и отфильтрованная траектории, ошибки, пропуски и состояние окон |
| `context30` | Ближняя траектория ТИС: LLS, WLLS, GN, GNP; четыре окна с траекториями, ошибками и центральными ансамблями |
| `context450` | Дальняя траектория ТИС: те же четыре метода и отдельные окна |
| `tis` | Пять геометрий ТИС, четыре независимых решателя, 64 реализации на опорную точку; облака ошибок и эмпирические оси |

`context30` и `context450` используют действующие конфигурации, включая
5000 реализаций центрального ансамбля. Они требуют больше времени, чем
короткий filter2win-сценарий. Исходные измерения, результаты и PNG сохраняются;
видимые окна строятся по тем же расчётным данным. Допуски точности не выводятся
из внешнего вида графиков: отчёт содержит фактические метрики и проверки.

`run_tests` выполняет все `matlab/tests/unit_test_*.m`, собирает ошибки и
возвращает общий статус. Unit-рисунки сохраняются обычными тестами в PNG,
новые окна unit-тестов закрываются. `demo_filter2win` и генератор документных
картинок после unit-тестов автоматически не запускаются.

```matlab
status.state                         % 'passed', 'failed' или 'cancelled'
status.unit.state                    % 'not_run' при запуске только интеграций
status.unit.failures
struct2table(status.unit.results)
status.integration.state             % 'not_run' при запуске только unit
status.integration.results           % статус, время, ошибка и метрики каждого сценария
status.output_dir                     % каталог отчёта, логов, MAT и PNG
```

Каждый выполненный запуск создаёт папку `runtime/matlab_tests/...` с
`report.json`. Unit-результаты находятся в `unit_results.json`; выбранные
интеграции — в `integration_results.json` и подпапках с их именами. В каждой
подпапке интеграции есть `run.log`, данные и PNG. Ошибка одного выбранного
сценария сохраняется, остальные выполняются. Возвращённый ненулевой счётчик
ошибок также означает FAILED.

Запуск сохраняет workspace и ранее открытые фигуры. Рабочий каталог и RNG
восстанавливаются. Путь сохраняет существующие каталоги в прежнем порядке,
но записи уже удалённых каталогов отбрасываются перед запуском и при
восстановлении. `savepath` и сброс всей MATLAB-сессии не выполняются.
MATLAB Desktop не требует Python, TCP-сервера или JSON-конфига.

## Из терминала

Для этого способа используется отдельная MATLAB-сессия с
`tools/matlab/tcpserver5555.m`:

```sh
tools/runner.sh matlab/tests/configs/all_unit_runner.json
tools/runner.sh matlab/tests/configs/filter2win_runner.json
tools/runner.sh matlab/tests/configs/filter2win_consumers_runner.json
tools/runner.sh matlab/tests/configs/filter2win_integration_runner.json
```

`all_unit` выполняет все unit-тесты. `filter2win` запускает settings,
persistent/schema-3 и schema-2; consumers — проверки scenario, model и plot.
`filter2win_integration` теперь выполняет сам `integration_filter2win` через
`action=integration`, сохраняет MAT/PNG без открытия окон. Это тот же расчёт,
что `run_tests('integration', {'filter2win'})` в MATLAB Desktop.

Клиентский отчёт: `runtime/pipeline_runs/<id>/report.json`. MATLAB сохраняет
отчёт, логи и данные в `runtime/pipeline/<job-id>`. Таймаут клиента не отменяет
задание. Выделенный сервер очищает свою сессию перед заданием; для работы с
вашими переменными и фигурами используйте `run_tests`.

Сервер обрабатывает задания последовательно на `127.0.0.1:5555`.
Служебные actions: `all`, `environment`, `unit`, `integration`, `mapping`,
`mapping5000`. `all` выполняет environment, unit и все интеграции; серверный
`integration` без выбранного теста выполняет оба контекста, ансамбли ТИС и
filter2win. Экспорт документов к тестам не относится.
Для остановки свободного сервера создайте `runtime/pipeline/stop-server`
и удалите этот marker перед следующим стартом.

Адресные проверки Python-runner без MATLAB:

```sh
tools/runner.sh matlab/tests/configs/pipeline_engine_runner.json
tools/runner.sh matlab/tests/configs/runner_contract.json
```
