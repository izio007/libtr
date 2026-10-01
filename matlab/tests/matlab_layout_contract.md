# Продуктовая физика и испытательная среда

Основание: решение Шефа 01.10.2026. Физические генераторы
service_sample_bearings и service_add_noise_ox — matlab/engine.
Их параметры передаются вызывающим кодом; сценарии и метрики — tests/support.
mock_position/covariance и идеальный адаптер остаются испытательными реперами.
tcpserver5555 — tools/matlab, инфраструктурный вход постоянного host.

@CRITERION MATLAB-LAYOUT-001: перенесённые расчётные файлы сохраняют SHA-256;
production dependency closure не включает tests или tools. RNG допустим
в стохастической модели engine, но не в чистых function; его контракт
и изоляция контекстов требуют отдельной работы, не маскируются переносом.
@CRITERION MATLAB-LAYOUT-002: unit_test_test_paths, unit_test_production_isolation,
unit_test_graphical_experiments и unit_test_filter_engine_scenario проходят через TCP.
@CRITERION MATLAB-LAYOUT-003: инфраструктурный вход не останавливает чужой или
существующий сервер; занятый порт вызывает отказ, свободный запускает host.
Обычный расчёт не требует запуска инфраструктурного входа повторно.