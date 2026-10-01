# 09. Миграция структуры репозитория

## Адаптер идеальных наблюдений, 2026-09-30 (без коммита)

service_ideal_mock_position перенесён из matlab/tests/support/ в tools/matlab/.
SHA-256 до/после: FD1009C10EEDFCCD0BB04402C8419D9CC3180A422F2A24805A1945624BE5B8A8.
Контракт: tools/pipeline/ideal_relocation_contract.md.
TCP ideal_before_20260930 — PASS (unit_test_engine_isolation).
TCP ideal_after_20260930 — PASS: разрешение на чистом пути без support,
недоступность на production path, известная цель [2;3;4], отказ короткой сети,
повтор прежней регрессии. Адаптер не объявляется независимым репером.
Граф: runtime/traceability/graph_ideal_move.json.
Эталонная приёмка 30/450 км NOT_RUN; HTML/Live Editor и коммит не выполнялись.

## Синтетика углового шума, 2026-09-30 (без коммита)

service_add_noise_ox перенесён из matlab/tests/support/ в tools/matlab/.
SHA-256 до/после: E68C00F1B6C78D745550D7E9A40FD1EB00AF74EDC22086E827BE4360D6CD101E.
Контракт: tools/pipeline/noise_relocation_contract.md.
TCP noise_before_20260930 — PASS: осевые реперы, размеры, повторяемость seed,
линейное масштабирование шума. TCP noise_after_20260930 — PASS: те же checks,
единственность разрешения и отсутствие функции на производственном пути.
В отслеживаемом коде вызовы не найдены; внешние потребители этим не исключены.
Изменение глобального rng сохранено; уточнение его контракта внесено в need_work.md.
Граф: runtime/traceability/graph_noise_move.json.
Эталонная приёмка NOT_RUN; HTML/Live Editor и коммит не выполнялись.

## Испытательные метрики, 2026-09-30 (без коммита)

service_ensemble_metrics и service_cumulative_rmse перенесены из
matlab/tests/support/ в tools/matlab/ без изменения байтов.
SHA-256 до/после соответственно:
228E0006093E44DE9346B01EE42D6A692B1542B93BA799B39F33C84701D72695;
AC245D603A65587FAABE2C77D09833CA3441DFA61594EBB49B43A29E1227357F.
Контракт: tools/pipeline/metrics_relocation_contract.md.
До переноса три TCP-запуска *_metricsbefore_20260930 — PASS:
unit_test_ensemble_metrics, unit_test_graphical_experiments,
unit_test_integration_independence.
После: runtime/pipeline/metrics_after_20260930 — PASS; составной тест
повторяет три регрессии и проверяет чистые пути, независимые моменты,
начальный/промежуточный отказы накопленного RMSE.
Граф: runtime/traceability/graph_metrics_move.json.
Производственная математика и эталоны не менялись; визуальная приёмка
30/450 км NOT_RUN. HTML/Live Editor и коммит не выполнялись.

## Синтетика пеленгов, 2026-09-30 (без коммита)

service_sample_bearings перенесён из matlab/tests/support/ в tools/matlab/.
SHA-256 до/после: 4716F7B19679F496D4A1477F22CFFD8253799D4D8F5845C5AE0C787C875627A7.
Контракт: tools/pipeline/sample_relocation_contract.md.
TCP sample_before_20260930 — PASS (unit_test_graphical_experiments).
TCP sample_after_20260930 — PASS: единственность разрешения, отсутствие
синтетики на production path, осевой геометрический репер с воспроизводимым
шумом, прежний тест и smoke-прогон tis_experiment_cell (4 метода, 8 наблюдений).
MAT сохранён, путь в runtime/pipeline/sample_after_20260930/unit_test_sample_relocation.log.
Граф: runtime/traceability/graph_sample_move.json.
service_add_noise_ox не переносился; оставшиеся support-функции требуют отдельного аудита.
Математика и эталоны не менялись; эталонная приёмка NOT_RUN, экспорт и коммит не выполнялись.

## Интеграционный relocation-прогон, 2026-09-30 (без коммита)

Контракт: tools/pipeline/relocation_suite_contract.md.
Новый unit_test_relocation_suite запускает существующий раннер на чистом пути
в уникальном runtime-каталоге. TCP relocation_suite_20260930 — PASS.
Девять вложенных checks успешны: production isolation, engine isolation,
ensemble metrics, integration independence, graphical experiments, pipeline,
document profile, mock position, mock covariance.
Проверены девять уникальных записей JSON и логов, восстановление path/pwd,
отказ повторного каталога без перезаписи отчёта.
Свидетельство: runtime/pipeline/relocation_suite_20260930/;
путь вложенного отчёта указан в unit_test_relocation_suite.log.
Граф: runtime/traceability/graph_relocation_suite.json.
В need_work убрано устаревшее утверждение о неперенесённых ядрах.
Перенос файлов завершён; классификация support/ и общий аудит ещё открыты.
Эталонная приёмка NOT_RUN. Экспорт документов и коммит не выполнялись.

## Явный сценарий filter2win, 2026-09-30 (без коммита)

Расчёт из test_twofilter выделен в tools/matlab/filter2win_scenario.m.
Генератор PNG и интерактивный сценарий вызывают функцию напрямую; strrep/eval
удалены. Производственное ядро и команды оформления графиков неизменны.
Контракт: tools/pipeline/filter_scenario_contract.md.
До изменения сохранены MAT и исходные сценарии в
runtime/filter_scenario_baseline_20260930/ из предыдущего успешного запуска.
TCP filter_scenario_migration_20260930 — PASS: все пять массивов isequaln
со снимком, повторяемость и регрессия генератора PNG подтверждены.
Одноразовый тест после выполнения переименован из unit_test_filter_scenario_migration
в run_filter_scenario_migration_check, чтобы общий unit-прогон не требовал
локального runtime-снимка. Постоянный unit_test_filter_scenario снимка не требует.
Граф: runtime/traceability/graph_filter_scenario.json.
Визуальное попиксельное сравнение не выполнялось; эталоны 30/450 км не проверены.
HTML/Live Editor и коммит не выполнялись.

## Путь генератора графиков filter2win, 2026-09-30 (без коммита)

generate_filter2win_doc_images подключает matlab/function/ вместо matlab/.
Контракт: tools/pipeline/filter_plot_path_contract.md.
TCP filter_plot_path_20260930: PASS на чистом пути с одним matlab/tests/.
Созданы расчётные MAT, два PNG и метрики в уникальном runtime-каталоге;
путь указан в runtime/pipeline/filter_plot_path_20260930/unit_test_filter_plot_path.log.
Проверены восстановление path/rng и точный повтор 101 сохранённого измерения,
включая NaN: выходы и мощность окна совпадают. Это проверка целостности
данных, не независимое доказательство математики или визуальная приёмка.
Граф: runtime/traceability/graph_filter_plot_path.json.
Оформление и сценарий не изменены; HTML/Live Editor и коммит не выполнялись.
unit_test_document_profile исследован: он использует синтетические файлы
валидатора, экспорт не запускает; оснований удалять его из раннера нет.

## Автономный mock-раннер, 2026-09-30 (без коммита)

run_mock_traceability больше не добавляет корень matlab/.
Снимок path и onCleanup создаются до setup_test_paths: исходный путь
восстанавливается и при успехе, и при отказе существующего выходного каталога.
Контракт: tools/pipeline/mock_runner_path_contract.md.
TCP mock_runner_path_20260930: PASS. На чистом пути выполнены две mock-проверки,
сформированы расчётные MAT/JSON/PNG в новом runtime-каталоге (путь в логе).
Повторный запуск отклонён без изменения report.json; path сохранён.
Свидетельство: runtime/pipeline/mock_runner_path_20260930/.
Граф: runtime/traceability/graph_mock_runner_path.json.
Это не эталонное сравнение 30/450 км. HTML/Live Editor не экспортировались.

## Тестовая композиция без корня matlab/, 2026-09-30 (без коммита)

setup_test_paths больше не добавляет каталог производных паспортов matlab/.
Пользовательские пути не удаляются. Контракт: tools/pipeline/test_path_contract.md.
unit_test_test_paths начинает с restoredefaultpath, явно очищает загруженную
setup_test_paths, проверяет отсутствие корня, единственность разрешения всех
ядер, движка и реперов, идемпотентность настройки. В той же чистой среде проходят
unit_test_engine_isolation, unit_test_integration_independence,
unit_test_ensemble_metrics и unit_test_graphical_experiments.
TCP clean_test_paths_20260930: PASS (один составной check, четыре регрессии).
Свидетельство: runtime/pipeline/clean_test_paths_20260930/.
Граф: runtime/traceability/graph_test_paths.json.
Производственные алгоритмы не менялись. Полный аудит сценариев и эталонная
приёмка не выполнены; HTML/Live Editor и коммит не выполнялись.

## Строгая изоляция после переноса, 2026-09-30 (без коммита)

Контракт: tools/pipeline/production_path_contract.md.
unit_test_production_isolation больше не добавляет корень matlab/ и не допускает
его файлы в производственных зависимостях. Проверяются все ядра и движок,
единственность разрешения, отсутствие mock и setup_test_paths на чистом пути.
До изменения isolation_before_strict_20260930 — PASS.
После production_path_strict_20260930 — PASS; новый тест-обёртка явно очищает
старую загруженную версию проверки в длительно работающем MATLAB-процессе.
Свидетельства: runtime/pipeline/production_path_strict_20260930/.
Граф: runtime/traceability/graph_production_path.json.
Математика, общая тестовая настройка путей и эталоны не изменены.
Статический контроль не доказывает отсутствие всех динамических зависимостей.
Эталонная приёмка NOT_RUN; экспорт и коммит не выполнялись.

## Срез filter2win, 2026-09-30 (без коммита)

matlab/filter2win.m → matlab/function/filter2win.m, без изменения байтов.
SHA-256 до/после: C0092D8DD9702AC72D76B9C6DCB1E23EAC8A09EFAC5C7CB8F782E8FF492EE178.
Контракт: tools/pipeline/filter2win_relocation_contract.md.
TCP: unit_test_filter2win до (filter2win_before_20260930) — PASS;
после unit_test_filter2win, unit_test_filter2win_relocation,
unit_test_production_isolation — 3/3 PASS.
Свидетельства после: runtime/pipeline/*_filterafter_20260930.
Проверены чистый путь, независимость двух состояний, среднее, неизменность
состояния при повторе времени и включающая граница удержания.
Граф: runtime/traceability/graph_filter_move.json.
Эталонная приёмка NOT_RUN; экспорт и коммит не выполнялись.

## Срез mock, 2026-09-30 (без коммита)

Имитационные реперы mock_position и mock_covariance перенесены из matlab/
в tools/matlab/ согласно ответственности испытательного контура.
SHA-256 до/после совпадают:
- mock_position: 3221682E9BC8F10E8DF2D1747E5149851E4275CD5CCC892A9FB072D0CF39C4A0
- mock_covariance: 1D67F91F65772D4037C8B8F2B0D486406B9A32C5F9774E3289C54FAE03F66579

Контракт: tools/pipeline/mock_relocation_contract.md.
setup_test_paths добавляет tools/matlab/ только в тестовую среду.
До переноса mock_position, mock_covariance, engine_isolation,
covariance_boundaries: 4/4 PASS (имена tests имеют префикс unit_test_).
Первый запуск после переноса FAILED: старый процесс не разрешал mock_position.
Сохранён runtime/pipeline/unit_test_mock_position_mockafter_20260930.
Собственный сервер tcp_targeted_restart перезапущен; новый лог
runtime/tcp_mock_restart_20260930.log, срок сервера 1800 секунд.
После перезапуска те же 4 проверки плюс unit_test_mock_relocation
и unit_test_production_isolation: 6/6 PASS.
Новый тест подтверждает отсутствие mock на production path, единственность
тестового разрешения и независимый диагональный геометрический репер со спектром.
Свидетельства: runtime/pipeline/*_mockbefore_20260930 и *_mockretry_20260930.
Граф: runtime/traceability/graph_mock_move.json.
Эталонная приёмка NOT_RUN; экспорт и коммит не выполнялись.

## Срез GN/GNP, 2026-09-30 (без коммита)

Из matlab/ в matlab/function/ перенесены четыре ядра без изменения байтов.
SHA-256 до/после:
- gn_position: 92768B59C5F1FE48BD33A3CDA46C65E7CD8989337BB836177E970D75215F92F5
- gn_covariance: 0384BF11CD0CEA972A8BEE7CE17FEEF9850A058898991510F88F276109CA468C
- gnp_position: E0BA3C38BFAFEDB3E03C709718BECF853F421CD1DEF5377260A3E093A9C7FA8C
- gnp_covariance: 3B8184300E780869A75F211DD39DE5B4376622776CF4745A3BD07E44263FFDB1

Контракт: tools/pipeline/gn_relocation_contract.md.
До/после: unit_test_gn_position, unit_test_gnp_position,
unit_test_covariance_boundaries, unit_test_integration_independence — PASS.
После дополнительно unit_test_gn_relocation и unit_test_production_isolation — PASS.
Новый тест проверяет разрешение на чистом пути, известную безошумную цель
и отказы короткой сети. Всего 4+6 запусков TCP.
Свидетельства: runtime/pipeline/*_gnbefore_20260930 и *_gnafter_20260930.
Граф: runtime/traceability/graph_gn_move.json.
Эталонная приёмка NOT_RUN. Математика и документы-представления не изменялись.

## Срез WLLS, 2026-09-30 (без коммита)

wlls_position.m и wlls_covariance.m перенесены из matlab/ в matlab/function/.
SHA-256 до/после совпадают соответственно:
7DE63E1E3D3E6076C540D9981DA527C0A061A7DAC943AF0121A27238E2EC4E24;
E8C1476957D62DB9917467BFB663F3016F5FB41F8830B7F60CB52CA107303342.
Контракт: tools/pipeline/wlls_relocation_contract.md.
До/после: unit_test_wlls_position, unit_test_covariance_boundaries,
unit_test_integration_independence — PASS. После дополнительно
unit_test_wlls_relocation (чистый путь, независимый геометрический репер,
короткая сеть) и unit_test_production_isolation — PASS. Всего 3+5 запусков TCP.
Свидетельства: runtime/pipeline/*_wllsbefore_20260930 и *_wllsafter_20260930.
Граф: runtime/traceability/graph_wlls_move.json.
Первый поиск потребителей через Git не выполнился из-за отсутствия less;
повторён успешно с --no-pager. Это не ошибка расчётных checks.
Эталонное сравнение остаётся NOT_RUN, приёмка миграции не объявлена.
WLLS_Polar_Focus не внедрялся; экспорт и коммит не выполнялись.

## Срез LLS, 2026-09-30 (без коммита)

lls_position.m и lls_covariance.m перенесены из matlab/ в matlab/function/ без изменения байтов.
SHA-256 соответственно:
E608E278E4D4578515C4FF7B9E9A78087EA5055C60850F9007A684BD3547E5EA;
ABC6B7AE4975A89DD5546FA8C1D4EE4E67C184C02DF385E234B29213C03DF54F.
Контракт: tools/pipeline/lls_relocation_contract.md.
TCP: до переноса unit_test_lls_position и unit_test_covariance_boundaries PASS;
после — те же, unit_test_lls_relocation, unit_test_wlls_position,
unit_test_gn_position, unit_test_gnp_position, unit_test_integration_independence,
unit_test_production_isolation: 8/8 PASS.
Свидетельства: runtime/pipeline/*_llsbefore_20260930 и *_llsafter_20260930.
Граф: runtime/traceability/graph_lls_move.json.
Сохранены также трёхаргументные вызовы LLS из GN/WLLS.
Визуальная приёмка pending; экспорт и коммит не выполнялись.

Одна тема объединяет переход паспортов на Markdown, перенос производственного
MATLAB-сервиса и тестового контура. Ниже — результаты конкретных коммитов,
не текущая спецификация размещения. Действующая архитектура задана .clinerules.
Открытые работы: [need_work.md](../need_work.md), задача 4.

## 1. Markdown-первоисточники

Индекс коммита: 56715fca42fee27d63261e530e96262675f1e5cb

**Задача:** начать миграцию по принятому тогда V-регламенту; копию репозитория
не изменять, математику сохранить. Прежний V-документ удалён из рабочего дерева;
историческое основание доступно в Git соответствующей ревизии.

**Результат:**
- Девять docs/*_theory.txt переименованы в docs/*_theory.md.
- Побайтовое сохранение содержимого проверено через SHA-256.
- Обновлены поиск паспортов в трансляторе, нормализаторе, MATLAB-валидаторе,
  регрессионных тестах и ссылка источника в отчёте mock.
- Старые имена внутри математических текстов намеренно не редактировались.
- Пользовательские регламенты, расчётные файлы и математические ядра не изменялись.

**Проверки:** 11 регрессионных тестов транслятора прошли; MATLAB-валидатор
после смены расширения в этом этапе не запускался. Исторический статус: PARTIAL.

## 2. Производственный MATLAB-сервис

Индекс коммита: 3bd4c84d4005dacf50ba62c2bfb1c13ac9be0021

**Задача:** продолжить размещение MATLAB-компонентов с изоляцией производства и испытаний.

**Результат:**
- service_expand_tact_matrix перенесён без изменения содержимого из matlabengine/
  в matlab/engine/.
- Обновлены тестовые пути, запуск mock-проверки и тест производственной изоляции.
- Тест зависимостей не разрешает произвольные подкаталоги matlab/.
- Математика, пользовательские регламенты и расчётные материалы не изменялись.

**Проверки:** MATLAB-проверка на этом этапе не выполнена. Исторический статус: PARTIAL.

## 3. Тестовый контур и точки входа

Индекс коммита: 4caa14437f6727fde96d73452a663da5be046ee7

**Задача:** продолжить миграцию тестового контура с сохранением изоляции производства.

**Результат:**
- matlabtests/ перенесён в matlab/tests/, включая support/ и экраны.
- Python-клиент и транспортный тест перенесены в tools/pipeline/.
- Исправлены вычисление корня, настройка путей и поиск тестов диспетчером.
- Публичные MATLAB-имена и вычислительные алгоритмы сохранены.
- Пользовательские регламенты и корневые расчётные материалы не перезаписывались.

**Проверки:** через MATLAB -batch прошли unit_test_context_configuration,
unit_test_pipeline, unit_test_engine_isolation и unit_test_production_isolation.
TCP:5555 не ответил; действующий сервер не перезапускался.
Исторический журнал: runtime/matlab_tests_layout.log; его текущая доступность
в этой задаче не подтверждалась. Документный шлюз, тяжёлые ансамбли и экспорт
не запускались. Исторический статус: PARTIAL.

## Граница темы

### Перенос tis_cov2std, 2026-09-30

Индекс коммита: изменения не закоммичены. Контракт:
tools/pipeline/cov2std_relocation_contract.md, MOVE-COV2STD-001–002.
matlab/tis_cov2std.m → matlab/function/tis_cov2std.m, SHA-256 сохранён:
5f1cbda0a9657b98a3f84a40f4e3d726eda68fc260f5a6e95d1a9ef2764130cd.
Через TCP прошли обе существующие проверки сечений до и после переноса,
новая проверка чистого production path и диагонального репера, production isolation.
Свидетельства runtime/pipeline/: unit_test_cov2std_before_move_20260930,
unit_test_cov2std_3d_before_move_20260930, unit_test_cov2std_covmove_20260930,
unit_test_cov2std_3d_covmove_20260930, unit_test_cov2std_relocation_covmove_20260930,
unit_test_production_isolation_covmove_20260930.
Известные математические замечания не закрыты переносом; сравнение с графиками
30km/450km и экспорт документов не выполнялись.

### Перенос FIFO, 2026-09-30

Индекс коммита: изменения не закоммичены. Контракт:
tools/pipeline/fifo_relocation_contract.md, MOVE-FIFO-001–002.
Четыре файла перенесены из matlab/ в matlab/function/ без изменения байтов:

| Файл | SHA-256 до и после |
|---|---|
| fifo_clear.m | a8c5911ba0d451de93d2ee4e29b62bbb4692b8b8505307786c9deea4153e795c |
| fifo_delete_at.m | 9957af625fab12c459251b2f2da98e558f7c12dc48dd9d21226943088cb57c56 |
| fifo_peek_recent.m | b723802c38723f4520be4e60cdc7fcc1c365ae4b1492326bce754f3f00ac9a17 |
| fifo_push.m | 7c5bd56ed9c5affe24e68116d16f64d4dbc2e0ad683fa19cd67f8c37a83bb0f9 |

Добавлена независимая регрессия по модели списка для допустимых int32-входов:
ёмкости 1/2/5, строки/столбцы, пустая очередь, переполнение, удаление и очистка.
До/после переноса PASS; проверка уникального production path и production isolation PASS.
Свидетельства runtime/pipeline/: fifo_before_move_20260930,
unit_test_fifo_fifo_move_20260930, unit_test_fifo_relocation_fifo_move_20260930,
unit_test_production_isolation_fifo_move_20260930.
Полный паспорт FIFO не найден; пробел зафиксирован в need_work.md.
Графики, экспорт и приёмка комплекса не выполнялись.

### Первый перенос ядра: matmul3, 2026-09-30

Индекс коммита: изменения не закоммичены. Контракт переноса:
tools/pipeline/matmul3_relocation_contract.md, MOVE-MATMUL3-001–002.
matlab/matmul3.m перенесён в matlab/function/matmul3.m без изменения байтов:
SHA-256 03b2e3c5fc67c2bb1e4a0511356e4000aa4cf2bf799f2f3d64f92661db91129a.
Обновлены явные тестовые пути и допустимое размещение производственных зависимостей.

Через TCP:5555 прошли unit_test_matmul3 до/после, новый тест уникального
разрешения функции на чистом производственном path, production/engine isolation.
Свидетельства в runtime/pipeline/: matmul3_before_move_20260930,
matmul3_path_after_20260930, unit_test_matmul3_move_20260930,
unit_test_production_isolation_move_20260930, unit_test_engine_isolation_move_20260930.
Остальные ядра не переносились. Визуальное эталонное сравнение не выполнено;
приёмка комплекса и завершение миграции не заявляются.

### Базовая проверка перед продолжением миграции, 2026-09-30

Индекс коммита: изменения не закоммичены. Восстановлен временный TCP:5555
на MATLAB R2025a. Задания environment и unit выполнены через TCP.
Свидетельства: runtime/pipeline/environment_recovery_20260930/report.json
и runtime/pipeline/unit_recovery_20260930/unit_results.json (19/19 PASS).
Это базовая проверка текущего размещения, не проверка ещё не выполненного переноса.
Эталонные графики не сопоставлялись; экспорт документов не выполнялся.

Коммиты подтверждают перечисленные этапы, а не завершение миграции.
Текущие незавершённые пункты и вопросы применимости старого плана ведутся
только в корневом need_work. Продолжение миграции дополняет этот файл,
а не создаёт новый файл для каждого коммита.
## Решение о каталогах MATLAB — исполнение 01.10.2026

Коммит: не создан. Контракт: matlab/tests/matlab_layout_contract.md.
- [x] .clinerules обновлён: engine — продукт, tests — испытательные контексты/реперы/метрики, tools/matlab — инфраструктура.
- [x] service_sample_bearings и service_add_noise_ox перенесены в engine; остальные шесть расчётных вспомогательных файлов из tools/matlab — в tests/support. SHA-256 всех восьми сохранены: runtime/matlab_layout_20261001.json.
- [x] tcpserver5555.m найден в корне и перенесён в tools/matlab; путь к корню исправлен, удалена остановка чужих переменных server/pipeline; используется постоянный host. Действующий сервер не перезапускался.
- [x] Восемь адресных TCP-тестов *_layout_090955…091120 PASS, включая изоляцию, синтетику, реперы, метрики и сценарий фильтра.
- [ ] Проверить новый startup на свободном/занятом порту изолированным тестом; текущий живой сервер не является проверкой нового входа.
- [ ] Завершить инвентаризацию всех старых ссылок/контрактов переноса: прежнее tools/matlab для метрик и синтетики больше не целевая архитектура.
- [ ] Завершить явный RNG-контекст физического движка; сохранённое глобальное rng в генераторе не объявляется изоляцией экземпляров.
Предыдущие пункты ENG-01/02 и ENV-01 читать с этим решением: реперы/метрики — tests/support; tcpserver5555 — tools/matlab, не matlab/. Общая приёмка и эталоны остаются открытыми.

## Аудит ссылок размещения — 01.10.2026
Коммит: не создан. Проверены matlab/tests, tools/pipeline, docs/guides и корневые очереди.
Исправлены текущие контракты sample/noise/metrics/mock/ideal и filter_scenario,
контракт test_model, инструкции PIPELINE/PRODUCTION_SERVICE_LAYOUT, пути в
CONTEXT_IMAGES, DOCUMENT_PROFILE_REPAIR, TRAJECTORY_CONFIGURATION,
UNIT_BOUNDARY_AUDIT, ENSEMBLE_VALIDATION, GRAPHICAL_EXPERIMENTS и matmul3_theory.
ENGINE_ISOLATION и TIS_VALIDATION_AUDIT обозначены историческими отчётами.
STATISTICAL_MAPPING больше не предписывает устаревший перезапуск.
Удалена лишняя инфраструктурная зависимость пути генератора filter2win.
Проверки TCP с --test-sha256 current, PID 28860:
unit_test_filter_plot_path_audit_094147 — PASS;
unit_test_production_isolation_audit_094208 — PASS;
unit_test_test_paths_audit_094229 — PASS.
Исторические runtime-свидетельства и тематические записи не переписывались.
- [ ] При выпуске актуализировать устаревшие пути в docs/guides/TRANSLATION.md
  и заново получить производные docs/liveeditor/*.m из Markdown. До прямой
  команды выпуска их правка/экспорт не выполняются.
Остаточные matlabtests в проверке изоляции — запрещённый шаблон, не зависимость.
Аудит не является проверкой всех динамически конструируемых путей или полной
приёмкой миграции, математики и эталонов 30/450 км.