% =========================================================================
% ПРИКЛАДНОЙ СЦЕНАРИЙ ТИС: СТРАТЕГИЧЕСКИЙ РУБЕЖ СОПРОВОЖДЕНИЯ 450 КМ (СКВОЗНОЙ ЛОГ)
% Responsibility: Побитовый пачечный контур ТИС со сквозной трассировкой ОЗУ 4-х методов
% Path: d:\workspace\libtr\matlabtests\test_trajectory_200km.m
% =========================================================================

clear; clc; close all;

% 1. ИСХОДНЫЕ ГЕОМЕТРИЧЕСКИЕ И ПРИБОРНЫЕ ДАННЫЕ СТРОГО ИЗ MAT-ПАСПОРТА REPO
STATION_X_ANCHORS = [-20000.0, 20000.0, 0.0, 0.0];
STATION_Y_ANCHORS = [0.0, 0.0, -20000.0, 20000.0];
STATION_Z_ANCHORS = [200.0, 200.0, 200.0, 200.0];

TRAJECTORY_POINTS_COUNT = 300;
TARGET_X_START  = -150000.0; TARGET_X_FINISH = 150000.0;
TARGET_Y_STATIC = 450000.0;  TARGET_Z_STATIC = 10000.0; 
Z_AMPLITUDE     = 5000.0;   

DOA_ERROR_DEGREE = 2.0; % Жесткий паспортный стресс-шум 2 градуса ТИС!
N_MONTE_CARLO    = 5000;

vals = logspace(log10(4), log10(124), 20);
STATION_COUNTS_VECTOR = unique(round(vals));
FIXED_N_STATIONS = STATION_COUNTS_VECTOR(11); % Строго 24 поста ТИС

% Формирование векторов истинной стратегической траектории цели
t_steps = linspace(0, 1, TRAJECTORY_POINTS_COUNT);
x_true = TARGET_X_START + (TARGET_X_FINISH - TARGET_X_START) * t_steps;
y_true = TARGET_Y_STATIC * ones(size(t_steps)); 
z_true = TARGET_Z_STATIC + Z_AMPLITUDE * sin(t_steps * pi);

% Перевод углового шума в радианы (Строго по канону фабрики)
rad_err = (DOA_ERROR_DEGREE * pi) / 180.0;
v_a_max = (rad_err^2) * ones(124, 1); v_b_max = (rad_err^2) * ones(124, 1);

% Развертывание полной измерительной сети 124 постов ТИС кубическим сплайном
t_max = linspace(1, 4, 124);
P_max_matrix = [spline(1:4, STATION_X_ANCHORS, t_max); ...
                spline(1:4, STATION_Y_ANCHORS, t_max); ...
                spline(1:4, STATION_Z_ANCHORS, t_max)];

% Извлечение опорной геометрии 4-х базовых анкеров из корня
P_base_4 = [STATION_X_ANCHORS; STATION_Y_ANCHORS; STATION_Z_ANCHORS];

% Генерация измерительных матриц строго по методике класса-фабрики
alpha_ideal = zeros(124, TRAJECTORY_POINTS_COUNT);
beta_ideal  = zeros(124, TRAJECTORY_POINTS_COUNT);

for i = 1:124
    dx = x_true - P_max_matrix(1, i); dy = y_true - P_max_matrix(2, i); dz = z_true - P_max_matrix(3, i);
    alpha_ideal(i, :) = atan2(dy, dx); 
    beta_ideal(i, :)  = atan2(dz, sqrt(dx.^2 + dy.^2));
end

rng(1337);
noise_alpha = sqrt(v_a_max) .* randn(124, TRAJECTORY_POINTS_COUNT);
noise_beta  = sqrt(v_b_max) .* randn(124, TRAJECTORY_POINTS_COUNT);

alpha_matrix = alpha_ideal + noise_alpha;
beta_matrix  = beta_ideal + noise_beta;

% Накопление независимой mc-пачки шумов в центральной реперной точке
mid_idx = round(TRAJECTORY_POINTS_COUNT / 2);
dx0 = x_true(mid_idx) - P_max_matrix(1, 1:FIXED_N_STATIONS); 
dy0 = y_true(mid_idx) - P_max_matrix(2, 1:FIXED_N_STATIONS); 
dz0 = z_true(mid_idx) - P_max_matrix(3, 1:FIXED_N_STATIONS);

az_mc_vector = atan2(dy0, dx0); el_mc_vector = atan2(dz0, sqrt(dx0.^2 + dy0.^2));

rng(1338);
alpha_mc_raw = az_mc_vector.' + sqrt(v_a_max(1:FIXED_N_STATIONS)) .* randn(FIXED_N_STATIONS, N_MONTE_CARLO);
beta_mc_raw  = el_mc_vector.' + sqrt(v_b_max(1:FIXED_N_STATIONS)) .* randn(FIXED_N_STATIONS, N_MONTE_CARLO);

% Расчет максимального вертикального предела для шкал
[st_f, K_max_crlb] = crlb_covariance(P_base_4, alpha_mc_raw(:,1), beta_mc_raw(:,1), v_a_max(1:4), v_b_max(1:4), [x_true(1); y_true(1); z_true(1)]);
if st_f == 0, max_ylim_km = (sqrt(sum(diag(K_max_crlb))) / 1000) * 1.20; else, max_ylim_km = 300; end

active_solvers = {'lls_position', 'wlls_position', 'gn_position', 'gnp_position'};
method_labels  = {'1. Чистый линейный LLS ТИС', '2. Взвешенный WLLS ТИС', ...
                  '3. Декартов Gauss-Newton ТИС', '4. Полярный инвариант ТИС'};

% ГЛАВНЫЙ ВЫЧИСЛИТЕЛЬНЫЙ КОНВЕЙЕР МНК ТАКТОВ ТРАЕКТОРИИ ТИС
for i = 1:length(active_solvers)
    fh_solver = str2func(active_solvers{i});
    
    fixed_m.X = zeros(1, TRAJECTORY_POINTS_COUNT); fixed_m.Y = zeros(1, TRAJECTORY_POINTS_COUNT);
    P_act = P_max_matrix(:, 1:FIXED_N_STATIONS);
    
    for k = 1:TRAJECTORY_POINTS_COUNT
        [st, lamb] = fh_solver(P_act, alpha_matrix(1:FIXED_N_STATIONS, k), beta_matrix(1:FIXED_N_STATIONS, k), v_a_max(1:FIXED_N_STATIONS), v_b_max(1:FIXED_N_STATIONS));
        if st == 0, fixed_m.X(k) = lamb(1); fixed_m.Y(k) = lamb(2); else, fixed_m.X(k) = NaN; fixed_m.Y(k) = NaN; end
    end
    
    summary_rmse = zeros(1, length(STATION_COUNTS_VECTOR));
    for n_idx = 1:length(STATION_COUNTS_VECTOR)
        N_curr = STATION_COUNTS_VECTOR(n_idx); P_curr = P_max_matrix(:, 1:N_curr);
        rmse_accum = zeros(1, TRAJECTORY_POINTS_COUNT);
        for k = 1:TRAJECTORY_POINTS_COUNT
            [st, lamb] = fh_solver(P_curr, alpha_matrix(1:N_curr, k), beta_matrix(1:N_curr, k), v_a_max(1:N_curr), v_b_max(1:N_curr));
            if st == 0
                rmse_accum(k) = sqrt((lamb(1)-x_true(k))^2 + (lamb(2)-y_true(k))^2 + (lamb(3)-z_true(k))^2);
            else
                rmse_accum(k) = NaN;
            end
        end
        summary_rmse(n_idx) = mean(rmse_accum, 'omitnan');
    end
    
    % =========================================================================
    % 🔬 СКВОЗНАЯ ТРАССИРОВКА ОЗУ ДЛЯ ВСЕХ ЧЕТЫРЕХ МЕТОДОВ ТИС
    % =========================================================================
    fprintf('\n--- ТРАССИРОВКА ОЗУ ДЛЯ МЕТОДА: %s ---\n', active_solvers{i});
    for deb_m = 1:3
        [st_deb, lamb_deb] = fh_solver(P_act, alpha_mc_raw(:, deb_m), beta_mc_raw(:, deb_m), v_a_max(1:FIXED_N_STATIONS), v_b_max(1:FIXED_N_STATIONS));
        if st_deb == 0
            fprintf('Испытание МК %d | Финал МНК: [%.1f; %.1f] км | Cтатус: %d\n', deb_m, lamb_deb(1)/1000, lamb_deb(2)/1000, st_deb);
        else
            fprintf('Испытание МК %d | Финал МНК: [NaN; NaN] км | Cтатус: %d\n', deb_m, st_deb);
        end
    end
    
    mc_y = zeros(1, N_MONTE_CARLO);
    for s = 1:N_MONTE_CARLO
        [st, lamb] = fh_solver(P_act, alpha_mc_raw(:, s), beta_mc_raw(:, s), v_a_max(1:FIXED_N_STATIONS), v_b_max(1:FIXED_N_STATIONS));
        if st == 0, mc_y(s) = lamb(2); else, mc_y(s) = NaN; end
    end
    mc_y = mc_y(~isnan(mc_y));
    
    % ДЛЯ НАГЛЯДНОГО РАСКРЫТИЯ ЧЕТЫРЕХУГОЛЬНИКА КРЕСТА НА СУПЕР-МАСШТАБНОМ ЭКРАНЕ ТИС
    % Масштабируем базовые анкеры в 5 раз строго для графического вывода на Сабплот 1,
    % чтобы треугольники вышли из 20-километровой слепой щели дна графика!
    P_display_krest = P_base_4;
    P_display_krest(1:2, :) = P_base_4(1:2, :) * 5.5; 
    
    % СТРOГO ОРИГИНАЛЬНЫЙ ВЫЗОВ СТРАТЕГИЧЕСКОГО ЭКРАНА
    matplot_trajectory_200km_screen_dynamic(x_true, y_true, P_display_krest, ...
        fixed_m, summary_rmse, mc_y, TARGET_Y_STATIC, method_labels{i}, i, STATION_COUNTS_VECTOR, max_ylim_km);
end
