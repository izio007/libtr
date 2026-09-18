function [status, count, stack_data] = stack_push(cfg, count, capacity, stack_data, value)
% STACK_PUSH Инкремент индекса вершины и запись значения в массив данных стека
% Входные параметры:
%   cfg        - Структура глобальных инвариантов и кодов завершения
%   count      - Текущий индекс вершины стека
%   capacity   - Предельная емкость массива хранения
%   stack_data - Массив данных стека (тип int32)
%   value      - Записываемое значение (тип int32)

    if count >= int32(capacity)
        status = cfg.STATUS_ERR_OVERFLOW;
        return;
    end

    count = count + int32(1);
    stack_data(count) = int32(value);
    status = cfg.STATUS_SUCCESS;
end
