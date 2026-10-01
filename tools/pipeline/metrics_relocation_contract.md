# Перенос испытательных метрик

Задача 4 need_work.md; .clinerules: метрики испытаний в matlab/tests/support/.
service_ensemble_metrics и service_cumulative_rmse переносятся из
matlab/tests/support/ без изменения байтов и определений статистик.

@CRITERION METRICS-MOVE-001: SHA-256 сохраняется, старые файлы отсутствуют;
функции недоступны на чистом production path, однозначно доступны из matlab/tests/support/.
@CRITERION METRICS-MOVE-002: unit_test_ensemble_metrics,
unit_test_graphical_experiments, unit_test_integration_independence проходят до/после.
@CRITERION METRICS-MOVE-003: точки [0;0;0] и [3;4;0] при нулевой истине
дают bias=[1.5;2;0], RMSE=sqrt(12.5), ковариацию [4.5 6 0;6 8 0;0 0 0].
Добавленный отказ не изменяет условные моменты, но даёт долю отказов 1/3.
Начальный и промежуточный отказы не становятся нулевыми ошибками в prefix RMSE.

Это проверка переноса и выбранных инвариантов, не полная область допустимых
входов и не сравнение эталонных графиков 30/450 км.
Исторические результаты относятся к прежним байтам контрактов; изменение целевого пути не переаттестовывает их. Текущая архитектура — .clinerules.
