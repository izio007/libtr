% =========================================================================
% КОНФИГУРАЦИОННЫЙ РАЗДЕЛ (SYSTEM CONFIGURATION)
% =========================================================================

% 1. Конфигурация измерительной группировки (Координаты станций, м)
STATION_POSITIONS = [-20000,  20000,      0,      0; ... 
                          0,      0, -20000,  20000; ... 
                          0,      0,      0,      0];    

% 2. Параметры точности датчиков пеленгования
DOA_ERROR_DEGREE = 2.0;
VAR_ALPHA = deg2rad(DOA_ERROR_DEGREE)^2 * ones(size(STATION_POSITIONS, 2), 1);
VAR_BETA  = deg2rad(DOA_ERROR_DEGREE)^2 * ones(size(VAR_ALPHA));

% 3. Параметры траектории движения цели (в метрах)
TRAJECTORY_POINTS_COUNT = 500;
TARGET_X_START  = -150000;
TARGET_X_FINISH =  150000;
TARGET_Y_STATIC =  200000;
TARGET_Z_START  =  10000;
TARGET_Z_AMPLITUDE = 5000;

% 4. Параметры статического теста Монте-Карло в фиксированной точке 200 км
MONTE_CARLO_RUNS = 50000;
MC_TARGET_POS = [0; 200000; 10000];

% 5. Системные константы генератора случайных чисел
RANDOM_SEED = 1337;

% =========================================================================
% ИСПОЛНИТЕЛЬНЫЙ РАЗДЕЛ 1: ТРАЕКТОРНЫЙ ТЕСТ
% =========================================================================

M = size(STATION_POSITIONS, 2);
t = linspace(0, 1, TRAJECTORY_POINTS_COUNT);

x_true = TARGET_X_START + (TARGET_X_FINISH - TARGET_X_START) * t;
y_true = TARGET_Y_STATIC * ones(size(t));
z_true = TARGET_Z_START + TARGET_Z_AMPLITUDE * sin(t * pi);

results_pos = zeros(3, TRAJECTORY_POINTS_COUNT);
results_std = zeros(1, TRAJECTORY_POINTS_COUNT);
status_position = zeros(1, TRAJECTORY_POINTS_COUNT);
status_covariance = zeros(1, TRAJECTORY_POINTS_COUNT);

rng(RANDOM_SEED);

for k = 1:TRAJECTORY_POINTS_COUNT
    target_true = [x_true(k); y_true(k); z_true(k)];
    
    alpha_measured = zeros(M, 1);
    beta_measured  = zeros(M, 1);
    
    for i = 1:M
        dx = target_true(1) - STATION_POSITIONS(1, i);
        dy = target_true(2) - STATION_POSITIONS(2, i);
        dz = target_true(3) - STATION_POSITIONS(3, i);
        r_xy = sqrt(dx^2 + dy^2);
        
        alpha_measured(i) = atan2(dy, dx) + deg2rad(DOA_ERROR_DEGREE) * randn();
        beta_measured(i)  = atan2(dz, r_xy) + deg2rad(DOA_ERROR_DEGREE) * randn();
    end
    
    [st_p, lambda] = lls3d_position(STATION_POSITIONS, alpha_measured, beta_measured);
    status_position(k) = st_p;
    
    if st_p == 0
        results_pos(:, k) = lambda;
        [st_c, K_lambda, std_3d] = lls3d_covariance(STATION_POSITIONS, alpha_measured, beta_measured, VAR_ALPHA, VAR_BETA, lambda);
        status_covariance(k) = st_c;
        if st_c == 0
            results_std(k) = std_3d;
        end
    end
end

% =========================================================================
% ИСПОЛНИТЕЛЬНЫЙ РАЗДЕЛ 2: СТАТИЧЕСКИЙ ТЕСТ МОНТЕ-КАРЛО
% =========================================================================

mc_results_y = zeros(MONTE_CARLO_RUNS, 1);
mc_status = zeros(MONTE_CARLO_RUNS, 1);

for k = 1:MONTE_CARLO_RUNS
    alpha_measured = zeros(M, 1);
    beta_measured  = zeros(M, 1);
    
    for i = 1:M
        dx = MC_TARGET_POS(1) - STATION_POSITIONS(1, i);
        dy = MC_TARGET_POS(2) - STATION_POSITIONS(2, i);
        dz = MC_TARGET_POS(3) - STATION_POSITIONS(3, i);
        r_xy = sqrt(dx^2 + dy^2);
        
        alpha_measured(i) = atan2(dy, dx) + deg2rad(DOA_ERROR_DEGREE) * randn();
        beta_measured(i)  = atan2(dz, r_xy) + deg2rad(DOA_ERROR_DEGREE) * randn();
    end
    
    [st_p, lambda] = lls3d_position(STATION_POSITIONS, alpha_measured, beta_measured);
    mc_status(k) = st_p;
    
    if st_p == 0
        mc_results_y(k) = lambda(2);
    end
end

valid_mc_y = mc_results_y(mc_status == 0) / 1000;

% =========================================================================
% ВИЗУАЛИЗАЦИЯ (PLOTS & HISTOGRAM)
% =========================================================================

figure;
subplot(3,1,1);
plot(x_true/1000, y_true/1000, 'k--', 'LineWidth', 2); hold on;
valid_idx = (status_position == 0);
plot(results_pos(1, valid_idx)/1000, results_pos(2, valid_idx)/1000, 'r.', 'MarkerSize', 8);
grid on; axis equal;
xlabel('X, km'); ylabel('Y, km');

subplot(3,1,2);
plot(x_true/1000, results_std/1000, 'b-', 'LineWidth', 1.5);
grid on;
xlabel('X, km'); ylabel('Calculated STD, km');

subplot(3,1,3);
histogram(valid_mc_y, 100, 'FaceColor', [0.5 0.5 0.5], 'EdgeColor', 'none'); hold on;
xline(MC_TARGET_POS(2)/1000, 'r--', 'LineWidth', 2);
grid on;
xlabel('Y coordinate estimation, km'); ylabel('Counts');
title(sprintf('Empirical Distribution at Center (True Y = %d km)', MC_TARGET_POS(2)/1000));

mc_mode = mode(round(valid_mc_y));
mc_median = median(valid_mc_y);
mc_mean = mean(valid_mc_y);
mc_skew = skewness(valid_mc_y);

fprintf('Истинное Y:     %.2f км\n', MC_TARGET_POS(2)/1000);
fprintf('Мода (Пик):     %.2f км\n', mc_mode);
fprintf('Медиана:        %.2f км\n', mc_median);
fprintf('Среднее:        %.2f км\n', mc_mean);
fprintf('Асимметрия:     %.2f\n', mc_skew);