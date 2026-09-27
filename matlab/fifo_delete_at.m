function [count, queue_data] = fifo_delete_at(count, queue_data, delete_idx)
% FIFO_DELETE_AT Удаление элемента по заданному индексу с хронологическим сдвигом памяти
% Входные параметры:
%   count      - Текущее количество элементов в очереди
%   queue_data - Массив данных очереди (тип int32)
%   delete_idx - Индекс удаляемого элемента (тип int32)

    if delete_idx >= int32(1) && delete_idx <= count
        for i = delete_idx:(count - int32(1))
            queue_data(i) = queue_data(i + int32(1));
        end
        queue_data(count) = int32(0);
        count = count - int32(1);
    end
end
