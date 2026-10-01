# Перенос имитационных операторов mock

Основание: .clinerules (реперы в matlab/tests/support/), docs/mock_theory.md,
задача 4 need_work.md. Перенести mock_position и mock_covariance из matlab/
в matlab/tests/support/ без изменения байтов. Изменить только тестовую композицию путей.

@CRITERION MOVE-MOCK-001: SHA-256 сохраняется, старые файлы отсутствуют.
Производственный путь matlab/, matlab/function/, matlab/engine/ не разрешает mock.
После добавления matlab/tests/support/ обе функции разрешаются однозначно.
@CRITERION MOVE-MOCK-002: unit_test_mock_position, unit_test_mock_covariance,
unit_test_engine_isolation, unit_test_covariance_boundaries проходят до/после;
unit_test_production_isolation проходит после.
@CRITERION MOVE-MOCK-003: четыре поста на единичной окружности, цель в центре,
единичные угловые дисперсии: позиция 0, K=diag(1/2,1/2,1/4),
V*S*V'=K и V'*V=I с абсолютным допуском 1e-12.
Знаки и базис кратных собственных значений не фиксируются.

Не меняются формулы или эталоны; перенос не доказывает независимость алгоритма
mock_position от LLS и не заменяет визуальную приёмку 30/450 км.
Исторические результаты относятся к прежним байтам контрактов; изменение целевого пути не переаттестовывает их. Текущая архитектура — .clinerules.
