function [is_valid, value] = fifo_peek_recent(count, queue_data)
% FIFO_PEEK_RECENT Чтение наиболее позднего по времени элемента без модификации очереди
% Входные параметры:
%   count      - Текущее количество элементов в очереди
%   queue_data - Массив данных очереди (тип int32)

    if count <= int32(0)
        is_valid = false;
        value = int32(-1);
        return;
    end
    
    is_valid = true;
    value = queue_data(count);
end
