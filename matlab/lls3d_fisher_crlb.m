function [status, crlb_X, crlb_Y, crlb_Z] = lls3d_fisher_crlb(P, var_alpha, var_beta, X_target, Y_target, Z_target)
% Вычисление теоретического предела точности (Границы Рао-Крамера)
% строго по физической геометрии измерительных пунктов P
crlb_X = 0; crlb_Y = 0; crlb_Z = 0;
M = size(P, 2);

J = zeros(2*M, 3);
W_noise = zeros(2*M, 1);

for i = 1:M
    % Берем ИСТИННЫЕ, прыгающие по сплайну координаты станций
    xs = P(1, i); ys = P(2, i); zs = P(3, i);
    
    dx = X_target - xs; 
    dy = Y_target - ys; 
    dz = Z_target - zs;
    
    rho_xy = sqrt(dx^2 + dy^2); 
    rho = sqrt(dx^2 + dy^2 + dz^2);
    
    if rho_xy < 1e-3, rho_xy = 1e-3; end
    if rho < 1e-3, rho = 1e-3; end
    
    % Истинные аналитические производные нелинейной геометрии (Якобиан)
    alpha_theo = atan2(dy, dx); 
    beta_theo  = atan2(dz, rho_xy);
    
    sa = sin(alpha_theo); ca = cos(alpha_theo);
    sb = sin(beta_theo);  cb = cos(beta_theo);
    
    % Строка азимута (радианы/метр)
    J(2*i-1, 1) = -sa / rho_xy; 
    J(2*i-1, 2) =  ca / rho_xy; 
    J(2*i-1, 3) =  0;
    
    % Строка угла места (радианы/метр)
    J(2*i, 1) = -ca * sb / rho; 
    J(2*i, 2) = -sa * sb / rho; 
    J(2*i, 3) =  cb / rho;
    
    W_noise(2*i-1) = 1.0 / var_alpha(i);
    W_noise(2*i)   = 1.0 / var_beta(i);
end

% Информационная матрица Фишера (Fisher Information Matrix)
I_Fisher = J.' * diag(W_noise) * J;

if rcond(I_Fisher) < 1e-12
    status = 1; return;
end

% Матрица Рао-Крамера (ковариация теоретического предела)
K_CRLB = inv(I_Fisher);

% Извлекаем чистые теоретические СКО по осям (в метрах)
crlb_X = sqrt(K_CRLB(1, 1));
crlb_Y = sqrt(K_CRLB(2, 2));
crlb_Z = sqrt(K_CRLB(3, 3));
status = 0;
end