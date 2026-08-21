function [status, std_X, std_Y, std_Z] = gn3d_covariance(P, var_alpha, var_beta, lambda_estimated)
std_X = 0; std_Y = 0; std_Z = 0;
M = size(P, 2);

x = lambda_estimated(1); y = lambda_estimated(2); z = lambda_estimated(3);
y_base_line = mean(P(2, :)); % Стабилизируем базу от S-колебаний

J = zeros(2*M, 3);
W_noise = zeros(2*M, 1);

for i = 1:M
    dx = x - P(1, i); 
    dy = y - y_base_line; 
    dz = z - 0; % Относительно базовой плоскости станций
    
    rho_xy = sqrt(dx^2 + dy^2); rho = sqrt(dx^2 + dy^2 + dz^2);
    if rho_xy < 1e-3, rho_xy = 1e-3; end
    if rho < 1e-3, rho = 1e-3; end
    
    alpha_theo = atan2(dy, dx); beta_theo  = atan2(dz, rho_xy);
    sa = sin(alpha_theo); ca = cos(alpha_theo);
    sb = sin(beta_theo);  cb = cos(beta_theo);
    
    J(2*i-1, 1) = -sa / rho_xy; J(2*i-1, 2) =  ca / rho_xy; J(2*i-1, 3) =  0;
    J(2*i, 1) = -ca * sb / rho; J(2*i, 2) = -sa * sb / rho; J(2*i, 3) =  cb / rho;
    
    W_noise(2*i-1) = 1.0 / var_alpha(i);
    W_noise(2*i)   = 1.0 / var_beta(i);
end

AtWA = J.' * diag(W_noise) * J;

[U, S, V] = svd(AtWA);
sing_vals = diag(S);
tol = max(size(AtWA)) * eps(max(sing_vals));
if tol < 1e-6, tol = 1e-6; end

S_inv = zeros(3, 3);
for i = 1:3
    if sing_vals(i) > tol
        S_inv(i, i) = 1.0 / sing_vals(i);
    end
end

K_lambda = V * S_inv * U.';

% ИЗОЛИРОВАННЫЙ ВЫВОД ТРЕХ ФИЗИЧЕСКИХ КОМПОНЕНТ ПРОМАХА (в метрах)
std_X = sqrt(K_lambda(1, 1)); % Ошибка бокового ухода (путевая координата)
std_Y = sqrt(K_lambda(2, 2)); % Ошибка прилета по дальности (глубина засечки)
std_Z = sqrt(K_lambda(3, 3)); % Ошибка по высоте (влияние конечной высоты)
status = 0;
end
