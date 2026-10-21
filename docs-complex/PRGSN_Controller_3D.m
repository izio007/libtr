function [U_target, Error_geom, Command_g, State_next] = PRGSN_Pure_Ang_Controller_3D(S_k, N_la_k, State_prev)
% СИСТЕМНЫЙ 3D-КОНТРОЛЛЕР ПРГСН НА ОСНОВЕ МЕТОДОВ МЕЛЬНИКОВА, РАДУ И БУЛЫЧЕВА
% Высокочастотная обработка (100 Гц) строго по пространственным пеленгам
%
% ВХОДНЫЕ ПАРАМЕТРЫ:
%   S_k        - ПРГСН: .alpha (азимут), .beta (угол места), .N_imp (поток)
%   N_la_k     - Навигация ЛА: .X, .Y, .Z, .Vx, .Vy, .Vz, .psi, .teta, .Flag_BINS, .time
%   State_prev - Память (матрицы КЛО, окна сглаживания Раду, формуляр цели)
%
% ВЫХОДНЫЕ ПАРАМЕТРЫ:
%   U_target   - Оцененные 3D-координаты цели [X_ц; Y_ц; Z_ц]
%   Error_geom - Среднегеометрическая пространственная невязка промаха (скаляр, метры)
%   Command_g  - Управляющие ускорения на рули [W_y_cmd; W_z_cmd] (Тангаж / Рыскание)
%   State_next - Обновленная структура памяти вычислителя

    %% Инициализация и системные константы
    State_next = State_prev;
    U_target   = State_prev.U_target;
    Error_geom = 0;
    Command_g  = [0; 0];
    
    % Пороги живучести и параметры алгоритма
    Pi_max     = 20000;         % Предельная плотность потока (Уровень 1)
    Epsilon    = 1e-6;          % Порог сингулярности матрицы ошибок (Уровень 2)
    W_min      = 0.1;           % Критический порог достоверности весов (Уровень 2)
    Sigma_ang  = deg2rad(0.5);  % Приборная точность ПРГСН (СКО)
    T_timeout  = 4.0;           % Тайм-аут списания формуляра цели (Уровень 5)
    N_window   = 20;            % Объем скользящего окна сглаживания Раду (Уровень 3)
    
    % Параметры прореживания и весового доминирования (Уровень 4)
    Delta_S_min = 5.0;          % Пространственный шаг прореживания траектории (метры)
    Mu_weight   = 10.0;         % Весовой коэффициент доминирования пеленга (\mu >> 1)
    
    % Параметры защиты шторки координатора (Блок наведения)
    Ang_max    = deg2rad(45.0); % Максимальный аппаратный угол сектора обзора ПРГСН
    Ang_safe   = deg2rad(4.0);  % Буферная зона безопасности шторки (\Delta_safe)
    K_corr     = 1.5;           % Коэффициент усиления контура коррекции
    W_kick     = 25.0;          % Амплитуда силового доворота корпуса (\Delta W_kick, м/с^2)

    %% ========================================================================
    %% 🚨 УРОВЕНЬ 1. БЛОКИРУЮЩИЙ КОНТУР (КРИТИЧЕСКИЙ ВЫЧИСЛИТЕЛЬНЫЙ БАЗИС)
    %% ========================================================================
    if (S_k.N_imp / 0.01 > Pi_max) || (N_la_k.Flag_BINS == 0)
        return; % Вычисления аварийно заблокированы, возврат предыстории
    end

    %% ========================================================================
    %% 🔄 УРОВЕНЬ 3. АДАПТАЦИОННЫЙ КОНТУР (3D-СГЛАЖИВАНИЕ OINO С МЕДИАННЫМ ФИЛЬТРОМ)
    %% ========================================================================
    % 3.1. Кинематическая компенсация эволюций ЛА (Перевод в географическую СК)
    alpha_geo = S_k.alpha + N_la_k.psi;
    beta_geo  = S_k.beta  + N_la_k.teta;
    
    % Пространственная селекция по методу Мельникова (проверка строба промаха луча)
    if norm(State_prev.U_target) > 0
        vec_la = [N_la_k.X; N_la_k.Y; N_la_k.Z];
        vec_ray = [cos(beta_geo)*cos(alpha_geo); cos(beta_geo)*sin(alpha_geo); sin(beta_geo)];
        vec_target = State_prev.U_target - vec_la;
        d_miss = norm(cross(vec_target, vec_ray));
    else
        d_miss = 0; % Этап первичного захвата ИИ
    end
    
    D_str = 500; % Линейный строб удержания Мельникова (метры)
    if d_miss <= D_str
        % Обновление скользящих буферов пространственных углов в памяти ЛА
        window_alpha = [State_prev.window_alpha(2:end); alpha_geo];
        window_beta  = [State_prev.window_beta(2:end); beta_geo];
        
        State_next.window_alpha = window_alpha;
        State_next.window_beta  = window_beta;
        
        % Вектор совместных пространственных наблюдений y_3D
        y_3D = [window_alpha; window_beta];
        
        % Вычисление пространственных медиан Раду по измерительным окнам
        alpha_med = median(window_alpha);
        beta_med  = median(window_beta);
        
        % Формирование нелинейной весовой матрицы Е (М-оценивание отклонений от медианы)
        N_total = 2 * N_window;
        E_diag = zeros(N_total, 1);
        for i = 1:N_window
            E_diag(i) = exp(-(window_alpha(i) - alpha_med)^2 / (2 * Sigma_ang^2));
            E_diag(N_window + i) = exp(-(window_beta(i) - beta_med)^2 / (2 * Sigma_ang^2));
        end
        E_diag(E_diag < 0.01) = 0; % Полное подавление зеркального блеска подстилающей поверхности
        E = diag(E_diag);
        sum_w = sum(E_diag);
        
        % Базисная матрица Вандермонда PSI_3D и вектор приборных связей h_3D
        I_3D = ones(N_total, 1);
        h_3D = ones(N_total, 1);
        Mt = 2; t_vec = (1:N_window)'; PSI_sub = zeros(Mt, N_window);
        for m = 1:Mt, PSI_sub(m, :) = (t_vec .^ (m-1))'; end
        PSI_3D = [PSI_sub, zeros(Mt, N_window); zeros(Mt, N_window), PSI_sub];
        PSIm_3D = PSI_3D(:, [N_window, 2*N_window]);
        
        % Математический аппарат calcoino по патенту Раду
        B_w = (Sigma_ang^2)^-1 .* E;
        W_mat = E - B_w * h_3D * (h_3D' * B_w * h_3D + 1e-5)^-1 * h_3D';
        H_mat = W_mat * PSI_3D' * (PSI_3D * W_mat * PSI_3D')^-1;
        P_mat = H_mat * PSIm_3D;
        
        % Очищенные мгновенные пеленги и матрица их совместной ковариации
        x_smoothed = P_mat' * y_3D;
        var_smoothed = Sigma_ang^2 * (P_mat' * P_mat);
        
        alpha_smoothed = x_smoothed(1);
        beta_smoothed  = x_smoothed(2);
        
        State_next.t_last_active = N_la_k.time;
        State_next.last_var_theta = var_smoothed;
        has_signal = true;
    else
        has_signal = false;
        sum_w = 0;
    end

    %% ========================================================================
    %% ⏱️ УРОВЕНЬ 4. РЕГЛАМЕНТНЫЙ КОНТУР (3D ТРИАНГУЛЯЦИЯ БУЛЫЧЕВА С ПРОРЕЖИВАНИЕМ)
    %% ========================================================================
    if has_signal && sum_w >= W_min
        % Проверка пространственного критерия прореживания данных на частоте 100 Гц
        % Строка КЛО накапливается только при достаточном линейном размахе траектории
        dist_moved = norm([N_la_k.X; N_la_k.Y; N_la_k.Z] - State_prev.P_last_nak);
        
        if dist_moved >= Delta_S_min || norm(State_prev.P_history) == 0
            % Фиксация точки траектории ЛА как новой измерительной базы КЛО
            P_history = [State_prev.P_history(:, 2:end), [N_la_k.X; N_la_k.Y; N_la_k.Z]];
            alpha_history = [State_prev.alpha_history(2:end); alpha_smoothed];
            beta_history  = [State_prev.beta_history(2:end); beta_smoothed];
            
            State_next.P_history = P_history;
            State_next.alpha_history = alpha_history;
            State_next.beta_history  = beta_history;
            State_next.P_last_nak = [N_la_k.X; N_la_k.Y; N_la_k.Z]; % Обновление опорной точки прореживания
        else
            % Прореживание: текущий избыточный такт 100 Гц пропускается, предыстория сохраняется
            P_history = State_prev.P_history;
            alpha_history = State_prev.alpha_history;
            beta_history  = State_prev.beta_history;
        end
        
        M_count = size(P_history, 2);
        
        % Кинематическая адаптация Раду под вектор скорости ЛА (углы сноса)
        V_mod = norm([N_la_k.Vx, N_la_k.Vy, N_la_k.Vz]);
        d_psi_ad  = -atan2(N_la_k.Vy, N_la_k.Vx);
        d_teta_ad = -asin(N_la_k.Vz / (V_mod + 1e-5));
        
        % Формирование глобальной КЛО системы Булычева в 3D пространстве
        H_global = zeros(2 * M_count, 3);
        b_global = zeros(2 * M_count, 1);
        
        for j = 1:M_count
            az = alpha_history(j) + d_psi_ad;
            el = beta_history(j)  + d_teta_ad;
            
            sa = sin(az); ca = cos(az);
            sb = sin(el); cb = cos(el);
            
            % Матрица ортогональных плоскостей Булычева с коэффициентом доминирования пеленга Mu_weight
            H_local = Mu_weight * [  sa,    -ca,     0; ...
                                    sb*ca,  sb*sa,  -cb ];
                                
            P_local = P_history(:, j);
            b_local = H_local * P_local;
            
            idx = (2*j-1):(2*j);
            H_global(idx, :) = H_local;
            b_global(idx)    = b_local;
        end
        
        % Расчет псевдообратной триангуляционной матрицы Булычева С
        C_matrix = (H_global' * H_global) \ H_global';
        lambda_target = C_matrix * b_global; % Прямое безынерционное 3D-местоопределение ИИ
        
        % Ковариационный анализ погрешностей по Булычеву (масштабирование на дальность)
        K_b_diag = zeros(2 * M_count, 1);
        for j = 1:M_count
            az = alpha_history(j) + d_psi_ad; el = beta_history(j) + d_teta_ad;
            r_vec = lambda_target - P_history(:, j);
            proj_error = ([cos(az)*cos(el), sin(az)*cos(el), sin(el)] * r_vec)^2;
            
            K_b_diag(2*j-1) = proj_error * State_next.last_var_theta(1,1);
            K_b_diag(2*j)   = proj_error * State_next.last_var_theta(2,2);
        end
        K_b = diag(K_b_diag);
        K_lambda = C_matrix * K_b * C_matrix'; % Декартова матрица Фишера-Булычева (3х3)
        
        %% ========================================================================
        %% ⚠️ УРОВЕНЬ 2. СДЕРЖИВАЮЩИЙ КОНТУР (СУБКРИТИЧЕСКИЙ ГЕОМЕТРИЧЕСКИЙ БАЗИС)
        %% ========================================================================
        if det(K_lambda) > Epsilon && norm(P_history(:,end) - P_history(:,1)) > 3.0
            U_target = lambda_target; % Обновление целевого вектора формуляра [X_ц; Y_ц; Z_ц]
            State_next.U_target = U_target;
        else
            U_target = State_prev.U_target; % Замораживание координат при вырожденной базе
        end
        
    %% ========================================================================
    %% 🟢 УРОВЕНЬ 5. БАЗОВЫЙ КОНТУР (ИНВАРИАНТНАЯ ЭКСТРАПОЛЯЦИЯ БУЛЫЧЕВА)
    %% ========================================================================
    else
        % Режим ухода ИИ в молчание: прекращение накопления, жесткое удержание трека
        dt_silence = N_la_k.time - State_prev.t_last_active;
        if dt_silence > T_timeout
            % Аннулирование формуляра цели по Мельникову по истечении тайм-аута
            State_next.window_alpha = zeros(N_window, 1);
            State_next.window_beta  = zeros(N_window, 1);
            State_next.P_history    = zeros(3, 50);
            State_next.alpha_history = zeros(50, 1);
            State_next.beta_history  = zeros(50, 1);
            State_next.U_target     = [0; 0; 0];
            State_next.P_last_nak   = [0; 0; 0];
            return;
        end
        U_target = State_prev.U_target; % Удержание константы КЛО (отсутствует ковариационный шум разгона)
    end

    %% ========================================================================
    %% 🎯 ВЫЧИСЛЕНИЕ ПРОСТРАНСТВЕННОЙ НЕВЯЗКИ И АВТОМАТИЧЕСКАЯ КОРРЕКЦИЯ ТРАЕКТОРИИ
    %% ========================================================================
    if norm(U_target) > 0
        % 1. Расчет вектора пространственных линейных декартовых невязок
        dX = U_target(1) - N_la_k.X;
        dY = U_target(2) - N_la_k.Y;
        dZ = U_target(3) - N_la_k.Z;
        Error_nav = [dX; dY; dZ];
        
        % 2. Вычисление СРЕДНЕГЕОМЕТРИЧЕСКОЙ НЕВЯЗКИ ПРОМАХА В 3D (евклидова норма)
        Error_geom = sqrt(dX^2 + dY^2 + dZ^2); 
        
        % 3. Мониторинг критических угловых границ шторки координатора ПРГСН
        % Предикат триггера безопасности при угрозе выхода цели за сектор видимости
        Trigger_bound = (abs(S_k.alpha) >= (Ang_max - Ang_safe)) || ...
                        (abs(S_k.beta)  >= (Ang_max - Ang_safe));
        
        % Расчет трехмерного вектора угловой скорости линии визирования целей
        V_missile = [N_la_k.Vx; N_la_k.Vy; N_la_k.Vz]; 
        Omega_lv = cross(Error_nav, V_missile) / (Error_geom^2 + 1e-5);
        
        % Базовый закон пропорциональной навигации (3D)
        N_nav = 4.0;
        W_base = N_nav * cross(V_missile, Omega_lv);
        
        % Интеграция корректирующего импульса Раду удержания пеленга в секторе
        % Силовой импульс заставляет ЛА довернуть на цель, раскрывая базу триангуляции КЛО
        W_cmd = W_base + Trigger_bound * K_corr * [0; ...
                                                   sign(S_k.alpha) * W_kick; ...
                                                   sign(S_k.beta)  * W_kick];
        
        % Проекция результирующих перегрузок на рулевые приводы тангажа и рыскания ЛА
        Command_g = [W_cmd(2); W_cmd(3)]; 
    end
end

State_prev.window_alpha  = zeros(20, 1); % Окно азимутов Раду
State_prev.window_beta   = zeros(20, 1); % Окно углов места Раду
State_prev.P_history     = zeros(3, 50);  % 3D-предыстория позиций ЛА
State_prev.alpha_history = zeros(50, 1);  % Предыстория сглаженных азимутов
State_prev.beta_history  = zeros(50, 1);  % Предыстория сглаженных углов места
State_prev.U_target      = [0; 0; 0];     % 3D-координаты цели в формуляре
State_prev.P_last_nak    = [0; 0; 0];     % Опорная точка прореживания ЛА
State_prev.t_last_active = 0;             % Время последней активной засечки
State_prev.last_var_theta = zeros(2, 2);  % Ковариационная матрица oino