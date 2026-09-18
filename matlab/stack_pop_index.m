function [status, count] = stack_pop_index(cfg, count)
% STACK_POP_INDEX Декремент индекса вершины стека LIFO без возврата значения
% Входные параметры:
%   cfg        - Структура глобальных инвариантов и кодов завершения
%   count      - Текущий индекс вершины стека

    if count <= int32(0)
        status = cfg.STATUS_ERR_UNDERFLOW;
        return;
    end

    count = count - int32(1);
    status = cfg.STATUS_SUCCESS;
end
