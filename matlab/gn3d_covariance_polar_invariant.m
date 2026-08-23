function [status, std_X, std_Y, std_Z] = gn3d_covariance_polar_invariant(P, var_alpha, var_beta, lambda_gn)
% =========================================================================
% ФУНКЦИЯ РАСЧЕТА ИСТИННОГО ПОЛЯРНОГО ИНВАРИАНТА МАТРИЦЫ ФИШЕРА ДЛЯ GN
% Входные параметры:
%   P          - Физическая матрица координат измерительных пунктов [3 x M]
%   var_alpha  - Вектор дисперсий шума азимутальных каналов [M x 1] (рад^2)
%   var_beta   - Вектор дисперсий шума угломестных каналов [M x 1] (рад^2)
%   lambda_gn  - Вектор текущих зашумленных декартовых координат цели [3 x 1] (м)
% Выходные параметры:
%   status     - Флаг выполнения (0 - успешно, 1 - сбой размерности, 2 - вырождение)
%   std_Along  - СКО продольного промаха по дальности вдоль луча визирования (м)
%   std_Cross  - СКО поперечного бокового ухода (м)
%   std_Z      - СКО высоты (м)
% =========================================================================
std_X = NaN; std_Y = NaN; std_Z = NaN;
M = size(P, 2);

J = zeros(2*M, 3);
W = zeros(2*M, 1);

x = lambda_gn(1); y = lambda_gn(2); z = lambda_gn(3);

for i = 1:M
    xs = P(1, i); ys = P(2, i); zs = P(3, i);
    dx = x - xs; dy = y - ys; dz = z - zs;
    
    r_xy = sqrt(dx^2 + dy^2);
    r_sq = dx^2 + dy^2 + dz^2;
    
    if r_xy < 1e-3, r_xy = 1e-3; end
    
    % Полные тригонометрические градиенты полярного базиса ТИС от оси OX
    J(2*i-1, 1) = -dy / (r_xy^2);
    J(2*i-1, 2) =  dx / (r_xy^2);
    J(2*i-1, 3) =  0;
    
    J(2*i, 1)   = -(dx * dz) / (r_sq * r_xy);
    J(2*i, 2)   = -(dy * dz) / (r_sq * r_xy);
    J(2*i, 3)   =  r_xy / r_sq;
    
    W(2*i-1) = 1.0 / var_alpha(i);
    W(2*i)   = 1.0 / var_beta(i);
end

I_Fisher = J.' * diag(W) * J;

if rcond(I_Fisher) < 2.2204e-16 || isnan(rcond(I_Fisher))
    status = 2; return;
end

K_cartesian = inv(I_Fisher);
std_X = sqrt(K_cartesian(1, 1));
std_Y = sqrt(K_cartesian(2, 2));
std_Z = sqrt(K_cartesian(3, 3));
status = 0;
end