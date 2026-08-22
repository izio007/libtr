function [status, std_Along, std_Cross, std_Z] = gn3d_covariance_polar_invariant(P, var_alpha, var_beta, lambda_gn)
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
std_Along = NaN; std_Cross = NaN; std_Z = NaN;
M = size(P, 2);

if M < 2 || length(lambda_gn) ~= 3 || any(isnan(lambda_gn))
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
    
    alpha_theo = atan2(dy, dx); beta_theo = atan2(dz, rho_xy);
    sa = sin(alpha_theo); ca = cos(alpha_theo);
    sb = sin(beta_theo);  cb = cos(beta_theo);
    
    J(2*i-1, 1) = -sa / rho_xy; J(2*i-1, 2) =  ca / rho_xy; J(2*i-1, 3) =  0;
    J(2*i, 1)   = -ca * sb / rho; J(2*i, 2)   = -sa * sb / rho; J(2*i, 3)   =  cb / rho;
    
    W_noise(2*i-1) = 1.0 / var_alpha(i);
    W_noise(2*i)   = 1.0 / var_beta(i);
end

AtWA = J.' * diag(W_noise) * J;

if rcond(AtWA) < 2.2204e-16 || isnan(rcond(AtWA))
    status = 2; return;
end

K_cartesian = inv(AtWA);

% СТРОГИЙ ТЕНЗОРНЫЙ ПОВОРОТ В ЛОКАЛЬНЫЕ ОСИ ВИЗИРОВАНИЯ ЦЕЛИ
x_c = mean(P(1, :)); y_c = mean(P(2, :)); z_c = mean(P(3, :));
dx_c = x - x_c; dy_c = y - y_c; dz_c = z - z_c;
rho_c = sqrt(dx_c^2 + dy_c^2 + dz_c^2); if rho_c < 1e-3, rho_c = 1e-3; end

r_x = dx_c / rho_c; r_y = dy_c / rho_c; r_z = dz_c / rho_c;
rho_xy_c = sqrt(dx_c^2 + dy_c^2); if rho_xy_c < 1e-3, rho_xy_c = 1e-3; end

U = zeros(3, 3);
U(1, 1) = r_x;             U(1, 2) = r_y;             U(1, 3) = r_z;            % Радиальная ось (Along-Track)
U(2, 1) = -dy_c/rho_xy_c;  U(2, 2) = dx_c/rho_xy_c;   U(2, 3) = 0;              % Поперечная нормаль (Cross-Track)
U(3, 1) = -r_x*r_z/rho_xy_c; U(3, 2) = -r_y*r_z/rho_xy_c; U(3, 3) = rho_xy_c/rho_c; % Вертикаль

% Закон преобразования тензора ковариации: K_polar = U * K_cartesian * U'
K_polar = U * K_cartesian * U.';

std_Along = sqrt(K_polar(1, 1)); 
std_Cross = sqrt(K_polar(2, 2)); 
std_Z     = sqrt(K_polar(3, 3));
status = 0;
end
