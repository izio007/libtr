function [status, std_X, std_Y, std_Z] = gn3d_covariance_cartesian(P, var_alpha, var_beta, lambda_gn)
% =========================================================================
% УСТОЙЧИВАЯ SVD-ФУНКЦИЯ РАСЧЕТА СКО ДЛЯ МЕТОДА GAUSS-NEWTON
% =========================================================================
% Входные параметры:
%   P                - Физическая матрица координат измерительных пунктов [3 x M]
%   var_alpha        - Вектор дисперсий шума азимутальных каналов [M x 1] (радианы^2)
%   var_beta         - Вектор дисперсий шума угломестных каналов [M x 1] (радианы^2)
%   lambda_estimated - Оцененные координаты цели от gn3d_position [x; y; z]
% Output:
%   status           - Флаг выполнения (0 - успешно, >0 - ошибка)
%   std_X, std_Y, Z  - Изолированные СКО по осям (в метрах)
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
    if rho < 1e-3, rho = 1e-3; end
    
    alpha_theo = atan2(dy, dx); 
    beta_theo  = atan2(dz, rho_xy);
    
    sa = sin(alpha_theo); ca = cos(alpha_theo);
    sb = sin(beta_theo);  cb = cos(beta_theo);
    
    % Истинные аналитические производные без каких-либо масштабирующих замен
    J(2*i-1, 1) = -sa / rho_xy; J(2*i-1, 2) =  ca / rho_xy; J(2*i-1, 3) =  0;
    J(2*i, 1) = -ca * sb / rho; J(2*i, 2) = -sa * sb / rho; J(2*i, 3) =  cb / rho;
    
    W_noise(2*i-1) = 1.0 / var_alpha(i);
    W_noise(2*i)   = 1.0 / var_beta(i);
end

% Информационная матрица Фишера задачи Гаусса-Ньютона
AtWA = J.' * diag(W_noise) * J;

if rcond(AtWA) < 1e-12
    status = 2; return;
end

K_lambda = inv(AtWA);

std_X = sqrt(K_lambda(1, 1));
std_Y = sqrt(K_lambda(2, 2));
std_Z = sqrt(K_lambda(3, 3));
status = 0;
end
