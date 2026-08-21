function [status, W_diag] = lls3d_prepare_data(P, alpha, beta, var_alpha, var_beta)
MAX_STATIONS = 128;

% Параметр гладкости углового сектора (4 градуса в радианах)
sigma_0 = deg2rad(4.0); 

M = size(P, 2);
W_diag = ones(2*M, 1);

if M < 2 || M > MAX_STATIONS || length(alpha) < M || length(beta) < M
    status = 1; return;
end

% Непрерывное Гауссово демпфирование без жестких порогов 'if'
for i = 1:M
    density_sum = 0.0;
    for j = 1:M
        diff_a = abs(alpha(i) - alpha(j));
        if diff_a > pi, diff_a = 2*pi - diff_a; end
        
        % Накапливаем гладкий вклад плотности по экспоненте
        density_sum = density_sum + exp(-(diff_a^2) / (2 * sigma_0^2));
    end
    
    % Защита от деления на 0 (минимум 1.0, когда станция абсолютно изолирована)
    if density_sum < 1.0, density_sum = 1.0; end
    
    % Формируем непрерывные демпфирующие веса
    W_diag(2*i-1) = 1.0 / density_sum; % Вес азимута
    W_diag(2*i)   = 1.0 / density_sum; % Вес угла места
end

status = 0;
end
