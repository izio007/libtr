function [status, D] = matmul3(A, B, C)
% MATMUL3 Произведение трех вещественных матриц double: D = (A*B)*C.
%   [status, D] = matmul3(A, B, C)
%   A: [m x n], B: [n x p], C: [p x q]; D: [m x q].
%   Допустимы только полные двумерные массивы класса double.
%   Размеры произвольны в пределах памяти MATLAB, включая нулевые.
%   Скалярного расширения и автоматического преобразования типов нет.
%   status = 0: успех; 1: неверный тип или размер, D = NaN (скаляр);
%   2: NaN/Inf во входах или результатах, D = NaN(m,q).
%   При пустом D признаком отказа служит status, а не элементы D.
%   Проверка конечности входов предшествует обработке пустых размеров.
%   Вырожденные матрицы допустимы; обратимость не требуется.
%   Нулевые размеры дают zeros(m,q) при конечных входах.
%   Потеря точности и исчезновение малых величин не диагностируются.
%   Ошибки выделения памяти и неверное число аргументов не перехватываются.
%   Входы и глобальное состояние не изменяются; ввод-вывод отсутствует.
%   Порядок скобок фиксирован, побитовая переносимость не гарантируется.

status = 1;
D = NaN;
if ~isa(A, 'double') || ~isa(B, 'double') || ...
        ~isa(C, 'double') || ~isreal(A) || ~isreal(B) || ...
        ~isreal(C) || issparse(A) || issparse(B) || issparse(C) || ...
        ~ismatrix(A) || ~ismatrix(B) || ~ismatrix(C)
    return;
end

[m, n] = size(A);
[p, q] = size(C);
if size(B, 1) ~= n || size(B, 2) ~= p
    return;
end

status = 2;
D = NaN(m, q);
if any(isnan(A(:)) | isinf(A(:))) || ...
        any(isnan(B(:)) | isinf(B(:))) || ...
        any(isnan(C(:)) | isinf(C(:)))
    return;
end

if m == 0 || n == 0 || p == 0 || q == 0
    D = zeros(m, q);
    status = 0;
    return;
end

T = A * B;
if any(isnan(T(:)) | isinf(T(:)))
    return;
end
D = T * C;
if any(isnan(D(:)) | isinf(D(:)))
    D = NaN(m, q);
    return;
end
status = 0;
end