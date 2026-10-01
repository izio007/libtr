# Адресный unit-запуск через TCP

Основание: need_work.md, настройка адресных проверок без экспорта документов.
Запрос action=unit может содержать test: имя существующего unit_test_*.m
без расширения. Отсутствие test сохраняет прежний общий unit-профиль.
Адресный режим не запускает environment и посторонние unit-тесты.

- @CRITERION TCP-UNIT-001: разрешено только имя unit_test_[A-Za-z0-9_]+,
  существующее непосредственно в matlab/tests; пути и неизвестные имена отклоняются.
- @CRITERION TCP-UNIT-002: test допустим только для unit; повтор id с другим
  test отклоняется как конфликт, одинаковый запрос остаётся идемпотентным.
- @CRITERION TCP-UNIT-003: адресный отчёт содержит ровно один запрошенный тест;
  ошибка проверки даёт failed; отсутствие test сохраняет прежнее поведение.

CLI: pipeline_client.py unit --test unit_test_matmul3 --id UNIQUE.
Проверки: unit_test_pipeline, unit_test_pipeline_selection и живой TCP-протокол.