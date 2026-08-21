function [summary_data] = matcompare(STATION_POSITIONS, x_true, y_true, z_true, VAR_ALPHA, VAR_BETA, DOA_ERROR_DEGREE, RANDOM_SEED)
% =========================================================================
% СРАВНИТЕЛЬНЫЙ ДИНАМИЧЕСКИЙ СТЕНД ОБРАБОТКИ ДАННЫХ
% =========================================================================
% Входные параметры:
%   STATION_POSITIONS - Координаты станций группировки [3 x M]
%   x_true, y_true, z_true - Векторы истинной траектории цели [1 x K]
%   VAR_ALPHA, VAR_BETA    - Векторы дисперсий шума каналов [M x 1]
%   DOA_ERROR_DEGREE       - Паспортное СКО шума датчиков (градусы)
%   RANDOM_SEED            - Зерно генератора псевдослучайных чисел
% Output:
%   summary_data           - Структура с массивами результатов сравнения
% =========================================================================

M = size(STATION_POSITIONS, 2);
K_points = length(x_true);

% Инициализация массивов накопления результатов
res_pos_lls  = zeros(3, K_points);
res_pos_gn   = zeros(3, K_points);
res_std_lls  = zeros(3, K_points); % [X; Y; Z]
res_std_gn   = zeros(3, K_points); % [X; Y; Z]

status_lls   = zeros(1, K_points);
status_gn    = zeros(1, K_points);

rng(RANDOM_SEED); % Фиксация генератора шума

for k = 1:K_points
    % Истинный вектор цели на текущем такте
    target_true = [x_true(k); y_true(k); z_true(k)];
    
    alpha_measured = zeros(M, 1);
    beta_measured  = zeros(M, 1);
    
    % Моделирование физического процесса пеленгации с наложением шума
    for i = 1:M
        dx = target_true(1) - STATION_POSITIONS(1, i);
        dy = target_true(2) - STATION_POSITIONS(2, i);
        dz = target_true(3) - STATION_POSITIONS(3, i);
        r_xy = sqrt(dx^2 + dy^2);
        
        alpha_measured(i) = atan2(dy, dx) + deg2rad(DOA_ERROR_DEGREE) * randn();
        beta_measured(i)  = atan2(dz, r_xy) + deg2rad(DOA_ERROR_DEGREE) * randn();
    end
    
    % --- ПОТОК ПОТОК №1: Классический Линейный МНК (LLS) ---
    [st_l_pos, lambda_lls] = lls3d_position(STATION_POSITIONS, alpha_measured, beta_measured);
    status_lls(k) = st_l_pos;
    
    if st_l_pos == 0
        res_pos_lls(:, k) = lambda_lls;
        % Расчет декартовой ковариации LLS
        [st_l_cov, sx, sy, sz] = lls3d_covariance(STATION_POSITIONS, alpha_measured, beta_measured, VAR_ALPHA, VAR_BETA, lambda_lls);
        if st_l_cov == 0
            res_std_lls(:, k) = [sx; sy; sz];
        end
    end
    
    % --- ПОТОК ПОТОК №2: Нелинейный Метод Гаусса-Ньютона (GN) ---
    [st_g_pos, lambda_gn] = gn3d_position(STATION_POSITIONS, alpha_measured, beta_measured);
    status_gn(k) = st_g_pos;
    
    if st_g_pos == 0
        res_pos_gn(:, k) = lambda_gn;
        % Устойчивый нелинейный SVD-расчет СКО
        [st_g_cov, sx, sy, sz] = gn3d_covariance(STATION_POSITIONS, VAR_ALPHA, VAR_BETA, lambda_gn);
        if st_g_cov == 0
            res_std_gn(:, k) = [sx; sy; sz];
        end
    end
end

% Упаковка результатов в монолитную структуру данных
summary_data.res_pos_lls = res_pos_lls;
summary_data.res_pos_gn  = res_pos_gn;
summary_data.res_std_lls = res_std_lls;
summary_data.res_std_gn  = res_std_gn;
summary_data.status_lls  = status_lls;
summary_data.status_gn   = status_gn;

end
