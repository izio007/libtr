function [count, queue_data] = fifo_push(count, capacity, queue_data, value)
% FIFO_PUSH Добавление элемента в хвост очереди с вытеснением старых данных при переполнении
% Входные параметры:
%   count      - Текущее количество элементов в очереди
%   capacity   - Предельная емкость массива хранения
%   queue_data - Массив данных очереди (тип int32)
%   value      - Записываемое значение (тип int32)

    if count < int32(capacity)
        count = count + int32(1);
        queue_data(count) = int32(value);
    else
        for i = int32(1):(int32(capacity) - int32(1))
            queue_data(i) = queue_data(i + int32(1));
        end
        queue_data(capacity) = int32(value);
    end
end
