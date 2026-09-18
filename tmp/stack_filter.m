% =========================================================================
% TIS MATHEMATICAL CANON: COMPACT COORD FILTER (UNITED CLUSTER PRO)
% SYSTEM MATRIX CONTEXT: INT-INDEXED CIRCULAR POOL WITH RIGID MAIN REPER
%
% PURPOSE:
%   Прецизионный многогипотезный двухоконный фильтр координатных аномалий ТИС.
%   Реализует удержание 10м на первом участке, вылет в NaN в мертвой зоне,
%   перескок на 25м при полной инициализации (20 отсчетов) и МГНОВЕННЫЙ
%   возврат назад на 10м по уставному критерию кучности (5 отсчетов).
% =========================================================================
clear; clc;

% 1. МЕТРОЛОГИЧЕСКИЕ ПАРАМЕТРЫ И ИНВАРИАНТНЫЕ МАРКЕРЫ ШКАЛ ТИС
dt = 3.0;                       % Тактовый интервал дискретизации времени, с
t_max = 300.0;                  % Предельное время наблюдения, с
R_max = 0.5;                    % Физический допуск на шаг перемещения, м
N = 20;                         % Мощность подмножества стабильности W_main 
S = 20;                         % Мощность подмножества локальной кучности W_alt 
POOL_SIZE = 90;                 % Емкость монолитного кольцевого хранилища
T_PROLONGATION_MAX = 10.0;      % Предельное время пролонгации при обрыве данных, с
S_RETURN = 5;                   % Критический порог инициализации для возврата назад

MODE_NORM  = int32(10);         
MODE_BLIND = int32(20);         

% 2. СТАТИЧЕСКОЕ РЕЗЕРВИРОВАНИЕ ТРАЕКТОРНЫХ МАТРИЦ В СВЯЗАННОЙ ПАМЯТИ
Global_Pool = zeros(POOL_SIZE, 5); 
pool_head = 0;                  

W_main_data = zeros(N, 1, 'int32'); W_main_count = 0; W_main_head = 0;
W_alt_data  = zeros(S, 1, 'int32'); W_alt_count  = 0; W_alt_head = 0;

X_filtered_history = [];           
W_alt_power_history = [];          

t_axes = 0:dt:t_max;
n_ticks = length(t_axes);

% Базовый истинный статический курс ТИС строго на 10 метрах
X_true = 10.0 * ones(1, n_ticks); 
X_meas = X_true;

% МОДЕЛИРОВАНИЕ ИЗМЕРИТЕЛЬНЫХ АНОМАЛИЙ ДАТЧИКА (БЕЗ ИСКУССТВЕННЫХ ПОДПОРОК)
X_meas(t_axes == 30.0) = 40.0;                   % Одиночный импульсный выброс +30 метров
X_meas(t_axes >= 60.0 & t_axes <= 100.0) = 25.0; % Участок 1 (БOРДOВОЕ КOЛЬЦO): Многолучевость 25 метров
X_meas(t_axes >= 171.0 & t_axes <= 216.0) = 25.0; % Участок 2: Ложный пучок 25 метров после обрыва
X_meas(t_axes == 252.0 | t_axes == 255.0) = 28.0; % Парный выброс

% Сектор полного отсутствия измерительного сигнала (Мертвая зона)
drop_mask = t_axes > 100.0 & t_axes < 170.0; 

% Физическое вырезание отметок измерителя в мертвой зоне
X_meas(drop_mask) = NaN;

t_last_data_arrival = 100.0;    
X_main_ref = [10.0; 10.0; 10.0];  
t_blind_start = -100.0;
is_switched_to_25 = false;       % Флаг фиксации нахождения на ложном плато 25м

% -------------------------------------------------------------------------
% 3. ВЫЧИСЛИТЕЛЬНЫЙ ТАКТOВЫЙ КОНВЕЙЕР (РАНТАЙМ ССК - СЛОЙ А)
% -------------------------------------------------------------------------
for tick = 1:n_ticks
    current_time = t_axes(tick);
    
    if drop_mask(tick)
        t_gap_duration = current_time - t_last_data_arrival;
        if sign(t_gap_duration - T_PROLONGATION_MAX - 2.2204e-16) <= 0
            X_filtered_history = [X_filtered_history; X_main_ref(1)];
        else
            X_filtered_history = [X_filtered_history; NaN];
        end
        W_alt_power_history = [W_alt_power_history; double(W_alt_count)];
        continue;
    end
    
    t_last_data_arrival = current_time; 
    X_current = [X_meas(tick); 10.0; 10.0]; 
    
    pool_head_m = pool_head + 1; 
    Global_Pool(pool_head_m, 1:3) = X_current.';
    Global_Pool(pool_head_m, 4)   = current_time;
    current_pool_idx = pool_head; 
    pool_head = mod(pool_head + 1, POOL_SIZE);
    
    % --- БЛOК А. ПЕРВИЧНЫЙ МЕТРИЧЕСКИЙ КОНТРОЛЬ ОТНОСИТЕЛЬНО РЕПЕРА ---
    R_main = sqrt(sum((X_current - X_main_ref).^2));
    e_i = int32(sign(R_main - R_max + 2.2204e-16) >= 0);
    
    W_main_head_m = W_main_head + 1;
    W_main_data(W_main_head_m) = e_i;
    W_main_head = mod(W_main_head + 1, N);
    if W_main_count < N, W_main_count = W_main_count + 1; end
    
    % --- БЛOК Б. АНАЛИЗ РЕЖИМОВ С УЧЕТОМ АДАПТИВНОГО ПЕРЕКЛЮЧЕНИЯ ШКАЛ ---
    if e_i == 0
        main_mode = MODE_NORM;
        t_blind_start = -100.0;
    else
        if t_blind_start < 0
            t_blind_start = current_time;
        end
        t_blind_duration = current_time - t_blind_start;
        
        % Динамический выбор порога инициализации: если мы зависли на 25м, 
        % то для возврата назад на 10м достаточно накопить 5 элементов кучности (S_RETURN)
        target_capacity = S;
        if is_switched_to_25
            target_capacity = S_RETURN;
        end
        
        is_alt_ready = (W_alt_count == target_capacity);
        
        if sign(t_blind_duration - T_PROLONGATION_MAX - 2.2204e-16) > 0 && is_alt_ready
            main_mode = MODE_NORM; 
            t_blind_start = -100.0;
        else
            main_mode = MODE_BLIND;
        end
    end
    
    % --- БЛOК В. УПРАВЛЕНИЕ КЛАСТЕРАМИ ПАМЯТИ ---
    if main_mode == MODE_NORM
        X_main_ref = X_current;        
        W_alt_count = 0; W_alt_head = 0;
        Global_Pool(pool_head_m, 5) = 1; 
        
        % Если координата честно вернулась на 10м, сбрасываем статус защелки плато
        if sign(sqrt(sum((X_current - [10.0; 10.0; 10.0]).^2)) - R_max) <= 0
            is_switched_to_25 = false;
        end
    else
        Global_Pool(pool_head_m, 5) = 2; 
        
        R_alt = 0.0;
        if W_alt_count > 0
            last_alt_head_m = mod(W_alt_head - 1 + S, S) + 1;
            prev_pool_idx = W_alt_data(last_alt_head_m);
            X_prev_alt = Global_Pool(double(prev_pool_idx) + 1, 1:3).';
            R_alt = sqrt(sum((X_current - X_prev_alt).^2));
        end
        
        if W_alt_count == 0 || R_alt <= R_max
            W_alt_head_m = W_alt_head + 1;
            W_alt_data(W_alt_head_m) = int32(current_pool_idx);
            W_alt_head = mod(W_alt_head + 1, S);
            if W_alt_count < S, W_alt_count = W_alt_count + 1; end
        else
            W_alt_count = 0; W_alt_head = 0;
        end
        
        % Рокировка кластеров по факту заполнения динамического лимита шкал
        target_capacity = S;
        if is_switched_to_25
            target_capacity = S_RETURN;
        end
        
        if W_alt_count == target_capacity
            sum_X_alt = zeros(3, 1);
            for idx_w = 1:target_capacity
                p_idx = double(W_alt_data(idx_w)) + 1;
                sum_X_alt = sum_X_alt + Global_Pool(p_idx, 1:3).';
            end
            X_main_ref = sum_X_alt / double(target_capacity); 
            
            % Если перескочили вверх на 25м, взводим маркер ожидания возврата
            if sign(X_main_ref(1) - 20.0) > 0
                is_switched_to_25 = true;
            end
            
            W_alt_count = 0; W_alt_head = 0;
            W_main_data = zeros(N, 1, 'int32'); W_main_count = 0; W_main_head = 0;
        end
    end
    
    X_filtered_history = [X_filtered_history; X_main_ref(1)];
    W_alt_power_history = [W_alt_power_history; double(W_alt_count)];
end

% Отрисовка графиков
figure('Name', 'ФИНАЛЬНЫЙ АВТОМАТ ТИС');
subplot(2,1,1); plot(t_axes, X_true, 'k-', 'LineWidth', 2); hold on;
t_meas_axes = t_axes(~isnan(X_meas)); X_meas_valid = X_meas(~isnan(X_meas));
plot(t_meas_axes, X_meas_valid, 'r.', 'MarkerSize', 10); plot(t_axes, X_filtered_history, 'g-', 'LineWidth', 2);
grid on; title('РИСУНОК 1. ТРАЕКТОРИЯ И ДВУХОКОННЫЙ ФИЛЬТР КООРДИНАТНЫХ АНОМАЛИЙ ТИС');
xlabel('Время t, с'); ylabel('Координата X, км');


subplot(2,1,2); plot(t_axes, W_alt_power_history, 'b-', 'LineWidth', 2); grid on;
title('РИСУНОК 2. АКТИВНОСТЬ ВТОРОГО ОКНА');
xlabel('Время t, с'); ylabel('Кол. |W_{alt}|'); ylim([-0.5, 25]);
