function [status, lambda] = gn3d_position(P, alpha, beta)
% =========================================================================
% ФУНКЦИЯ НЕЛИНЕЙНОГО 3D-ПОЗИЦИОНИРОВАНИЯ (LLS + 1 ШАГ GAUSS-NEWTON)
% =========================================================================
% Входные параметры:
%   P     - Физическая матрица координат измерительных пунктов [3 x M]
%   alpha - Вектор измеренных азимутов цели [M x 1] (радианы)
%   beta  - Вектор измеренных углов места цели [M x 1] (радианы)
% Выходные параметры:
%   status - Флаг выполнения (0 - успешно, 1 - сбой LLS, 2 - сбой GN)
%   lambda - Финальный вектор оцененных координат цели [x; y; z] (метры)
% =========================================================================

% НЕЛИНЕЙНОЕ ПОЗИЦИОНИРОВАНИЕ (1 ШАГ GAUSS-NEWTON С ПЕРЕИСПОЛЬЗОВАНИЕМ LLS)
lambda = [0; 0; 0];
M = size(P, 2);

% Явное переиспользование базового линейного МНК для получения начальной точки
[st_lls, lambda_lls] = lls3d_position(P, alpha, beta);
if st_lls ~= 0
    status = 1; return;
end

x = lambda_lls(1); y = lambda_lls(2); z = lambda_lls(3);
J = zeros(2*M, 3);
delta_Y = zeros(2*M, 1);

for i = 1:M
    dx = x - P(1, i); dy = y - P(2, i); dz = z - P(3, i);
    rho_xy = sqrt(dx^2 + dy^2); rho = sqrt(dx^2 + dy^2 + dz^2);
    if rho_xy < 1e-3, rho_xy = 1e-3; end
    if rho < 1e-3, rho = 1e-3; end
    
    alpha_theo = atan2(dy, dx); 
    beta_theo  = atan2(dz, rho_xy);
    
    % Чистые тригонометрические невязки углов в радианах
    d_alpha = alpha(i) - alpha_theo;
    d_alpha = atan2(sin(d_alpha), cos(d_alpha));
    d_beta  = beta(i) - beta_theo;
    
    delta_Y(2*i-1) = d_alpha;
    delta_Y(2*i)   = d_beta;
    
    sa = sin(alpha_theo); ca = cos(alpha_theo);
    sb = sin(beta_theo);  cb = cos(beta_theo);
    
    % Истинный аналитический нелинейный Якобиан из учебника
    J(2*i-1, 1) = -sa / rho_xy; J(2*i-1, 2) =  ca / rho_xy; J(2*i-1, 3) =  0;
    J(2*i, 1) = -ca * sb / rho; J(2*i, 2) = -sa * sb / rho; J(2*i, 3) =  cb / rho;
end

JtJ = J.' * J;
if rcond(JtJ) < 1e-12
    status = 2; return;
end

% Нахождение нелинейной поправки Гаусса-Ньютона
lambda = lambda_lls + (JtJ \ (J.' * delta_Y));
status = 0;
end

