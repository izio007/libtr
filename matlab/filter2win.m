function [status, ctx] = filter2win(cfg, ctx, current_time, X_meas_tick, is_nan_tick)
% FILTER2WIN Расчет пространственного фильтра координатных аномалий ТИС
% Вычислительный контур оперирует операторами скользящей очереди FIFO.

    status = cfg.STATUS_SUCCESS;

    % БЛОК ПРОПУСКА ТАКТА (МЕРТВАЯ ЗОНА И ТАЙМАУТЫ)
    if is_nan_tick
        t_gap_duration = current_time - ctx.T_LAST_DATA_ARRIVAL;
        
        if (t_gap_duration - cfg.T_PROLONGATION_MAX) <= cfg.EPSILON_MACHINE
            ctx.X_FILTERED_OUTPUT = ctx.X_MAIN_REF(1);
        else
            ctx.X_FILTERED_OUTPUT = NaN;
            [ctx.W_ALT_COUNT, ctx.W_ALT_DATA] = fifo_clear(cfg.S, ctx.W_ALT_DATA);
        end
        
        if (t_gap_duration - cfg.T_TIMEOUT_CLEAR) > cfg.EPSILON_MACHINE
            [ctx.W_ALT_COUNT, ctx.W_ALT_DATA] = fifo_clear(cfg.S, ctx.W_ALT_DATA);
        end
        
        ctx.W_ALT_POWER_OUTPUT = double(ctx.W_ALT_COUNT);
        return;
    end
    
    ctx.X_CURRENT(1) = X_meas_tick;
    ctx.X_CURRENT(2) = cfg.BASE_REPER_Y;
    ctx.X_CURRENT(3) = cfg.BASE_REPER_Z;
    ctx.T_LAST_DATA_ARRIVAL = current_time;
    
    pool_head_m = ctx.POOL_HEAD + cfg.INDEX_SHIFT;
    ctx.GLOBAL_POOL(pool_head_m, 1:3) = ctx.X_CURRENT.';
    ctx.GLOBAL_POOL(pool_head_m, 4)   = current_time;
    CURRENT_POOL_IDX = ctx.POOL_HEAD;
    ctx.POOL_HEAD = mod(ctx.POOL_HEAD + cfg.INDEX_SHIFT, cfg.POOL_SIZE);
    
    R_main = sqrt(sum((ctx.X_CURRENT - ctx.X_MAIN_REF).^2));
    e_i = int32((R_main - cfg.R_MAX + cfg.EPSILON_MACHINE) >= cfg.ZERO_REAL);
    
    [ctx.W_MAIN_COUNT, ctx.W_MAIN_DATA] = fifo_push(ctx.W_MAIN_COUNT, cfg.N, ctx.W_MAIN_DATA, e_i);
    
    target_capacity = int32(cfg.S);
    if ctx.IS_SWITCHED_TO_25
        target_capacity = int32(cfg.S_RETURN);
    end
    is_alt_ready = (ctx.W_ALT_COUNT == target_capacity);
    
    % --- БЛОК Б. УПРАВЛЕНИЕ РЕЖИМАМИ АВТОМАТА ---
    if e_i == cfg.ZERO_INT
        main_mode = cfg.MODE_NORM;
        ctx.T_BLIND_START = cfg.TIMER_RESET_MARKER;
    else
        if ctx.T_BLIND_START < cfg.ZERO_REAL
            ctx.T_BLIND_START = current_time;
        end
        
        if is_alt_ready
            main_mode = cfg.MODE_NORM;
            ctx.T_BLIND_START = cfg.TIMER_RESET_MARKER;
        else
            main_mode = cfg.MODE_BLIND;
        end
    end
    
    % --- БЛОК В. УПРАВЛЕНИЕ КЛАСТЕРАМИ ПАМЯТИ ---
    if main_mode == cfg.MODE_NORM
        if is_alt_ready
            p_indices = double(ctx.W_ALT_DATA(cfg.INDEX_SHIFT:double(target_capacity))) + cfg.INDEX_SHIFT;
            ctx.X_MAIN_REF = sum(ctx.GLOBAL_POOL(p_indices, 1:3), cfg.INDEX_SHIFT).' / double(target_capacity);
            
            if (ctx.X_MAIN_REF(1) - cfg.X_THRESHOLD_PLATEAU) > cfg.ZERO_REAL
                ctx.IS_SWITCHED_TO_25 = true;
            end
            [ctx.W_MAIN_COUNT, ctx.W_MAIN_DATA] = fifo_clear(cfg.N, ctx.W_MAIN_DATA);
        else
            ctx.X_MAIN_REF = ctx.X_CURRENT;
        end
        
        [ctx.W_ALT_COUNT, ctx.W_ALT_DATA] = fifo_clear(cfg.S, ctx.W_ALT_DATA);
        
        if (sqrt(sum((ctx.X_CURRENT - cfg.X_TRUE_REPER).^2)) - cfg.R_MAX) <= cfg.ZERO_REAL
            ctx.IS_SWITCHED_TO_25 = false;
        end
    else
        ctx.GLOBAL_POOL(pool_head_m, 5) = double(cfg.MODE_BLIND_MARKER);
        
        is_in_neighborhood = false;
        
        if ctx.W_ALT_COUNT == cfg.ZERO_INT
            is_in_neighborhood = true;
        elseif ctx.IS_SWITCHED_TO_25
            R_to_base = sqrt(sum((ctx.X_CURRENT - cfg.X_TRUE_REPER).^2));
            if R_to_base <= cfg.R_MAX
                is_in_neighborhood = true;
            end
        else
            sum_x_alt = cfg.ZERO_REAL;
            for idx_w = cfg.INDEX_SHIFT:double(ctx.W_ALT_COUNT)
                p_idx = double(ctx.W_ALT_DATA(idx_w)) + cfg.INDEX_SHIFT;
                sum_x_alt = sum_x_alt + ctx.GLOBAL_POOL(p_idx, 1);
            end
            X_mean_alt = sum_x_alt / double(ctx.W_ALT_COUNT);
            R_alt = abs(ctx.X_CURRENT(1) - X_mean_alt);
            
            if R_alt <= cfg.R_ALT_MAX
                is_in_neighborhood = true;
            end
        end
        
        if is_in_neighborhood
            [ctx.W_ALT_COUNT, ctx.W_ALT_DATA] = fifo_push(ctx.W_ALT_COUNT, cfg.S, ctx.W_ALT_DATA, CURRENT_POOL_IDX);
        else
            [ctx.W_ALT_COUNT, ctx.W_ALT_DATA] = fifo_clear(cfg.S, ctx.W_ALT_DATA);
        end
    end
    
    if main_mode == cfg.MODE_BLIND
        t_blind_duration = current_time - ctx.T_BLIND_START;
        if (t_blind_duration - cfg.T_PROLONGATION_MAX) <= cfg.EPSILON_MACHINE
            ctx.X_FILTERED_OUTPUT = ctx.X_MAIN_REF(1);
        else
            ctx.X_FILTERED_OUTPUT = NaN;
        end
    else
        ctx.X_FILTERED_OUTPUT = ctx.X_MAIN_REF(1);
    end
    
    ctx.W_ALT_POWER_OUTPUT = double(ctx.W_ALT_COUNT);
end
