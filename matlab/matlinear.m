function [out] = matlinear()
% =========================================================================
% БИБЛИОТЕКА НИЗКОУРОВНЕВОЙ СТАТИЧЕСКОЙ ЛИНЕЙНОЙ АЛГЕБРЫ 3х3 (ПРОТОТИП СИ)
% =========================================================================
% Возвращает структуру указателей на локальные вычислительные ядра.
% Все массивы и векторы имеют строго фиксированный размер 3х3 или 3х1.
% =========================================================================
    out.cholesky       = @mat3x3_cholesky;
    out.solve_forward  = @mat3x3_solve_forward;
    out.solve_backward = @mat3x3_solve_backward;
    out.solve_system   = @mat3x3_solve_system;
    out.inverse        = @mat3x3_inverse;
end

function [status, L] = mat3x3_cholesky(A)
    % Разложение Холецкого A = L * L' для симметричных матриц 3х3
    % status: 0 - успешно, 1 - матрица не положительно определена
    L = zeros(3,3);
    eps_val = 1e-12;
    
    for i = 1:3
        for j = 1:i
            sum_val = 0;
            for k = 1:(j-1)
                sum_val = sum_val + L(i,k) * L(j,k);
            end
            
            if i == j
                diff_val = A(i,i) - sum_val;
                if diff_val <= eps_val || isnan(diff_val) || isinf(diff_val)
                    status = 1; return; % Нарушение знакоопределенности
                end
                L(i,i) = sqrt(diff_val);
            else
                if abs(L(j,j)) < eps_val
                    status = 1; return;
                end
                L(i,j) = (A(i,j) - sum_val) / L(j,j);
            end
        end
    end
    status = 0;
end

function [status, y] = mat3x3_solve_forward(L, b)
    % Прямая подстановка L * y = b (решение нижней треугольной системы)
    y = zeros(3,1);
    eps_val = 1e-12;
    
    for i = 1:3
        sum_val = 0;
        for k = 1:(i-1)
            sum_val = sum_val + L(i,k) * y(k);
        end
        if abs(L(i,i)) < eps_val
            status = 1; return;
        end
        y(i) = (b(i) - sum_val) / L(i,i);
    end
    status = 0;
end

function [status, x] = mat3x3_solve_backward(L, y)
    % Обратная подстановка L' * x = y (решение верхней треугольной системы)
    x = zeros(3,1);
    eps_val = 1e-12;
    
    for i = 3:-1:1
        sum_val = 0;
        for k = (i+1):3
            sum_val = sum_val + L(k,i) * x(k); % Транспонированная L
        end
        if abs(L(i,i)) < eps_val
            status = 1; return;
        end
        x(i) = (y(i) - sum_val) / L(i,i);
    end
    status = 0;
end

function [status, x] = mat3x3_solve_system(AtA, Atb)
    % Полное решение нормальной системы МНК: (AtA) * x = Atb
    x = zeros(3,1);
    
    [st_chol, L] = mat3x3_cholesky(AtA);
    if st_chol ~= 0, status = 1; return; end
    
    [st_fwd, y] = mat3x3_solve_forward(L, Atb);
    if st_fwd ~= 0, status = 2; return; end
    
    [st_bwd, x] = mat3x3_solve_backward(L, y);
    if st_bwd ~= 0, status = 3; return; end
    
    if any(isnan(x)) || any(isinf(x))
        status = 4; return;
    end
    status = 0;
end

function [status, A_inv] = mat3x3_inverse(A)
    % Поколоночное инвертирование матрицы 3х3 через Холецкого
    A_inv = zeros(3,3);
    I = eye(3);
    
    [st_chol, L] = mat3x3_cholesky(A);
    if st_chol ~= 0, status = 1; return; end
    
    for col = 1:3
        [st_fwd, y] = mat3x3_solve_forward(L, I(:, col));
        if st_fwd ~= 0, status = 2; return; end
        
        [st_bwd, x] = mat3x3_solve_backward(L, y);
        if st_bwd ~= 0, status = 3; return; end
        
        A_inv(:, col) = x;
    end
    status = 0;
end
