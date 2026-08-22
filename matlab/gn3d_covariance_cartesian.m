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

if M < 2 || length(lambda_gn) ~= 3
    status = 1; return;
end

x = lambda_gn(1); y = lambda_gn(2); z = lambda_gn(3);
J = zeros(2*M, 3);
W_noise = zeros(2*M, 1);

for i = 1:M
    dx = x - P(1, i); dy = y - P(2, i); dz = z - P(3, i);
    rho_xy = sqrt(dx^2 + dy^2); rho = sqrt(dx^2 + dy^2 + dz^2);
    
    if rho_xy < 1e-3, rho_xy = 1e-3; end
    if rho < 1e-3,    rho = 1e-3; end
    
    % Истинные аналитические ракурсы визирования от оси OX в прыгающей точке
    alpha_theo = atan2(dy, dx); 
    beta_theo  = atan2(dz, rho_xy);
    
    sa = sin(alpha_theo); ca = cos(alpha_theo);
    sb = sin(beta_theo);  cb = cos(beta_theo);
    
    % Чистый Якобиан из учебника (Размерность: радиан на метр)
    J(2*i-1, 1) = -sa / rho_xy; 
    J(2*i-1, 2) =  ca / rho_xy; 
    J(2*i-1, 3) =  0;
    
    J(2*i, 1)   = -ca * sb / rho; 
    J(2*i, 2)   = -sa * sb / rho; 
    J(2*i, 3)   =  cb / rho;
    
    % Чистая весовая матрица обратных угловых дисперсий (Размерность: 1 / радиан^2)
    W_noise(2*i-1) = 1.0 / var_alpha(i);
    W_noise(2*i)   = 1.0 / var_beta(i);
end

% Прямой расчет информационной матрицы Фишера задачи Гаусса-Ньютона
AtWA = J.' * diag(W_noise) * J;

% Чистая аналитическая инверсия оператором inv. Если rcond падает - фиксируем честный отказ.
if rcond(AtWA) < 2.2204e-16 || isnan(rcond(AtWA))
    status = 2; return;
end

K_lambda = inv(AtWA);

std_X = sqrt(K_lambda(1, 1));
std_Y = sqrt(K_lambda(2, 2));
std_Z = sqrt(K_lambda(3, 3));
status = 0;
end
