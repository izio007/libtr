function [count, queue_data] = fifo_clear(capacity, queue_data)
% FIFO_CLEAR Заполнение массива данных очереди нулевыми значениями
% Входные параметры:
%   capacity   - Предельная емкость массива хранения
%   queue_data - Массив данных очереди (тип int32)

    count = int32(0);
    for k = int32(1):int32(capacity)
        queue_data(k) = int32(0);
    end
end
