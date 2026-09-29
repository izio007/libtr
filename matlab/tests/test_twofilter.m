clear; clc;
% Parameters belong to the scalar filter, truth is only a test reference.
cfg=struct('N',20,'S',6,'R_MAX',5,'R_ALT_MAX',6, ...
    'T_PROLONGATION_MAX',15,'T_TIMEOUT_CLEAR',70,'V',0, ...
    'DT',3,'T_MAX',300,'STATUS_SUCCESS',0);
ctx=struct('X_MAIN_REF',10);

% 3. ВХОДНЫЕ ДАННЫЕ И МОДЕЛИРОВАНИЕ ИЗМЕРИТЕЛЬНОГО ШУМА
t_axes = 0:cfg.DT:cfg.T_MAX;
n_ticks = length(t_axes);

X_true = 10.0 * ones(1, n_ticks);
X_meas = X_true;
X_meas(t_axes == 30.0) = 40.0;
X_meas(t_axes >= 60.0 & t_axes <= 100.0) = 25.0;
X_meas(t_axes >= 171.0 & t_axes <= 216.0) = 25.0;
X_meas(t_axes == 252.0 | t_axes == 255.0) = 28.0;

% Масштабированное зашумление измерительного тракта датчика
noise = 4.0 * rand(size(X_meas)) - 2.0;
X_meas = X_meas + noise;

drop_mask = t_axes > 100.0 & t_axes < 170.0;
X_meas(drop_mask) = NaN;

X_filtered_history = zeros(n_ticks, 1);
W_alt_power_history = zeros(n_ticks, 1);

% 4. ВЫЧИСЛИТЕЛЬНЫЙ ТАКТOВЫЙ КОНВЕЙЕР
for tick = 1:n_ticks
    [status, ctx] = filter2win(cfg, ctx, t_axes(tick), X_meas(tick), drop_mask(tick));

    if status ~= cfg.STATUS_SUCCESS
        error('Ошибка конфигурации или крах разрядной сетки ТИС.');
    end

    X_filtered_history(tick) = ctx.X_FILTERED_OUTPUT;
    W_alt_power_history(tick) = ctx.W_ALT_POWER_OUTPUT;
end

% 5. АВТОНОМНЫЙ ВЫЗОВ ФУНКЦИИ ОТОБРАЖЕНИЯ ГРАФИКОВ
matplot_twofilter_screen(t_axes, X_true, X_meas, X_filtered_history, W_alt_power_history);
