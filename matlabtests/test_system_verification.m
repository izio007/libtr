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

summary_rmse = zeros(length(STATION_COUNTS_VECTOR), 1);
summary_mean_miss = zeros(length(STATION_COUNTS_VECTOR), 1);
summary_max_miss = zeros(length(STATION_COUNTS_VECTOR), 1);
summary_bias_y = zeros(length(STATION_COUNTS_VECTOR), 1);

t_anchors = 1:length(STATION_X_ANCHORS);
t_steps = linspace(0, 1, TRAJECTORY_POINTS_COUNT);
x_true = TARGET_X_START + (TARGET_X_FINISH - TARGET_X_START) * t_steps;
y_true = TARGET_Y_STATIC * ones(size(t_steps));
z_true = TARGET_Z_STATIC * ones(size(t_steps));

fixed_results_pos = zeros(3, TRAJECTORY_POINTS_COUNT);
fixed_results_std = zeros(1, TRAJECTORY_POINTS_COUNT);
fixed_status_position = zeros(1, TRAJECTORY_POINTS_COUNT);
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
    
    results_pos = zeros(3, TRAJECTORY_POINTS_COUNT);
    results_std = zeros(1, TRAJECTORY_POINTS_COUNT);
    status_position = zeros(1, TRAJECTORY_POINTS_COUNT);
    
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
        
        % --- ВЫЗОВ НОВОЙ НЕПРЕРЫВНОЙ ФУНКЦИИ ПОДГОТОВКИ ВЕСОВ ---
        [st_prep, W_diag] = lls3d_prepare_data(STATION_POSITIONS, alpha_measured, beta_measured, VAR_ALPHA, VAR_BETA);
        
        if st_prep == 0
            % Взвешенное позиционирование (WLLS) вместо обычного МНК
            [st_p, lambda] = wlls3d_position(STATION_POSITIONS, alpha_measured, beta_measured, W_diag);
            status_position(k) = st_p;
            
            if st_p == 0
                results_pos(:, k) = lambda;
                % Взвешенный расчет ковариации, учитывающий плавное демпфирование
                [st_c, K_lambda, std_3d] = wlls3d_covariance(STATION_POSITIONS, alpha_measured, beta_measured, VAR_ALPHA, VAR_BETA, lambda, W_diag);
                status_covariance(k) = st_c;
                if st_c == 0
                    results_std(k) = std_3d;
                end
            end
        else
            status_position(k) = 1;
        end
    end
    
    % =========================================================================
    % БЕЗОПАСНЫЙ СБОР МЕТРИК ПРОМАХА (ЗАЩИТА ОТ ПУСТЫХ МАССИВОВ)
    % =========================================================================
    valid_mask = (status_position == 0);
    
    if any(valid_mask)
        error_x = results_pos(1, valid_mask) - x_true(valid_mask);
        error_y = results_pos(2, valid_mask) - y_true(valid_mask);
        error_z = results_pos(3, valid_mask) - z_true(valid_mask);
        absolute_miss = sqrt(error_x.^2 + error_y.^2 + error_z.^2);
        
        summary_rmse(s_idx) = sqrt(mean(error_x.^2 + error_y.^2 + error_z.^2));
        summary_mean_miss(s_idx) = mean(absolute_miss);
        summary_max_miss(s_idx) = max(absolute_miss);
        summary_bias_y(s_idx) = mean(error_y);
    else
        summary_rmse(s_idx) = NaN;
        summary_mean_miss(s_idx) = NaN;
        summary_max_miss(s_idx) = NaN;
        summary_bias_y(s_idx) = NaN;
    end
    
    if N_STATIONS == FIXED_N_STATIONS
        fixed_results_pos = results_pos;
        fixed_results_std = results_std;
        fixed_status_position = status_position;
        fixed_STATION_POSITIONS = STATION_POSITIONS;
    end
end

% =========================================================================
% МОНОЛИТНАЯ ВИЗУАЛИЗАЦИЯ (ЕДИНОЕ ОКНО, 4 САБПЛОТА)
% =========================================================================
figure('Name', sprintf('Комплексный анализ: Детальный пролет (%d станций) и сводная сходимость до 124 станций', FIXED_N_STATIONS));

% Сабплот 1: Траектория и облако оценок (Геометрия)
subplot(2,2,1);
t_mesh = linspace(1, length(STATION_X_ANCHORS), 500);
spline_x_mesh = spline(t_anchors, STATION_X_ANCHORS, t_mesh);
spline_y_mesh = spline(t_anchors, STATION_Y_ANCHORS, t_mesh);

plot(spline_x_mesh/1000, spline_y_mesh/1000, 'g-', 'LineWidth', 2); hold on;
plot(x_true/1000, y_true/1000, 'k--', 'LineWidth', 2);
plot(fixed_STATION_POSITIONS(1,:)/1000, fixed_STATION_POSITIONS(2,:)/1000, 'b^', 'MarkerSize', 8, 'LineWidth', 2);

valid_idx = (fixed_status_position == 0);
plot(fixed_results_pos(1, valid_idx)/1000, fixed_results_pos(2, valid_idx)/1000, 'r.', 'MarkerSize', 6);

grid on; axis equal;
xlabel('X, km'); ylabel('Y, km');
xlim([-25 25]); ylim([-10 40]);
title(sprintf('Положение и облако оценок (Фиксировано станций = %d)', FIXED_N_STATIONS));

% Сабплот 2: Профиль мгновенного СКО во времени
subplot(2,2,2);
plot(x_true/1000, fixed_results_std/1000, 'b-', 'LineWidth', 1.5);
grid on;
xlabel('X, km'); ylabel('Calculated STD, km');
xlim([-20 20]);
title('Профиль расчетного СКО');

    % =========================================================================
    % БЕЗОПАСНЫЙ СБОР МЕТРИК ПРОМАХА
    % =========================================================================
    valid_mask = (status_position == 0);
    
    if any(valid_mask)
        error_x = results_pos(1, valid_mask) - x_true(valid_mask);
        error_y = results_pos(2, valid_mask) - y_true(valid_mask);
        error_z = results_pos(3, valid_mask) - z_true(valid_mask);
        absolute_miss = sqrt(error_x.^2 + error_y.^2 + error_z.^2);
        
        summary_rmse(s_idx) = sqrt(mean(error_x.^2 + error_y.^2 + error_z.^2));
        summary_mean_miss(s_idx) = mean(absolute_miss);
        summary_max_miss(s_idx) = max(absolute_miss);
        summary_bias_y(s_idx) = mean(error_y);
    else
        summary_rmse(s_idx) = NaN;
        summary_mean_miss(s_idx) = NaN;
        summary_max_miss(s_idx) = NaN;
        summary_bias_y(s_idx) = NaN;
    end
    
    if N_STATIONS == FIXED_N_STATIONS
        fixed_results_pos = results_pos;
        fixed_results_std = results_std;
        fixed_status_position = status_position;
        fixed_STATION_POSITIONS = STATION_POSITIONS;
    end


% =========================================================================
% МОНОЛИТНАЯ ВИЗУАЛИЗАЦИЯ (4 САБПЛОТА)
% =========================================================================
figure('Name', sprintf('Взвешенный анализ: Плавное Гауссово демпфирование (%d станций)', FIXED_N_STATIONS));

subplot(2,2,1);
t_mesh = linspace(1, length(STATION_X_ANCHORS), 500);
spline_x_mesh = spline(t_anchors, STATION_X_ANCHORS, t_mesh);
spline_y_mesh = spline(t_anchors, STATION_Y_ANCHORS, t_mesh);

plot(spline_x_mesh/1000, spline_y_mesh/1000, 'g-', 'LineWidth', 2); hold on;
plot(x_true/1000, y_true/1000, 'k--', 'LineWidth', 2);
plot(fixed_STATION_POSITIONS(1,:)/1000, fixed_STATION_POSITIONS(2,:)/1000, 'b^', 'MarkerSize', 8, 'LineWidth', 2);

valid_idx = (fixed_status_position == 0);
plot(fixed_results_pos(1, valid_idx)/1000, fixed_results_pos(2, valid_idx)/1000, 'r.', 'MarkerSize', 6);
grid on; axis equal;
xlabel('X, km'); ylabel('Y, km');
xlim([-25 25]); ylim([-10 40]);
title(sprintf('Положение и облако оценок WLLS (Станций = %d)', FIXED_N_STATIONS));

subplot(2,2,2);
plot(x_true/1000, fixed_results_std/1000, 'b-', 'LineWidth', 1.5);
grid on;
xlabel('X, km'); ylabel('Calculated WLLS STD, km');
xlim([-20 20]);
title('Профиль взвешенного СКО во времени');

subplot(2,2,3);
plot(STATION_COUNTS_VECTOR, summary_rmse, 'r-o', 'LineWidth', 2); hold on;
plot(STATION_COUNTS_VECTOR, summary_mean_miss, 'b-s', 'LineWidth', 1.5);
plot(STATION_COUNTS_VECTOR, summary_max_miss, 'g-^', 'LineWidth', 1.5);
grid on;
xlabel('Number of Stations along Spline'); ylabel('Miss Magnitude, meters');
legend('RMSE', 'Mean Miss', 'Max Miss', 'Location', 'northeast');

subplot(2,2,4);
plot(STATION_COUNTS_VECTOR, summary_bias_y, 'm-d', 'LineWidth', 2);
grid on;
xlabel('Number of Stations along Spline'); ylabel('Systemic Bias Y, meters');
legend('Bias Y', 'Location', 'northeast');
title('Динамика смещения дальности WLLS');