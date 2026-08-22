% =========================================================================
% ВЕРИФИКАЦИОННЫЙ СТЕНД: СВЕРХДАЛЬНИЙ СТРЕСС-ТЕСТ (450 КМ) — ФИНАЛЬНАЯ СБОРКА
% Responsibility: Крупномасштабный тест накопления с честной генерацией углов dy
% Path: d:\workspace\libtr\matlabtests\test_trajectory_200km.m
% =========================================================================

clear; clc; close all;

% 1. Конфигурация жесткого креста базы из 4 станций и стресс-шума 2.0°
STATION_POSITIONS_BASE = [-20000, 20000, 0, 0; 0, 0, -20000, 20000; 0, 0, 0, 0];
DOA_ERROR_DEGREE = 5.0; 
M_BASE = 4;
VAR_ALPHA_BASE = deg2rad(DOA_ERROR_DEGREE)^2 * ones(M_BASE, 1);
VAR_BETA_BASE  = deg2rad(DOA_ERROR_DEGREE)^2 * ones(M_BASE, 1);

TRAJECTORY_POINTS_COUNT = 300; % Оптимизировано для скорости пролета цели
N_MONTE_CARLO = 15000;         % Оптимальный объем выборки для анализа скоса моды
y_center_true = 450000;        % ИСТИННЫЙ СТРЕСС-РУБЕЖ: 450 км дальности (без залипаний!)

% Формирование логарифмической сетки накопления измерений (от 4 до 124) строго по REPO
vals = logspace(log10(4), log10(124), 20);
STATION_COUNTS_VECTOR = unique(round(vals));
FIXED_N_STATIONS = STATION_COUNTS_VECTOR(11);

if ~any(STATION_COUNTS_VECTOR == FIXED_N_STATIONS)
    STATION_COUNTS_VECTOR = unique(sort([STATION_COUNTS_VECTOR, FIXED_N_STATIONS]));
end

% Сценарий: дальний пролет на 450 км со сквозной синусоидой высоты Z
t_steps = linspace(0, 1, TRAJECTORY_POINTS_COUNT);
x_true = linspace(-150000, 150000, TRAJECTORY_POINTS_COUNT);
y_true = y_center_true * ones(size(t_steps)); % Честная динамическая дальность 450 км
z_true = 10000 + 5000 * sin(t_steps * pi);

% --- СИНХРОННАЯ ГЕНЕРАЦИЯ: ЕДИНЫЕ МАССИВЫ ВХОДНЫХ ЗАШУМЛЕННЫХ ДАННЫХ ---
L_counts = length(STATION_COUNTS_VECTOR);
max_measurements = max(STATION_COUNTS_VECTOR);

% Предрасчет расширенной геометрии тактов под максимальный лимит сетки
[P_max_exp, V_a_max_exp, V_b_max_exp] = expand_cross_geometry(STATION_POSITIONS_BASE, VAR_ALPHA_BASE, VAR_BETA_BASE, max_measurements);

% Генерация единого траекторного шума (Строго по координатам y_true)
alpha_m_raw = zeros(max_measurements, TRAJECTORY_POINTS_COUNT);
beta_m_raw  = zeros(max_measurements, TRAJECTORY_POINTS_COUNT);
rng(1337); % Идентичные зашумленные пеленги для всех четырех ядер МНК
for k = 1:TRAJECTORY_POINTS_COUNT
    for i = 1:max_measurements
        dx = x_true(k) - P_max_exp(1, i); 
        dy = y_true(k) - P_max_exp(2, i); % ИСПРАВЛЕНО: Строго 450 км пролета
        dz = z_true(k) - P_max_exp(3, i);
        alpha_m_raw(i, k) = atan2(dy, dx) + sqrt(V_a_max_exp(i)) * randn();
        beta_m_raw(i, k)  = atan2(dz, sqrt(dx^2 + dy^2)) + sqrt(V_b_max_exp(i)) * randn();
    end
end

% Генерация единого массива статического Монте-Карло для фиксированных 107 измерений в центре
[P_exp_mc, V_a_mc, V_b_mc] = expand_cross_geometry(STATION_POSITIONS_BASE, VAR_ALPHA_BASE, VAR_BETA_BASE, FIXED_N_STATIONS);
alpha_mc_raw = zeros(FIXED_N_STATIONS, N_MONTE_CARLO);
beta_mc_raw  = zeros(FIXED_N_STATIONS, N_MONTE_CARLO);
for s = 1:N_MONTE_CARLO
    for i = 1:FIXED_N_STATIONS
        dx = 0 - P_exp_mc(1, i); 
        dy = y_center_true - P_exp_mc(2, i); % ИСПРАВЛЕНО: Строго 450 км статики
        dz = 10000 - P_exp_mc(3, i);
        alpha_mc_raw(i, s) = atan2(dy, dx) + sqrt(V_a_mc(i)) * randn();
        beta_mc_raw(i, s)  = atan2(dz, sqrt(dx^2 + dy^2)) + sqrt(V_b_mc(i)) * randn();
    end
end

all_summaries = cell(4, 1);
all_fixed = cell(4, 1);
all_mc = cell(4, 1);
method_names = {'1. Чистый линейный LLS', '2. Взвешенный WLLS', '3. Декартов Gauss-Newton (6 итераций)', '4. Полярный инвариант (6 итераций)'};

% =========================================================================
% ВЫЧИСЛИТЕЛЬНЫЙ ЦИКЛ ОБРАБОТКИ МЕТОДОВ ЯДРА
% =========================================================================
for SELECT_METHOD = 1:4
    summary.rmse = zeros(L_counts, 1);
    fixed.pos = zeros(3, TRAJECTORY_POINTS_COUNT);
    fixed.std_Y = zeros(TRAJECTORY_POINTS_COUNT, 1);
    
    for s_idx = 1:L_counts
        N_TOTAL = STATION_COUNTS_VECTOR(s_idx);
        P_curr = P_max_exp(:, 1:N_TOTAL);
        V_a_curr = V_a_max_exp(1:N_TOTAL); V_b_curr = V_b_max_exp(1:N_TOTAL);
        
        results_pos = zeros(3, TRAJECTORY_POINTS_COUNT);
        status = zeros(1, TRAJECTORY_POINTS_COUNT);
        
        for k = 1:TRAJECTORY_POINTS_COUNT
            alpha_m = alpha_m_raw(1:N_TOTAL, k);
            beta_m  = beta_m_raw(1:N_TOTAL, k);
            
            if SELECT_METHOD == 1
                [st, lambda] = lls3d_position(P_curr, alpha_m, beta_m);
            elseif SELECT_METHOD == 2
                W_df = [1./V_a_curr; 1./V_b_curr]; W_df = W_df / norm(W_df);
                [st, lambda] = wlls3d_position(P_curr, alpha_m, beta_m, W_df);
            elseif SELECT_METHOD == 3
                [st, lambda] = gn3d_position(P_curr, alpha_m, beta_m);
            else
                [st, lambda] = gn3d_position_polar(P_curr, alpha_m, beta_m);
            end
            status(k) = st;
            if st == 0, results_pos(:, k) = lambda; end
        end
        
        mask = (status == 0);
        if any(mask)
            err_x = results_pos(1, mask) - x_true(mask); 
            err_y = results_pos(2, mask) - y_true(mask); 
            err_z = results_pos(3, mask) - z_true(mask);
            summary.rmse(s_idx) = sqrt(mean(err_x.^2 + err_y.^2 + err_z.^2));
        end
        if N_TOTAL == FIXED_N_STATIONS
            fixed.pos = results_pos;
            fixed.STATION_POSITIONS = P_curr;
        end
    end
    
    % Высокоскоростной расчет статического Монте-Карло 15 000 итераций
    mc_y = zeros(N_MONTE_CARLO, 1);
    for s = 1:N_MONTE_CARLO
        a_mc = alpha_mc_raw(:, s); b_mc = beta_mc_raw(:, s);
        if SELECT_METHOD == 1,     [st, lambda] = lls3d_position(P_exp_mc, a_mc, b_mc);
        elseif SELECT_METHOD == 2, W_df = [1./V_a_mc; 1./V_b_mc]; W_df = W_df / norm(W_df); [st, lambda] = wlls3d_position(P_exp_mc, a_mc, b_mc, W_df);
        elseif SELECT_METHOD == 3, [st, lambda] = gn3d_position(P_exp_mc, a_mc, b_mc);
        else                       [st, lambda] = gn3d_position_polar(P_exp_mc, a_mc, b_mc); end
        if st == 0, mc_y(s) = lambda(2); end
    end
    
    all_summaries{SELECT_METHOD} = summary;
    all_fixed{SELECT_METHOD} = fixed;
    all_mc{SELECT_METHOD} = mc_y;
end

% =========================================================================
% ОПРЕДЕЛЕНИЕ ЕДИНОГО ЖЕСТКОГО ПРЕДЕЛА ШКАЛЫ ПО ТЕОРЕТИЧЕСКОМУ CRLB (N=4)
% =========================================================================
VAR_ALPHA_BASE_4 = deg2rad(DOA_ERROR_DEGREE)^2 * ones(4, 1);
VAR_BETA_BASE_4  = deg2rad(DOA_ERROR_DEGREE)^2 * ones(4, 1);
[~, cx, cy, cz] = lls3d_fisher_crlb(STATION_POSITIONS_BASE, VAR_ALPHA_BASE_4, VAR_BETA_BASE_4, 0, y_center_true, 10000);
crlb_max_limit = sqrt(cx^2 + cy^2 + cz^2);

% Фиксируем верхнюю границу шкалы Global RMSE в км на базе предела Рао-Крамера (+20% запас)
max_ylim_km = (crlb_max_limit / 1000) * 1.20;

% =========================================================================
% ОДНОВРЕМЕННЫЙ МОЗАИЧНЫЙ ВЫВОД НА ЭКРАН В ФОРМАТЕ 2х2
% =========================================================================
for m_idx = 1:4
    clear plot_pos;
    plot_pos.X = all_fixed{m_idx}.pos(1, :);
    plot_pos.Y = all_fixed{m_idx}.pos(2, :);
    
    matplot_trajectory_200km_screen_dynamic(...
        x_true, y_true, STATION_POSITIONS_BASE, plot_pos, all_summaries{m_idx}.rmse, ...
        all_mc{m_idx}, y_center_true, method_names{m_idx}, m_idx, STATION_COUNTS_VECTOR, max_ylim_km);

end

function [P_exp, V_a_exp, V_b_exp] = expand_cross_geometry(P_base, V_a_base, V_b_base, N_total)
    % Алгоритм циклического набора избыточных временных тактов с фиксированного креста
    P_exp = zeros(3, N_total);
    V_a_exp = zeros(N_total, 1); V_b_exp = zeros(N_total, 1);
    for idx = 1:N_total
        base_idx = mod(idx - 1, 4) + 1;
        P_exp(:, idx) = P_base(:, base_idx);
        V_a_exp(idx) = V_a_base(base_idx);
        V_b_exp(idx) = V_b_base(base_idx);
    end
end
