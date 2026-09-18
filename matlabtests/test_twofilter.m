clear; clc;

% =========================================================================
% 1. ИНИЦИАЛИЗАЦИЯ ИНВАРИАНТОВ И КОНСТАНТ В СТРУКТУРЕ CFG
% =========================================================================
cfg.dt = 3.0;
cfg.t_max = 300.0;
cfg.R_max = 0.5;
cfg.N = 20;
cfg.S = 20; % Настройка кучности от 6 до 20
cfg.POOL_SIZE = 90;
cfg.T_PROLONGATION_MAX = 10.0;
cfg.T_TIMEOUT_CLEAR = 70.0; 
cfg.S_RETURN = 5;
cfg.MODE_NORM = int32(10);
cfg.MODE_BLIND = int32(20);

% Системные и метрологические константы
cfg.X_THRESHOLD_PLATEAU = 20.0;
cfg.BASE_REPER_Y = 10.0;
cfg.BASE_REPER_Z = 10.0;
cfg.X_true_reper = [10.0; 10.0; 10.0];
cfg.TIMER_RESET_MARKER = -100.0;

% Базисные константы для безцифрового программирования ядра
cfg.ZERO_INT = int32(0);
cfg.ZERO_REAL = 0.0;
cfg.INDEX_SHIFT = 1;
cfg.MODE_NORM_MARKER = 1;
cfg.MODE_BLIND_MARKER = 2;
cfg.S_MIN_LIMIT = 6;
cfg.S_MAX_LIMIT = 20;
cfg.STATUS_SUCCESS = 0;
cfg.STATUS_ERR_CONFIG = 1;
cfg.EPSILON_MACHINE = 2.2204e-16;

% =========================================================================
% 2. СТАТИЧЕСКАЯ АЛЛОКАЦИЯ ВНУТРЕННИХ ВЕКТОРОВ КОНТЕКСТА (CTX)
% =========================================================================
ctx.Global_Pool = zeros(cfg.POOL_SIZE, 5);
ctx.pool_head = cfg.ZERO_INT;
ctx.W_main_data = zeros(cfg.N, 1, 'int32');
ctx.W_main_count = cfg.ZERO_INT;
ctx.W_main_head = cfg.ZERO_INT;
ctx.W_alt_data = zeros(cfg.S, 1, 'int32');
ctx.W_alt_count = cfg.ZERO_INT;
ctx.W_alt_head = cfg.ZERO_INT;

ctx.X_current = zeros(3, 1);
ctx.X_main_ref = [10.0; 10.0; 10.0];

ctx.t_last_data_arrival = 100.0;
ctx.t_blind_start = cfg.TIMER_RESET_MARKER;
ctx.is_switched_to_25 = false;

ctx.X_filtered_output = 10.0;
ctx.W_alt_power_output = 0.0;

% =========================================================================
% 3. ВХОДНЫЕ ДАННЫЕ И РЕЗЕРВИРОВАНИЕ ИСТОРИИ
% =========================================================================
t_axes = 0:cfg.dt:cfg.t_max;
n_ticks = length(t_axes);

X_true = 10.0 * ones(1, n_ticks);
X_meas = X_true;
X_meas(t_axes == 30.0) = 40.0;
X_meas(t_axes >= 60.0 & t_axes <= 100.0) = 25.0;
X_meas(t_axes >= 171.0 & t_axes <= 216.0) = 25.0;
X_meas(t_axes == 252.0 | t_axes == 255.0) = 28.0;

drop_mask = t_axes > 100.0 & t_axes < 170.0;
X_meas(drop_mask) = NaN;

X_filtered_history = zeros(n_ticks, 1);
W_alt_power_history = zeros(n_ticks, 1);

% =========================================================================
% 4. ВЫЧИСЛИТЕЛЬНЫЙ ТАКТOВЫЙ КОНВЕЙЕР (ВЫЗОВ ЯДРА FILTER2WIN)
% =========================================================================
for tick = 1:n_ticks
    % Потактовый вызов прецизионной функции
    [status, ctx] = filter2win(cfg, ctx, t_axes(tick), X_meas(tick), drop_mask(tick));
    
    if status ~= cfg.STATUS_SUCCESS
        error('Ошибка конфигурации или крах разрядной сетки ТИС.');
    end
    
    % Логирование состояния
    X_filtered_history(tick) = ctx.X_filtered_output;
    W_alt_power_history(tick) = ctx.W_alt_power_output;
end

% =========================================================================
% 5. АВТОНОМНЫЙ ВЫЗОВ ФУНКЦИИ ОТОБРАЖЕНИЯ ГРАФИКОВ
% =========================================================================
matplot_twofilter_screen(t_axes, X_true, X_meas, X_filtered_history, W_alt_power_history);
