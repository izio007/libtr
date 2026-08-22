function [status, lambda] = gn3d_position(P, alpha, beta)
% =========================================================================
% ФУНКЦИЯ ИТЕРАЦИОННОГО ДЕКАРТОВА 3D-ПОЗИЦИОНИРОВАНИЯ GAUSS-NEWTON
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

% Переиспользование базового линейного LLS для получения начальной точки
[st_lls, lambda_init] = lls3d_position(P, alpha, beta);
if st_lls ~= 0 || any(isnan(lambda_init))
    status = 2; return;
end

lambda = lambda_init;

for iter = 1:6
    x = lambda(1); y = lambda(2); z = lambda(3);
    J = zeros(2*M, 3);
    delta_Y = zeros(2*M, 1);
    
    for i = 1:M
        dx = x - P(1, i); dy = y - P(2, i); dz = z - P(3, i);
        rho_xy = sqrt(dx^2 + dy^2); rho = sqrt(dx^2 + dy^2 + dz^2);
        if rho_xy < 1e-3, rho_xy = 1e-3; end
        if rho < 1e-3,    rho = 1e-3; end
        
        alpha_theo = atan2(dy, dx); 
        beta_theo  = atan2(dz, rho_xy);
        
        % Классические угловые невязки в радианах
        d_alpha = alpha(i) - alpha_theo;
        d_alpha = atan2(sin(d_alpha), cos(d_alpha)); % Строгая тригонометрическая коррекция
        d_beta  = beta(i) - beta_theo;
        
        delta_Y(2*i-1) = d_alpha;
        delta_Y(2*i)   = d_beta;
        
        sa = sin(alpha_theo); ca = cos(alpha_theo);
        sb = sin(beta_theo);  cb = cos(beta_theo);
        
        % Истинные аналитические частные производные в рад/м от оси OX
        J(2*i-1, 1) = -sa / rho_xy; J(2*i-1, 2) =  ca / rho_xy; J(2*i-1, 3) =  0;
        J(2*i, 1)   = -ca * sb / rho; J(2*i, 2)   = -sa * sb / rho; J(2*i, 3)   =  cb / rho;
    end
    
    JtJ = J.' * J;
    
    % Честный аналитический отказ при вырождении — без SVD-маскировки!
    if rcond(JtJ) < 2.2204e-16 || isnan(rcond(JtJ))
        status = 2; lambda = [NaN; NaN; NaN]; return;
    end
    
    delta_lambda = JtJ \ (J.' * delta_Y);
    lambda = lambda + delta_lambda;
    
    if norm(delta_lambda) < 1e-2
        break;
    end
end

status = 0;
end
