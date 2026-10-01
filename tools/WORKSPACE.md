# Рабочие операции агента

`workspace.py` — короткий CLI для обзора и фиксации выбранных текстовых файлов.
Запуск из корня проекта через Cygwin Python:

```sh
python3 tools/workspace.py tree --depth 2
python3 tools/workspace.py status
python3 tools/workspace.py check .clinerules
python3 tools/workspace.py commit .clinerules --task "Update rules" --status PASS
```

Критерии: UTF-8 и diff --check до коммита; только явно выбранные файлы;
непустой индекс блокирует коммит; literal pathspec исключает раскрытие шаблонов;
runtime, .git и выход за корень запрещены. Коммит только через Cygwin.
PASS передаётся исполнителем по фактическим проверкам, не вычисляется по
наличию коммита. Утилита не запускает MATLAB, не делает push и не заменяет runner.sh.
При ошибке Git после staging индекс сохраняется для разбора, автоматического отката нет.

Проверки инфраструктуры: tools/test_workspace.py — временные репозитории,
изоляция коммита, защита индекса, пути, кодировка и специальные имена файлов.