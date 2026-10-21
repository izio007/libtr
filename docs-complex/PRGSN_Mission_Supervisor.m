function [Mission_Status, Trigger_ABORT, State_next] = PRGSN_Mission_Supervisor(State_curr, N_la_k, Error_geom, K_lambda)
% ЛОГИЧЕСКИЙ СУПЕРВИЗОР АВТОНОМНОГО ПРИНЯТИЯ РЕШЕНИЙ ПРГСН
%
% ВХОДНЫЕ ПАРАМЕТРЫ:
%   State_curr - Текущее состояние формуляра (включая .t_last_active, .t_last_pack)
%   N_la_k     - Навигация ЛА: .X, .Y, .Z, .Vx, .Vy, .Vz, .time
%   Error_geom - Текущая среднегеометрическая невязка промаха (дальность до ИИ)
%   K_lambda   - Декартова ковариационная матрица ошибок триангуляции (3х3)
%
% ВЫХОДНЫЕ ПАРАМЕТРЫ:
%   Mission_Status - Текстовый статус ('MISSION_CONFIRMED' / 'MISSION_ABORTED')
%   Trigger_ABORT  - Логический флаг для САУ (0 - летим на цель, 1 - уходим на след. точку)
%   State_next     - Обновленная память таймеров

    %% Инициализация
    State_next = State_curr;
    Trigger_ABORT = 0;
    Mission_Status = 'MISSION_CONFIRMED';

    % Системные константы ограничений и боевой эффективности
    R_lethal   = 15.0;   % Радиус гарантированного поражения цели (метры)
    T_maneuver = 4.0;    % Минимальное время для совершения маневра САУ (секунды)
    D_threshold = 2500;  % Предельный разрос (дисперсия) декартовых координат из-за ловушек
    Eta_min    = 0.25;   % Критический коэффициент скрытности (мерцания) РЛС цели
    
    %% 1. ВЫЧИСЛЕНИЕ ДИНАМИЧЕСКИХ ПАРАМЕТРОВ ТРАЕКТОРИИ
    
    % Модуль полной скорости ракеты
    V_mod = norm([N_la_k.Vx, N_la_k.Vy, N_la_k.Vz]);
    
    % Скорость сближения с целью (производная дальности)
    % Знак минус означает, что дальность сокращается
    R_dot = -V_mod; 
    
    % Оставшееся время до расчетного динамического попадания (Time-to-Go)
    if abs(R_dot) > 0.1
        T_go = Error_geom / abs(R_dot);
    else
        T_go = 999; % Движения нет
    end
    
    % Текущий радиус облака погрешности триангуляции (величина зоны ошибок 2-сигма)
    R_error = 2 * sqrt(max(diag(K_lambda)));

    %% 2. ПРОВЕРКА КРИТЕРИЕВ ЭФФЕКТИВНОСТИ И АВТОНОМНОЙ ОТМЕНЫ
    
    % --- Критерий А: Нехватка времени при низкой точности ---
    % Если до цели осталось лететь меньше, чем нужно автопилоту на доворот,
    % а облако ошибок все еще больше радиуса поражения — атака неэффективна.
    if (T_go <= T_maneuver) && (R_error > R_lethal)
        Trigger_ABORT = 1;
        Mission_Status = 'ABORT_REASON_TIME_TO_GO_EXHAUSTED';
    end
    
    % --- Критерий Б: Отстрел ловушек и ложных целей (Скачки КЛО) ---
    % Накапливаем историю вычисленных координат в скользящее окно
    State_next.coord_history = [State_curr.coord_history(:, 2:end), State_curr.U_target];
    
    % Считаем пространственный разброс (дисперсию) траекторных оценок в окне
    mean_coord = mean(State_next.coord_history, 2);
    coord_dev = sum(sum((State_next.coord_history - mean_coord*ones(1, size(State_next.coord_history, 2))).^2)) / size(State_next.coord_history, 2);
    
    % Если координаты хаотично прыгают во все стороны — ракета обманута ловушками
    if (coord_dev > D_threshold) && (norm(State_curr.U_target) > 0)
        Trigger_ABORT = 1;
        Mission_Status = 'ABORT_REASON_DECOY_DETECTED';
    end
    
    % --- Критерий В: Скрытность и мерцание РЛС цели ---
    % Оцениваем время горения и время молчания локатора
    t_silence = N_la_k.time - State_curr.t_last_active;
    
    if t_silence > 0.05 % Локатор в данный момент молчит
        State_next.t_total_silence = State_curr.t_total_silence + 0.01;
    else % Локатор активен и облучает ракету
        State_next.t_total_active = State_curr.t_total_active + 0.01;
    end
    
    % Коэффициент информационной достаточности (отношение приема к слепоте)
    eta = State_next.t_total_active / (State_next.t_total_silence + 1e-5);
    
    % Если цель мерцает слишком скрытно, а точность триангуляции плохая — отмена
    if (eta < Eta_min) && (R_error > R_lethal) && (N_la_k.time > 5.0)
        Trigger_ABORT = 1;
        Mission_Status = 'ABORT_REASON_TARGET_BLINKING';
    end

    %% 3. ФИНАЛЬНАЯ ФИКСАЦИЯ РЕШЕНИЯ
    if Trigger_ABORT == 1
        % Команда отмены подтверждена — обнуляем целевую память
        State_next.U_target = [0;0;0];
        State_next.t_total_active = 0;
        State_next.t_total_silence = 0;
        State_next.coord_history = zeros(3, 10);
    else
        % Все проверки пройдены — полет на источник подтверждается
        Mission_Status = 'MISSION_CONFIRMED';
    end
end
