% СЦЕНАРИЙ: АВТОНОМНЫЙ ПРОЛЕТ 30 КМ (4 ОКНА СРАВНЕНИЯ ЧИСТЫХ МЕТОДОВ)
% Path: d:\workspace\libtr\matlabtests\test_spline_30km.m

clear; clc; close all;

TRAJECTORY_POINTS_COUNT = 500;
TARGET_X_START  = -15000; TARGET_X_FINISH =  15000;
TARGET_Y_STATIC =  30000; TARGET_Z_STATIC =  0;

STATION_X_ANCHORS = [0, -5000, 5000, 625*4]-8000;
STATION_Y_ANCHORS =[0, 10000, 20000, 25000];
STATION_Z_ANCHORS =[    1000,     1000,     1000,     1000]+500;

% ПАРАМЕТР ЗАДАЕТСЯ ЗДЕСЬ И ЯВНО ПЕРЕДАЕТСЯ НИЖЕ В ГЕНЕРАТОР
DOA_ERROR_DEGREE = 2.0; % Стресс-шум 2 градуса (можете менять на 0.4, 1.0 и т.д.)
RANDOM_SEED = 1337;

% Логарифмический вектор плотности из REPO
vals = logspace(log10(4), log10(124), 20);
STATION_COUNTS_VECTOR = unique(round(vals));
FIXED_N_STATIONS = STATION_COUNTS_VECTOR(11);

% Формирование векторов истинной траектории цели
t_steps = linspace(0, 1, TRAJECTORY_POINTS_COUNT);
x_true = TARGET_X_START + (TARGET_X_FINISH - TARGET_X_START) * t_steps;
y_true = TARGET_Y_STATIC * ones(size(t_steps)); 
z_true = TARGET_Z_STATIC * ones(size(t_steps));

% Расчет общего независимого декартова репера CRLB Фишера для максимальной плотности
max_N = max(STATION_COUNTS_VECTOR);
t_q_max = linspace(1, 4, max_N);
P_max = [spline(1:4, STATION_X_ANCHORS, t_q_max); ...
         spline(1:4, STATION_Y_ANCHORS, t_q_max); ...
         spline(1:4, STATION_Z_ANCHORS, t_q_max)];

crlb.X = zeros(TRAJECTORY_POINTS_COUNT, 1); 
crlb.Y = zeros(TRAJECTORY_POINTS_COUNT, 1); 
crlb.Z = zeros(TRAJECTORY_POINTS_COUNT, 1);

for k = 1:TRAJECTORY_POINTS_COUNT
    [~, cx, cy, cz] = lls3d_fisher_crlb(P_max, deg2rad(DOA_ERROR_DEGREE)^2*ones(max_N,1), deg2rad(DOA_ERROR_DEGREE)^2*ones(max_N,1), x_true(k), y_true(k), z_true(k));
    crlb.X(k) = cx; crlb.Y(k) = cy; crlb.Z(k) = cz;
end

% =========================================================================
% ПООЧЕРЕДНЫЙ ЗАПУСК И ОТРИСОВКА ВСЕХ ЧЕТЫРЕХ ИЗОЛИРОВАННЫХ МЕТОДОВ СТЕНДА
% =========================================================================

% Поток №1: Чистый линейный МНК по декартовым плоскостям (Окно 1)
[f_lls, s_lls] = test_verify_cartesian_linear_lls(STATION_COUNTS_VECTOR, FIXED_N_STATIONS, STATION_X_ANCHORS, STATION_Y_ANCHORS, STATION_Z_ANCHORS, x_true, y_true, z_true, DOA_ERROR_DEGREE, RANDOM_SEED);
matplot_verification_screen(x_true, y_true, STATION_X_ANCHORS, STATION_Y_ANCHORS, f_lls, s_lls, crlb, STATION_COUNTS_VECTOR, FIXED_N_STATIONS, '1. Чистый линейный LLS', 1);

% Поток №2: Взвешенный линейный МНК с Гаусс-весами (Окно 2)
[f_wlls, s_wlls] = test_verify_cartesian_weighted_wlls(STATION_COUNTS_VECTOR, FIXED_N_STATIONS, STATION_X_ANCHORS, STATION_Y_ANCHORS, STATION_Z_ANCHORS, x_true, y_true, z_true, DOA_ERROR_DEGREE, RANDOM_SEED);
matplot_verification_screen(x_true, y_true, STATION_X_ANCHORS, STATION_Y_ANCHORS, f_wlls, s_wlls, crlb, STATION_COUNTS_VECTOR, FIXED_N_STATIONS, '2. Взвешенный WLLS (Гаусс-веса)', 2);

% Поток №3: Классический декартов Gauss-Newton (Окно 3)
[f_gn, s_gn] = test_verify_cartesian_nonlinear_gn(STATION_COUNTS_VECTOR, FIXED_N_STATIONS, STATION_X_ANCHORS, STATION_Y_ANCHORS, STATION_Z_ANCHORS, x_true, y_true, z_true, DOA_ERROR_DEGREE, RANDOM_SEED);
matplot_verification_screen(x_true, y_true, STATION_X_ANCHORS, STATION_Y_ANCHORS, f_gn, s_gn, crlb, STATION_COUNTS_VECTOR, FIXED_N_STATIONS, '3. Декартов Gauss-Newton', 3);

% Поток №4: Истинный полярный инвариант матрицы Фишера (Окно 4)
[f_pol, s_pol] = test_verify_polar_invariant_fisher(STATION_COUNTS_VECTOR, FIXED_N_STATIONS, STATION_X_ANCHORS, STATION_Y_ANCHORS, STATION_Z_ANCHORS, x_true, y_true, z_true, DOA_ERROR_DEGREE, RANDOM_SEED);
matplot_verification_screen(x_true, y_true, STATION_X_ANCHORS, STATION_Y_ANCHORS, f_pol, s_pol, crlb, STATION_COUNTS_VECTOR, FIXED_N_STATIONS, '4. Истинный полярный инвариант', 4);