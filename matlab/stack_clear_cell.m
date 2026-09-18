function stack_data = stack_clear_cell(stack_data, cell_idx)
% STACK_CLEAR_CELL Запись нулевого значения в заданную ячейку массива данных стека
% Входные параметры:
%   stack_data - Массив данных стека (тип int32)
%   cell_idx   - Индекс очищаемой ячейки (тип int32)

    stack_data(cell_idx) = int32(0);
end
