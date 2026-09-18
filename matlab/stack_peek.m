function [status, value] = stack_peek(cfg, count, stack_data)
% STACK_PEEK Чтение текущего значения на вершине стека без изменения индекса
% Входные параметры:
%   cfg        - Структура global-инвариантов и кодов завершения
%   count      - Текущий индекс вершины стека
%   stack_data - Массив данных стека (тип int32)

    if count <= int32(0)
        status = cfg.STATUS_ERR_UNDERFLOW;
        value = int32(-1);
        return;
    end

    value = stack_data(count);
    status = cfg.STATUS_SUCCESS;
end
