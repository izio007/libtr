function [fixed, summary] = test_verify_polar_invariant_fisher(STATION_COUNTS_VECTOR, FIXED_N_STATIONS, STATION_X_ANCHORS, STATION_Y_ANCHORS, STATION_Z_ANCHORS, x_true, y_true, z_true, DOA_ERROR_DEGREE, RANDOM_SEED)
% =========================================================================
% ВЕРИФИКАТОР: ИСТИННЫЙ ПОЛЯРНЫЙ ИНВАРИАНТ ФИШЕРА ДЛЯ GAUSS-NEWTON
% Path: d:\workspace\libtr\matlabtests\test_verify_polar_invariant_fisher.m
% =========================================================================
addpath('d:\workspace\libtr\matlab\');

TRAJECTORY_POINTS_COUNT = length(x_true);
L_counts = length(STATION_COUNTS_VECTOR);
t_anchors = 1:length(STATION_X_ANCHORS);

summary.rmse = zeros(L_counts, 1); 
summary.mean_miss = zeros(L_counts, 1);
summary.max_miss = zeros(L_counts, 1); 
summary.bias_y = zeros(L_counts, 1);

fixed.pos = zeros(3, TRAJECTORY_POINTS_COUNT);
fixed.std_X = zeros(TRAJECTORY_POINTS_COUNT, 1);
fixed.std_Y = zeros(TRAJECTORY_POINTS_COUNT, 1);
fixed.std_Z = zeros(TRAJECTORY_POINTS_COUNT, 1);
fixed.STATION_POSITIONS = [];

for s_idx = 1:L_counts
    N_STATIONS = STATION_COUNTS_VECTOR(s_idx);
    t_query = linspace(1, length(STATION_X_ANCHORS), N_STATIONS);
    STATION_POSITIONS = [spline(t_anchors, STATION_X_ANCHORS, t_query); ...
                         spline(t_anchors, STATION_Y_ANCHORS, t_query); ...
                         spline(t_anchors, STATION_Z_ANCHORS, t_query)];
                     
    VAR_ALPHA = deg2rad(DOA_ERROR_DEGREE)^2 * ones(N_STATIONS, 1);
    VAR_BETA  = deg2rad(DOA_ERROR_DEGREE)^2 * ones(N_STATIONS, 1);
    
    results_pos = zeros(3, TRAJECTORY_POINTS_COUNT);
    results_std_X = zeros(TRAJECTORY_POINTS_COUNT, 1);
    results_std_Y = zeros(TRAJECTORY_POINTS_COUNT, 1);
    results_std_Z = zeros(TRAJECTORY_POINTS_COUNT, 1);
    status = zeros(1, TRAJECTORY_POINTS_COUNT);
    
    rng(RANDOM_SEED);
    for k = 1:TRAJECTORY_POINTS_COUNT
        alpha_m = zeros(N_STATIONS, 1); beta_m = zeros(N_STATIONS, 1);
        for i = 1:N_STATIONS
            dx = x_true(k) - STATION_POSITIONS(1, i); 
            dy = y_true(k) - STATION_POSITIONS(2, i); 
            dz = z_true(k) - STATION_POSITIONS(3, i);
            alpha_m(i) = atan2(dy, dx) + deg2rad(DOA_ERROR_DEGREE) * randn();
            beta_m(i)  = atan2(dz, sqrt(dx^2 + dy^2)) + deg2rad(DOA_ERROR_DEGREE) * randn();
        end
        
        % Вызов полярного нелинейного МНК-поиска координат
        [st_p, lambda] = gn3d_position_polar(STATION_POSITIONS, alpha_m, beta_m);
        status(k) = st_p;
        if st_p == 0
            results_pos(:, k) = lambda;
            % Вызов полярного инварианта ковариации матрицы Фишера
            [st_c, s_along, s_cross, sz] = gn3d_covariance_polar_invariant(STATION_POSITIONS, VAR_ALPHA, VAR_BETA, lambda);
            if st_c == 0
                results_std_X(k) = s_cross; 
                results_std_Y(k) = s_along; 
                results_std_Z(k) = sz;
            end
        end
    end
    
    mask = (status == 0);
    if any(mask)
        err_x = results_pos(1, mask) - x_true(mask); 
        err_y = results_pos(2, mask) - y_true(mask); 
        err_z = results_pos(3, mask) - z_true(mask);
        absolute_miss = sqrt(err_x.^2 + err_y.^2 + err_z.^2);
        
        summary.rmse(s_idx) = sqrt(mean(err_x.^2 + err_y.^2 + err_z.^2));
        summary.mean_miss(s_idx) = mean(absolute_miss);
        summary.max_miss(s_idx) = max(absolute_miss);
        summary.bias_y(s_idx) = mean(err_y);
    end
    
    if N_STATIONS == FIXED_N_STATIONS
        fixed.pos = results_pos; 
        fixed.std_X = results_std_X; 
        fixed.std_Y = results_std_Y; 
        fixed.std_Z = results_std_Z;
        fixed.STATION_POSITIONS = STATION_POSITIONS;
    end
end
end
