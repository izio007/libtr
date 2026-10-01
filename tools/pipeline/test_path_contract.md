# Тестовая композиция после миграции

Задача 4 need_work.md; .clinerules разделяет ядра, движок, реперы и тесты.
setup_test_paths не добавляет корень matlab/ с производными паспортами.
Функция не удаляет пути вызывающего пользователя: проверка начинается с чистого пути.

@CRITERION TEST-PATH-001: после restoredefaultpath и setup_test_paths корень
matlab/ отсутствует в path; все ядра, движок и реперы разрешаются однозначно
из назначенных каталогов; повторная настройка не меняет path.
@CRITERION TEST-PATH-002: на этой композиции проходят unit_test_engine_isolation,
unit_test_integration_independence, unit_test_ensemble_metrics,
unit_test_graphical_experiments. Экспорт документов не запускается.

Это адресная регрессия, не полная приёмка всех сценариев и эталонных графиков.