function [status, lambda] = gn3d_position_polar(P, alpha, beta)
% =========================================================================
% НЕЛИНЕЙНОЕ ПОЗИЦИОНИРОВАНИЕ В ИНВАРИАНТНЫХ ПОЛЯРНЫХ ОСЯХ (1 ШАГ GN)
% Responsibility: Поиск 3D координат цели через Якобиан в базисе визирования
% Path: d:\workspace\libtr\matlab\gn3d_position_polar.m
% =========================================================================

lambda = [0; 0; 0];
M = size(P, 2);

% 1. Явное переиспользование базового линейного МНК для получения начальной точки
[st_lls, lambda_lls] = lls3d_position(P, alpha, beta);
if st_lls ~= 0
    status = 1; return;
end

x = lambda_lls(1); y = lambda_lls(2); z = lambda_lls(3);

% Находим геометрический центр масс системы для построения полярного базиса
x_c = mean(P(1, :)); y_c = mean(P(2, :)); z_c = mean(P(3, :));
dx_c = x - x_c; dy_c = y - y_c; dz_c = z - z_c;
rho_c = sqrt(dx_c^2 + dy_c^2 + dz_c^2);
if rho_c < 1e-3, rho_c = 1e-3; end

% Направляющие косинусы для матрицы поворота U (3x3)
r_x = dx_c / rho_c; r_y = dy_c / rho_c; r_z = dz_c / rho_c;
rho_xy_c = sqrt(dx_c^2 + dy_c^2); if rho_xy_c < 1e-3, rho_xy_c = 1e-3; end

U = zeros(3, 3);
U(1, 1) = r_x;             U(1, 2) = r_y;             U(1, 3) = r_z;            % Ось Along-Track (Дальность)
U(2, 1) = -dy_c/rho_xy_c;  U(2, 2) = dx_c/rho_xy_c;   U(2, 3) = 0;              % Ось Cross-Track (Боковой уход)
U(3, 1) = -r_x*r_z/rho_xy_c; U(3, 2) = -r_y*r_z/rho_xy_c; U(3, 3) = rho_xy_c/rho_c; % Высота Z

J_cart = zeros(2*M, 3);
delta_Y = zeros(2*M, 1);

% 2. Формирование классических нелинейных невязок и декартова Якобиана
for i = 1:M
    dx = x - P(1, i); dy = y - P(2, i); dz = z - P(3, i);
    rho_xy = sqrt(dx^2 + dy^2); rho = sqrt(dx^2 + dy^2 + dz^2);
    if rho_xy < 1e-3, rho_xy = 1e-3; end
    if rho < 1e-3, rho = 1e-3; end
    
    alpha_theo = atan2(dy, dx); 
    beta_theo  = atan2(dz, rho_xy);
    
    d_alpha = alpha(i) - alpha_theo;
    d_alpha = atan2(sin(d_alpha), cos(d_alpha));
    d_beta  = beta(i) - beta_theo;
    
    delta_Y(2*i-1) = d_alpha;
    delta_Y(2*i)   = d_beta;
    
    sa = sin(alpha_theo); ca = cos(alpha_theo);
    sb = sin(beta_theo);  cb = cos(beta_theo);
    
    J_cart(2*i-1, 1) = -sa / rho_xy; J_cart(2*i-1, 2) =  ca / rho_xy; J_cart(2*i-1, 3) =  0;
    J_cart(2*i, 1)   = -ca * sb / rho; J_cart(2*i, 2)   = -sa * sb / rho; J_cart(2*i, 3)   =  cb / rho;
end

% 3. ТЕНЗОРНЫЙ ПЕРЕХОД ЯКОБИАНА В ПОЛЯРНЫЙ БАЗИС ЦЕЛИ: J_polar = J_cart * U'
J_polar = J_cart * U.';

JtJ_polar = J_polar.' * J_polar;
if rcond(JtJ_polar) < 1e-12
    status = 2; return;
end

% Вычисление вектора поправки в инвариантных полярных осях цели
delta_lambda_polar = JtJ_polar \ (J_polar.' * delta_Y);

% Перевод найденной поправки обратно в декартов базис: delta_lambda_cart = U' * delta_lambda_polar
delta_lambda_cart = U.' * delta_lambda_polar;

% Финальный шаг обновления вектора состояния координат цели
lambda = lambda_lls + delta_lambda_cart;
status = 0;
end
