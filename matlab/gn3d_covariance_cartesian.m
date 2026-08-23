function [status, std_X, std_Y, std_Z] = gn3d_covariance_cartesian(P, var_alpha, var_beta, lambda_gn)
% =========================================================================
% КЛАССИЧЕСКАЯ ДЕКАРТОВА КОВАРИАЦИЯ GAUSS-NEWTON (ЧИСТАЯ МАТРИЦА ФИШЕРА)
% Входные параметры:
%   P         - Физическая матрица координат измерительных пунктов [3 x M]
%   var_alpha - Вектор дисперсий шума азимутальных каналов [M x 1] (рад^2)
%   var_beta  - Вектор дисперсий шума угломестных каналов [M x 1] (рад^2)
%   lambda_gn - Вектор текущих зашумленных декартовых координат цели [3 x 1] (м)
% Выходные параметры:
%   status    - Флаг выполнения (0 - успешно, 1 - сбой размерности, 2 - вырождение)
%   std_X,Y,Z - СКО погрешностей, спроецированные на декартовы оси сетки ПВО (м)
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
    r = sqrt(r_sq);
    
    if r_xy < 1e-3, r_xy = 1e-3; end
    if r < 1e-3,    r = 1e-3; end
    
    % 1. Строка азимута alpha
    J(2*i-1, 1) = -dy / (r_xy^2);
    J(2*i-1, 2) =  dx / (r_xy^2);
    J(2*i-1, 3) =  0;
    
    % 2. Строка угла места beta - ВОССТАНОВЛЕНА ПОЛНАЯ НЕЛИНЕЙНАЯ СВЯЗЬ Z
    J(2*i, 1)   = -(dx * dz) / (r_sq * r_xy);
    J(2*i, 2)   = -(dy * dz) / (r_sq * r_xy);
    J(2*i, 3)   =  r_xy / r_sq;
    
    W(2*i-1) = 1.0 / var_alpha(i);
    W(2*i)   = 1.0 / var_beta(i);
end

AtWA = J.' * diag(W) * J;

if rcond(AtWA) < 2.2204e-16 || isnan(rcond(AtWA))
    status = 2; return;
end

K = inv(AtWA);
std_X = sqrt(K(1, 1));
std_Y = sqrt(K(2, 2));
std_Z = sqrt(K(3, 3));
status = 0;
end
