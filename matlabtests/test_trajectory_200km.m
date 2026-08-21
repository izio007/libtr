% =========================================================================
% СЦЕНАРИЙ ИСПЫТАНИЙ: ДАЛЬНИЙ ПРОЛЕТ 300 КМ (АВТОНОМНЫЙ КРЕСТ С МОНТЕ-КАРЛО)
% Responsibility: Автономная верификация метода GN на сверхдальней трассе
% Path: d:\workspace\libtr\matlabtests\test_trajectory_200km.m
% =========================================================================

clear; clc; close all;
addpath('d:\workspace\libtr\matlab\');

% 1. Конфигурация сценария (Строго по физике вашего REPO)
TRAJECTORY_POINTS_COUNT = 500;
TARGET_X_START  = -150000; % Пролет 300 км (от -150 до +150 км)
TARGET_X_FINISH =  150000;
TARGET_Y_STATIC =  200000; % Удаление траверза 200 км

% Жесткий крест из 4-х базовых станций на удалениях +-20 км
STATION_POSITIONS = [-20000, 20000, 0, 0; ...
                     0, 0, -20000, 20000; ...
                     0, 0, 0, 0];

DOA_ERROR_DEGREE = 2.0; % Экстремальный шум 2 градуса
N_STATIONS = size(STATION_POSITIONS, 2);
RANDOM_SEED = 1337;

% Сетка плотности для сходимости (в данном сценарии константна, так как база фиксирована)
STATION_COUNTS_VECTOR =4; 
FIXED_N_STATIONS = 4;

% Инициализация дисперсий шума
VAR_ALPHA = deg2rad(DOA_ERROR_DEGREE)^2 * ones(N_STATIONS, 1);
VAR_BETA  = deg2rad(DOA_ERROR_DEGREE)^2 * ones(N_STATIONS, 1);

% ГЕНЕРАЦИЯ ТРАЕКТОРИИ (Синусоидальный подъем по высоте Z от 10 до 15 км)
t_steps = linspace(0, 1, TRAJECTORY_POINTS_COUNT);
x_true = TARGET_X_START + (TARGET_X_FINISH - TARGET_X_START) * t_steps;
y_true = TARGET_Y_STATIC * ones(size(t_steps));
z_true = 10000 + 5000 * sin(t_steps * pi);

% Буферы для накопления результатов пролета
fixed.pos = zeros(3, TRAJECTORY_POINTS_COUNT);
fixed.std_X = zeros(TRAJECTORY_POINTS_COUNT, 1);
fixed.std_Y = zeros(TRAJECTORY_POINTS_COUNT, 1);
fixed.std_Z = zeros(TRAJECTORY_POINTS_COUNT, 1);
fixed.STATION_POSITIONS = STATION_POSITIONS;

crlb.X = zeros(TRAJECTORY_POINTS_COUNT, 1);
crlb.Y = zeros(TRAJECTORY_POINTS_COUNT, 1);
crlb.Z = zeros(TRAJECTORY_POINTS_COUNT, 1);

summary.rmse = 0; summary.mean_miss = 0; summary.max_miss = 0; summary.bias_y = 0;

% =========================================================================
% ВЫЧИСЛИТЕЛЬНЫЙ ЦИКЛ ПО ТРАЕКТОРИИ
% =========================================================================
rng(RANDOM_SEED);

for k = 1:TRAJECTORY_POINTS_COUNT
    % 1. Генерируем чистый репер границы Рао-Крамера со знанием дальности
    [st_f, cx, cy, cz] = lls3d_fisher_crlb(STATION_POSITIONS, VAR_ALPHA, VAR_BETA, x_true(k), y_true(k), z_true(k));
    if st_f == 0
        crlb.X(k) = cx; crlb.Y(k) = cy; crlb.Z(k) = cz;
    end
    
    % 2. Моделирование физических измерений углов с большим шумом
    alpha_m = zeros(N_STATIONS, 1); beta_m = zeros(N_STATIONS, 1);
    for i = 1:N_STATIONS
        dx = x_true(k) - STATION_POSITIONS(1, i);
        dy = y_true(k) - STATION_POSITIONS(2, i);
        dz = z_true(k) - STATION_POSITIONS(3, i);
        r_xy = sqrt(dx^2 + dy^2);
        alpha_m(i) = atan2(dy, dx) + sqrt(VAR_ALPHA(i)) * randn();
        beta_m(i)  = atan2(dz, r_xy) + sqrt(VAR_BETA(i)) * randn();
    end
    
    % 3. Вызовы атомарных нелинейных ядер обработки (Gauss-Newton)
    [st_p, lambda] = gn3d_position(STATION_POSITIONS, alpha_m, beta_m);
    if st_p == 0
        fixed.pos(:, k) = lambda;
        [st_c, sx, sy, sz] = gn3d_covariance(STATION_POSITIONS, VAR_ALPHA, VAR_BETA, lambda);
        if st_c == 0
            fixed.std_X(k) = sx; fixed.std_Y(k) = sy; fixed.std_Z(k) = sz;
        end
    end
end

% Расчет итоговой статистики пролета для векторов сходимости (заглушка для совместимости)
err_x = fixed.pos(1, :) - x_true; err_y = fixed.pos(2, :) - y_true; err_z = fixed.pos(3, :) - z_true;
absolute_miss = sqrt(err_x.^2 + err_y.^2 + err_z.^2);
summary.rmse = sqrt(mean(err_x.^2 + err_y.^2 + err_z.^2));
summary.mean_miss = mean(absolute_miss);
summary.max_miss = max(absolute_miss);
summary.bias_y = mean(err_y);

% =========================================================================
% ВЫЗОВ УТВЕРЖДЕННОГО ГРАФИЧЕСКОГО ДВИЖКА (ВЫВОДИТ ТЕ ЖЕ 4 САБПЛОТА)
% =========================================================================
% Передаем фиктивные STATION_X/Y_ANCHORS для отрисовки базовых линий
STATION_X_ANCHORS = STATION_POSITIONS(1, :);
STATION_Y_ANCHORS = STATION_POSITIONS(2, :);

matplot_verification_screen(x_true, y_true, STATION_X_ANCHORS, STATION_Y_ANCHORS, fixed, summary, crlb, STATION_COUNTS_VECTOR, FIXED_N_STATIONS, 'Gauss-Newton (Дальний пролет 300 км)');

% Отдельный вывод таблицы в консоль
fprintf('\n=== РЕЗУЛЬТАТЫ ДАЛЬНЕГО ТРАЕКТОРНОГО ТЕСТА (300 км) ===\n');
fprintf('RMSE промаха: %.2f м | Средний промах: %.2f м | Систематический Bias Y: %.2f м\n', summary.rmse, summary.mean_miss, summary.bias_y);
