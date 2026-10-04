# FIFO_DOUBLE — пары double, интерфейс схемы 2

## F2W-S2-03. Контракт

Чистое кольцо конечных пар время/значение. init принимает целую положительную
double capacity; state содержит capacity, head, count, last_time, time, value.
Массивы выделяются на capacity; активны только count элементов.

`[rc,q]=fifo_double('init',[],capacity)`;
`[rc,q]=fifo_double('push',q,time,value)`;
`[rc,q]=fifo_double('prune',q,cutoff)`;
`[rc,q,data]=fifo_double('read'|'peek'|'pop',q)`;
`[rc,q]=fifo_double('clear',q)`.

push требует строго возрастающего времени; переполнение вытесняет старейшую
пару. read возвращает data.time/data.value в хронологическом порядке.
peek читает старейшую пару; pop дополнительно удаляет её. Пустое чтение
успешно и возвращает пустые массивы. prune удаляет только время < cutoff.
prune/pop сохраняют last_time; clear обнуляет память и начинает новую
временную последовательность с last_time=-Inf. NaN/Inf и недопустимое состояние
отвергаются. rc=1 не изменяет q; rc=0 означает успех.

Это замена прежнего fifo_double вместе с filter2win, не замена индексных
int32 FIFO. Старый порядок аргументов push(value,time), get и четыре выхода
не поддерживаются. Производственный потребитель — filter2win и его helpers.
Проверка — matlab/tests/unit_test_fifo_double.m, данные —
matlab/tests/configs/fifo_double_cases.json, запуск — fifo_double_runner.json.
Проверяются независимый порядок, точность дробных значений, вытеснение,
граница prune и атомарность отказа. Исполнение MATLAB NOT_RUN из-за :5555.
read и валидация могут выделять временные массивы; Zero-Allocation не заявлен.