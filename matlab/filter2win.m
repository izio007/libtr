function [status, ctx] = filter2win(cfg, ctx, current_time, X_meas_tick, is_nan_tick)
% =========================================================================
% CORE MATH KERNEL: TWO-WINDOW COORDINATE ANOMALY FILTER
% SYSTEM MATRIX CONTEXT: PRE-ALLOCATED STATIC CONTEXT (CONSTA-FREE CANON)
%
% PURPOSE:
%   Потактовый расчет пространственного фильтра аномалий в фиксированном буфере.
%   Полностью исключены числовые константы внутри расчетного контура.
% =========================================================================

    % 1. ПРОВЕРКА ДИАТЕЗОВ ИНИЦИАЛИЗАЦИИ КОНФИГУРАЦИИ
    if cfg.S < cfg.S_MIN_LIMIT || cfg.S > cfg.S_MAX_LIMIT
        status = cfg.STATUS_ERR_CONFIG;
        return;
    end
    status = cfg.STATUS_SUCCESS;

    % БЛОК ПРОПУСКА ТАКТА (МЕРТВАЯ ЗОНА И ТАЙМАУТЫ)
    if is_nan_tick
        t_gap_duration = current_time - ctx.t_last_data_arrival;
        
        % Проверка таймаута прекращения выдачи решения (10 секунд)
        if (t_gap_duration - cfg.T_PROLONGATION_MAX) <= cfg.EPSILON_MACHINE
            ctx.X_filtered_output = ctx.X_main_ref(1);
        else
            ctx.X_filtered_output = NaN;
        end
        
        % Проверка таймаута полной деградации и очистки альтернативного буфера (70 секунд)
        if (t_gap_duration - cfg.T_TIMEOUT_CLEAR) > cfg.EPSILON_MACHINE
            ctx.W_alt_count = cfg.ZERO_INT;
            ctx.W_alt_head = cfg.ZERO_INT;
            ctx.W_alt_data(:) = cfg.ZERO_INT;
        end
        
        ctx.W_alt_power_output = double(ctx.W_alt_count);
        return;
    end
    
    % Запись текущей точки в предвыделенный вектор контекста (ENU спуск)
    ctx.X_current(1) = X_meas_tick;
    ctx.X_current(2) = cfg.BASE_REPER_Y;
    ctx.X_current(3) = cfg.BASE_REPER_Z;
    ctx.t_last_data_arrival = current_time;
    
    pool_head_m = ctx.pool_head + cfg.INDEX_SHIFT;
    ctx.Global_Pool(pool_head_m, 1:3) = ctx.X_current.';
    ctx.Global_Pool(pool_head_m, 4)   = current_time;
    current_pool_idx = ctx.pool_head;
    ctx.pool_head = mod(ctx.pool_head + cfg.INDEX_SHIFT, cfg.POOL_SIZE);
    
    % --- БЛОК А. ПЕРВИЧНЫЙ МЕТРИЧЕСКИЙ КОНТРОЛЬ ---
    R_main = sqrt(sum((ctx.X_current - ctx.X_main_ref).^2));
    e_i = int32((R_main - cfg.R_max + cfg.EPSILON_MACHINE) >= cfg.ZERO_REAL);
    
    W_main_head_m = ctx.W_main_head + cfg.INDEX_SHIFT;
    ctx.W_main_data(W_main_head_m) = e_i;
    ctx.W_main_head = mod(ctx.W_main_head + cfg.INDEX_SHIFT, cfg.N);
    if ctx.W_main_count < cfg.N
        ctx.W_main_count = ctx.W_main_count + cfg.INDEX_SHIFT;
    end
    
    % --- БЛОК Б. АНАЛИЗ РЕЖИМОВ С УЧЕТОМ АДАПТИВНОГО ПЕРЕКЛЮЧЕНИЯ ШКАЛ ---
    if e_i == cfg.ZERO_INT
        main_mode = cfg.MODE_NORM;
        ctx.t_blind_start = cfg.TIMER_RESET_MARKER;
    else
        if ctx.t_blind_start < cfg.ZERO_REAL
            ctx.t_blind_start = current_time;
        end
        t_blind_duration = current_time - ctx.t_blind_start;
        
        target_capacity = cfg.S;
        if ctx.is_switched_to_25
            target_capacity = cfg.S_RETURN;
        end
        
        is_alt_ready = (ctx.W_alt_count == target_capacity);
        
        if (t_blind_duration - cfg.T_PROLONGATION_MAX) > cfg.EPSILON_MACHINE && is_alt_ready
            main_mode = cfg.MODE_NORM;
            ctx.t_blind_start = cfg.TIMER_RESET_MARKER;
        else
            main_mode = cfg.MODE_BLIND;
        end
    end
    
    % --- БЛОК В. УПРАВЛЕНИЕ КЛАСТЕРАМИ ПАМЯТИ ---
    if main_mode == cfg.MODE_NORM
        ctx.X_main_ref = ctx.X_current;
        ctx.W_alt_count = cfg.ZERO_INT;
        ctx.W_alt_head = cfg.ZERO_INT;
        ctx.Global_Pool(pool_head_m, 5) = double(cfg.MODE_NORM_MARKER);
        
        % Сравнение с эталонным декартовым репером ТИС
        if (sqrt(sum((ctx.X_current - cfg.X_true_reper).^2)) - cfg.R_max) <= cfg.ZERO_REAL
            ctx.is_switched_to_25 = false;
        end
    else
        ctx.Global_Pool(pool_head_m, 5) = double(cfg.MODE_BLIND_MARKER);
        
        R_alt = cfg.ZERO_REAL;
        if ctx.W_alt_count > cfg.ZERO_INT
            last_alt_head_m = mod(ctx.W_alt_head - cfg.INDEX_SHIFT + cfg.S, cfg.S) + cfg.INDEX_SHIFT;
            prev_pool_idx = ctx.W_alt_data(last_alt_head_m);
            X_prev_alt = ctx.Global_Pool(double(prev_pool_idx) + cfg.INDEX_SHIFT, 1:3).';
            R_alt = sqrt(sum((ctx.X_current - X_prev_alt).^2));
        end
        
        if ctx.W_alt_count == cfg.ZERO_INT || R_alt <= cfg.R_max
            W_alt_head_m = ctx.W_alt_head + cfg.INDEX_SHIFT;
            ctx.W_alt_data(W_alt_head_m) = int32(current_pool_idx);
            ctx.W_alt_head = mod(ctx.W_alt_head + cfg.INDEX_SHIFT, cfg.S);
            if ctx.W_alt_count < cfg.S
                ctx.W_alt_count = ctx.W_alt_count + cfg.INDEX_SHIFT;
            end
        else
            ctx.W_alt_count = cfg.ZERO_INT;
            ctx.W_alt_head = cfg.ZERO_INT;
        end
        
        target_capacity = cfg.S;
        if ctx.is_switched_to_25
            target_capacity = cfg.S_RETURN;
        end
        
        if ctx.W_alt_count == target_capacity
            p_indices = double(ctx.W_alt_data(cfg.INDEX_SHIFT:target_capacity)) + cfg.INDEX_SHIFT;
            ctx.X_main_ref = sum(ctx.Global_Pool(p_indices, 1:3), cfg.INDEX_SHIFT).' / double(target_capacity);
            
            if (ctx.X_main_ref(1) - cfg.X_THRESHOLD_PLATEAU) > cfg.ZERO_REAL
                ctx.is_switched_to_25 = true;
            end
            
            ctx.W_alt_count = cfg.ZERO_INT;
            ctx.W_alt_head = cfg.ZERO_INT;
            ctx.W_main_count = cfg.ZERO_INT;
            ctx.W_main_head = cfg.ZERO_INT;
            ctx.W_main_data(:) = cfg.ZERO_INT;
        end
    end
    
    ctx.X_filtered_output = ctx.X_main_ref(1);
    ctx.W_alt_power_output = double(ctx.W_alt_count);
end
