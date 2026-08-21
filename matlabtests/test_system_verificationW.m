TRAJECTORY_POINTS_COUNT = 1000;
TARGET_X_START  = -15000;
TARGET_X_FINISH =  15000;
TARGET_Y_STATIC =  30000; 
TARGET_Z_STATIC =  0;

% Геометрия опорных точек сплайна
STATION_X_ANCHORS = [0, -5000, 5000, 625*4];
STATION_Y_ANCHORS =[0, 10000, 20000, 25000];
STATION_Z_ANCHORS =[    1000,     1000,     1000,     1000];

DOA_ERROR_DEGREE = 0.4;
RANDOM_SEED = 1337;

% Вектор всех исследуемых вариантов для сводных графиков
vals = logspace(log10(start), log10(stop), n);
vals_int = round(vals);
vals_int = unique(vals_int);  % убираем повторы из‑за округления
STATION_COUNTS_VECTOR = vals_int; 

% Фиксированное количество станций для детального временного графика (Старый формат)
FIXED_N_STATIONS = STATION_COUNTS_VECTOR(8);



if ~any(STATION_COUNTS_VECTOR == FIXED_N_STATIONS)
    STATION_COUNTS_VECTOR = unique(sort([STATION_COUNTS_VECTOR, FIXED_N_STATIONS]));
end

% Буферы для сводной статистики метода Gauss-Newton (GN)
gn_summary_rmse = zeros(length(STATION_COUNTS_VECTOR), 1);
gn_summary_mean_miss = zeros(length(STATION_COUNTS_VECTOR), 1);
gn_summary_max_miss = zeros(length(STATION_COUNTS_VECTOR), 1);
gn_summary_bias_y = zeros(length(STATION_COUNTS_VECTOR), 1);

t_anchors = 1:length(STATION_X_ANCHORS);
t_steps = linspace(0, 1, TRAJECTORY_POINTS_COUNT);
x_true = TARGET_X_START + (TARGET_X_FINISH - TARGET_X_START) * t_steps;
y_true = TARGET_Y_STATIC * ones(size(t_steps));
z_true = TARGET_Z_STATIC * ones(size(t_steps));

% Переменные для отрисовки фиксированного случая (GN)
fixed_results_pos_gn = zeros(3, TRAJECTORY_POINTS_COUNT);
fixed_results_std_gn = zeros(1, TRAJECTORY_POINTS_COUNT);
fixed_status_gn = zeros(1, TRAJECTORY_POINTS_COUNT);
fixed_STATION_POSITIONS = [];

% =========================================================================
% EXECUTION LOOP FOR ALL CASES
% =========================================================================
for s_idx = 1:length(STATION_COUNTS_VECTOR)
    N_STATIONS = STATION_COUNTS_VECTOR(s_idx);
    
    t_query = linspace(1, length(STATION_X_ANCHORS), N_STATIONS);
    STATION_X = spline(t_anchors, STATION_X_ANCHORS, t_query);
    STATION_Y = spline(t_anchors, STATION_Y_ANCHORS, t_query);
    STATION_Z = spline(t_anchors, STATION_Z_ANCHORS, t_query);
    STATION_POSITIONS = [STATION_X; STATION_Y; STATION_Z];
    
    M = size(STATION_POSITIONS, 2);
    VAR_ALPHA = deg2rad(DOA_ERROR_DEGREE)^2 * ones(M, 1);
    VAR_BETA  = deg2rad(DOA_ERROR_DEGREE)^2 * ones(M, 1);
    
    results_pos_gn = zeros(3, TRAJECTORY_POINTS_COUNT);
    results_std_gn = zeros(1, TRAJECTORY_POINTS_COUNT);
    status_position_gn = zeros(1, TRAJECTORY_POINTS_COUNT);
    
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
        
        % Прямой вызов базовой функции LLS для получения начальной точки
        [st_p, lambda_lls] = lls3d_position(STATION_POSITIONS, alpha_measured, beta_measured);
        
        if st_p == 0
            % Нелинейное итерационное уточнение Gauss-Newton
            [st_gn, lambda_gn] = gn3d_position(STATION_POSITIONS, alpha_measured, beta_measured, lambda_lls);
            status_position_gn(k) = st_gn;
            
            if st_gn == 0
                results_pos_gn(:, k) = lambda_gn;
                % Строгая ковариация нелинейного метода в радианах
                [st_c, ~, std_3d_gn] = gn3d_covariance(STATION_POSITIONS, alpha_measured, beta_measured, VAR_ALPHA, VAR_BETA, lambda_gn);
                if st_c == 0
                    results_std_gn(k) = std_3d_gn;
                end
            end
        else
            status_position_gn(k) = 1;
        end
    end
    
    % --- Сбор чистой статистики для Gauss-Newton ---
    mask_gn = (status_position_gn == 0);
    if any(mask_gn)
        err_x = results_pos_gn(1, mask_gn) - x_true(mask_gn);
        err_y = results_pos_gn(2, mask_gn) - y_true(mask_gn);
        err_z = results_pos_gn(3, mask_gn) - z_true(mask_gn);
        absolute_miss = sqrt(err_x.^2 + err_y.^2 + err_z.^2);
        
        gn_summary_rmse(s_idx) = sqrt(mean(err_x.^2 + err_y.^2 + err_z.^2));
        gn_summary_mean_miss(s_idx) = mean(absolute_miss);
        gn_summary_max_miss(s_idx) = max(absolute_miss);
        gn_summary_bias_y(s_idx) = mean(err_y);
    else
        gn_summary_rmse(s_idx) = NaN;
        gn_summary_mean_miss(s_idx) = NaN;
        gn_summary_max_miss(s_idx) = NaN;
        gn_summary_bias_y(s_idx) = NaN;
    end
    
    if N_STATIONS == FIXED_N_STATIONS
        fixed_results_pos_gn = results_pos_gn;
        fixed_results_std_gn = results_std_gn;
        fixed_status_gn = status_position_gn;
        fixed_STATION_POSITIONS = STATION_POSITIONS;
    end
end

% =========================================================================
% МОНОЛИТНАЯ ВИЗУАЛИЗАЦИЯ GAUSS-NEWTON (4 САБПЛОТА)
% =========================================================================
figure('Name', 'Анализ нелинейного метода Gauss-Newton (1 итерация)');

% Сабплот 1: Траектория и облако оценок GN
subplot(2,2,1);
t_mesh = linspace(1, length(STATION_X_ANCHORS), 500);
spline_x_mesh = spline(t_anchors, STATION_X_ANCHORS, t_mesh);
spline_y_mesh = spline(t_anchors, STATION_Y_ANCHORS, t_mesh);

plot(spline_x_mesh/1000, spline_y_mesh/1000, 'g-', 'LineWidth', 2); hold on;
plot(x_true/1000, y_true/1000, 'k--', 'LineWidth', 2);
plot(fixed_STATION_POSITIONS(1,:)/1000, fixed_STATION_POSITIONS(2,:)/1000, 'b^', 'MarkerSize', 8, 'LineWidth', 2);

valid_idx = (fixed_status_gn == 0);
plot(fixed_results_pos_gn(1, valid_idx)/1000, fixed_results_pos_gn(2, valid_idx)/1000, 'r.', 'MarkerSize', 6);
grid on; axis equal;
xlabel('X, km'); ylabel('Y, km');
xlim([-25 25]); ylim([-10 40]);
title(sprintf('Облако оценок Gauss-Newton (Станций = %d)', FIXED_N_STATIONS));

% Сабплот 2: Теоретическое СКО метода Gauss-Newton во времени
subplot(2,2,2);
plot(x_true/1000, fixed_results_std_gn/1000, 'b-', 'LineWidth', 1.5);
grid on;
xlabel('X, km'); ylabel('Calculated GN STD, km');
xlim([-20 20]);
title('Профиль расчетного СКО GN');

% Сабплот 3: Сводные графики сходимости пространственного промаха GN
subplot(2,2,3);
plot(STATION_COUNTS_VECTOR, gn_summary_rmse, 'r-o', 'LineWidth', 2); hold on;
plot(STATION_COUNTS_VECTOR, gn_summary_mean_miss, 'b-s', 'LineWidth', 1.5);
plot(STATION_COUNTS_VECTOR, gn_summary_max_miss, 'g-^', 'LineWidth', 1.5);
grid on;
xlabel('Number of Stations along Spline'); ylabel('Miss Magnitude, meters');
legend('RMSE (Spatial)', 'Mean Absolute Miss', 'Max Peak Miss', 'Location', 'northeast');
title('Сходимость промаха от плотности сетки');

% Сабплот 4: Сводный график выправления систематического смещения дальности GN
subplot(2,2,4);
plot(STATION_COUNTS_VECTOR, gn_summary_bias_y, 'm-d', 'LineWidth', 2);
grid on;
xlabel('Number of Stations along Spline'); ylabel('Systemic Range Bias (Y), meters');
legend('Bias Y Gauss-Newton', 'Location', 'northeast');
title('Динамика смещения Bias Y GN');

% Вывод сводной таблицы в консоль
fprintf('\n=== СВОДНАЯ ТАБЛИЦА СХОДИМОСТИ МЕТОДА GAUSS-NEWTON ===\n');
fprintf('Станций |  RMSE, м  | Ср.Промах, м | Макс.Промах, м |  Bias Y, м\n');
fprintf('---------------------------------------------------------------\n');
for s_idx = 1:length(STATION_COUNTS_VECTOR)
    fprintf('   %3d  |  %7.2f  |   %7.2f   |    %8.2f    |  %7.2f\n', ...
        STATION_COUNTS_VECTOR(s_idx), gn_summary_rmse(s_idx), ...
        gn_summary_mean_miss(s_idx), gn_summary_max_miss(s_idx), gn_summary_bias_y(s_idx));
end
