function stack_data = stack_shift_down(count, stack_data, delete_idx)
% STACK_SHIFT_DOWN Поэлементный сдвиг ячеек массива памяти вниз от заданной позиции
% Входные параметры:
%   count      - Текущий индекс вершины стека
%   stack_data - Массив данных стека (тип int32)
%   delete_idx - Начальный индекс сдвига (тип int32)

    for i = delete_idx:(count - int32(1))
        stack_data(i) = stack_data(i + int32(1));
    end
    stack_data(count) = int32(0);
end
