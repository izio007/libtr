function [status, std_Along, std_Cross, std_Z] = gn3d_covariance_polar_invariant(P, var_alpha, var_beta, lambda_gn)
% =========================================================================
% ИСТИННЫЙ ПОЛЯРНЫЙ ИНВАРИАНТ МАТРИЦЫ ФИШЕРА (SINGLE-SHOT)
% Responsibility: Оценка СКО в инвариантных осях направления на цель
% Path: d:\workspace\libtr\matlab\gn3d_covariance_polar_invariant.m
% =========================================================================

std_Along = NaN; std_Cross = NaN; std_Z = NaN;
M = size(P, 2);

if M < 2 || length(lambda_gn) ~= 3
    status = 1; return;
end

x = lambda_gn(1); y = lambda_gn(2); z = lambda_gn(3);
J = zeros(2*M, 3);
W_noise = zeros(2*M, 1);

% 1. Строим классический аналитический Якобиан Фишера в текущей точке
for i = 1:M
    dx = x - P(1, i); dy = y - P(2, i); dz = z - P(3, i);
    rho_xy = sqrt(dx^2 + dy^2); rho = sqrt(dx^2 + dy^2 + dz^2);
    if rho_xy < 1e-3, rho_xy = 1e-3; end
    if rho < 1e-3, rho = 1e-3; end
    
    alpha_theo = atan2(dy, dx); beta_theo = atan2(dz, rho_xy);
    sa = sin(alpha_theo); ca = cos(alpha_theo);
    sb = sin(beta_theo);  cb = cos(beta_theo);
    
    J(2*i-1, 1) = -sa / rho_xy; J(2*i-1, 2) =  ca / rho_xy; J(2*i-1, 3) =  0;
    J(2*i, 1)   = -ca * sb / rho; J(2*i, 2)   = -sa * sb / rho; J(2*i, 3)   = cb / rho;
    
    W_noise(2*i-1) = 1.0 / var_alpha(i);
    W_noise(2*i)   = 1.0 / var_beta(i);
end

I_Fisher = J.' * diag(W_noise) * J;
if rcond(I_Fisher) < 1e-12
    status = 2; return;
end

K_cartesian = inv(I_Fisher);

% 2. СТРОГИЙ ТЕНЗОРНЫЙ ПОВОРОТ В ИНВАРИАНТНЫЙ БАЗИС НАПРАВЛЕНИЯ ЦЕЛИ
x_c = mean(P(1, :)); y_c = mean(P(2, :)); z_c = mean(P(3, :));
dx_c = x - x_c; dy_c = y - y_c; dz_c = z - z_c;
rho_c = sqrt(dx_c^2 + dy_c^2 + dz_c^2);
if rho_c < 1e-3, rho_c = 1e-3; end

r_x = dx_c / rho_c; r_y = dy_c / rho_c; r_z = dz_c / rho_c;
rho_xy_c = sqrt(dx_c^2 + dy_c^2); if rho_xy_c < 1e-3, rho_xy_c = 1e-3; end

% Геометрически инвариантная матрица перехода U (3x3)
U = zeros(3, 3);
U(1, 1) = r_x;             U(1, 2) = r_y;             U(1, 3) = r_z;            % Ось Along-Track (Дальность)
U(2, 1) = -dy_c/rho_xy_c;  U(2, 2) = dx_c/rho_xy_c;   U(2, 3) = 0;              % Ось Cross-Track (Боковой уход)
U(3, 1) = -r_x*r_z/rho_xy_c; U(3, 2) = -r_y*r_z/rho_xy_c; U(3, 3) = rho_xy_c/rho_c; % Высота Z

% Поворот тензора декартовых ошибок в полярный инвариант
K_polar = U * K_cartesian * U.';

% Извлекаем чистые физические компоненты, устойчивые к параметрам декартовой сетки
std_Along = sqrt(K_polar(1, 1)); % Продольное СКО
std_Cross = sqrt(K_polar(2, 2)); % Поперечное СКО
std_Z     = sqrt(K_polar(3, 3)); % Высотное СКО
status = 0;
end
