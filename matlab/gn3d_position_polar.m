function [status, lambda] = gn3d_position_polar(P, alpha, beta)
% =========================================================================
% ФУНКЦИЯ ИТКРАЦИОННОГО ПОЛЯРНОГО 3D-ПОЗИЦИОНИРОВАНИЯ GAUSS-NEWTON
% Входные параметры:
%   P      - Физическая матрица координат измерительных пунктов [3 x M]
%   alpha  - Вектор измеренных азимутов цели [M x 1] (радианы)
%   beta   - Вектор измеренных углов места цели [M x 1] (радианы)
% Выходные параметры:
%   status - Флаг выполнения (0 - успешно, 1 - сбой размерности, 2 - вырождение)
%   lambda - Оцененные декартовы координаты цели [x; y; z] (метры)
% =========================================================================
lambda = [NaN; NaN; NaN];
M = size(P, 2);

% Первичное линейное приближение для старта итераций (переиспользование голого LLS)
[st_lls, lambda_init] = lls_position(P, alpha, beta);
if st_lls ~= 0 || any(isnan(lambda_init))
    status = 2; return;
end

lambda = lambda_init;
x_c = mean(P(1, :)); y_c = mean(P(2, :)); z_c = mean(P(3, :));

for iter = 1:6
    x = lambda(1); y = lambda(2); z = lambda(3);
    
    % Построение локального полярного базиса текущей итерационной точки цели
    dx_c = x - x_c; dy_c = y - y_c; dz_c = z - z_c;
    rho_c = sqrt(dx_c^2 + dy_c^2 + dz_c^2); if rho_c < 1e-3, rho_c = 1e-3; end
    
    r_x = dx_c / rho_c; r_y = dy_c / rho_c; r_z = dz_c / rho_c;
    rho_xy_c = sqrt(dx_c^2 + dy_c^2); if rho_xy_c < 1e-3, rho_xy_c = 1e-3; end
    
    % Матрица ортогонального перехода U от оси OX
    U = zeros(3, 3);
    U(1, 1) = r_x;             U(1, 2) = r_y;             U(1, 3) = r_z;            % Along-Track
    U(2, 1) = -dy_c/rho_xy_c;  U(2, 2) = dx_c/rho_xy_c;   U(2, 3) = 0;              % Cross-Track
    U(3, 1) = -r_x*r_z/rho_xy_c; U(3, 2) = -r_y*r_z/rho_xy_c; U(3, 3) = rho_xy_c/rho_c; % Вертикаль
    
    J_cart = zeros(2*M, 3);
    delta_Y = zeros(2*M, 1);
    
    for i = 1:M
        dx = x - P(1, i); dy = y - P(2, i); dz = z - P(3, i);
        rho_xy = sqrt(dx^2 + dy^2); rho = sqrt(dx^2 + dy^2 + dz^2);
        if rho_xy < 1e-3, rho_xy = 1e-3; end
        if rho < 1e-3,    rho = 1e-3; end
        
        alpha_theo = atan2(dy, dx); 
        beta_theo  = atan2(dz, rho_xy);
        
        d_alpha = alpha(i) - alpha_theo;
        d_alpha = atan2(sin(d_alpha), cos(d_alpha)); % Коррекция фазы
        d_beta  = beta(i) - beta_theo;
        
        delta_Y(2*i-1) = d_alpha;
        delta_Y(2*i)   = d_beta;
        
        sa = sin(alpha_theo); ca = cos(alpha_theo);
        sb = sin(beta_theo);  cb = cos(beta_theo);
        
        % Строгий Якобиан частных производных от оси OX (рад/м)
        J_cart(2*i-1, 1) = -sa / rho_xy; J_cart(2*i-1, 2) =  ca / rho_xy; J_cart(2*i-1, 3) =  0;
        J_cart(2*i, 1)   = -ca * sb / rho; J_cart(2*i, 2)   = -sa * sb / rho; J_cart(2*i, 3)   =  cb / rho;
    end
    
    % Проекция декартова Якобиана в локальные полярные оси направления цели
    J_polar = J_cart * U.';
    JtJ_polar = J_polar.' * J_polar;
    
    % Чистая аналитическая проверка вырождения. Без SVD-маскировки!
    if rcond(JtJ_polar) < eps || isnan(rcond(JtJ_polar))
        status = 2; lambda = [NaN; NaN; NaN]; return;
    end
    
    % Нахождение вектора нелинейной поправки в осях Along/Cross-Track
    delta_lambda_polar = JtJ_polar \ (J_polar.' * delta_Y);
    
    % Обратный перевод поправки в декартовы координаты ПВО
    delta_lambda_cart = U.' * delta_lambda_polar;
    lambda = lambda + delta_lambda_cart;
    
    if norm(delta_lambda_cart) < 1e-2
        break;
    end
end

status = 0;
end
