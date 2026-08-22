classdef TisIntegrationSandbox < handle
    % =========================================================================
    % КЛАСС-ФАБРИКА АВТОМАТИЗАЦИИ ИНТЕГРАЦИОННЫХ СЦЕНАРИЕВ ТИС (SOLID)
    % Responsibility: Расчеты через вызовы 10 канонических функций ядра из matlab/
    % Path: d:\workspace\libtr\matlabtests\TisIntegrationSandbox.m
    % =========================================================================
    
    properties (Access = private)
        Cfg                 % Структура конфигурации параметров верхнего уровня
        X_True, Y_True, Z_True % Массивы опорной истинной траектории цели
        CountsVector        % Логарифмический вектор плотности/тактов станций
        Fixed_N_Stations    % Фиксированная рабочая уставка ТИС (24 по умолчанию)
        FixedStructuresCell % Хранилище декартовых облаков оценок методов МНК
    end
    
    methods (Access = public)
        function obj = TisIntegrationSandbox(configStruct)
            obj.Cfg = configStruct;
            obj.FixedStructuresCell = cell(4, 1);
            obj.initEnvironment();
        end
        
        function [summaryOut, counts, fixedN, crlbOut, xTrueOut] = run(obj)
            % Вычислительный автомат 30-км пролета барьера ТИС (Без графики)
            [P_max, crlb] = obj.computeTheoreticalLimits();
            summaryOut = struct();
            
            method_map = containers.Map({'LLS', 'WLLS', 'GN_Cartesian', 'GN_Polar'}, [1, 2, 3, 4]);
            
            for i = 1:length(obj.Cfg.ActiveMethods)
                methodName = obj.Cfg.ActiveMethods{i};
                m_idx = method_map(methodName);
                
                [fixed, summary] = obj.evaluateMethod(m_idx);
                summaryOut.(methodName) = summary;
                obj.FixedStructuresCell{m_idx} = fixed;
            end
            
            counts = obj.CountsVector;
            fixedN = obj.Fixed_N_Stations;
            crlbOut = crlb;
            xTrueOut = obj.X_True;
        end
        
        function fixedStr = getFixedStructure(obj, methodName)
            % Безопасный метод-геттер для передачи облаков оценок на верхний уровень
            method_map = containers.Map({'LLS', 'WLLS', 'GN_Cartesian', 'GN_Polar'}, [1, 2, 3, 4]);
            m_idx = method_map(methodName);
            fixedStr = obj.FixedStructuresCell{m_idx};
        end

        function [summaryOut, counts, fixedN, mcOut, max_ylim_km, xTrueOut] = runTrajectory200km(obj)
            % Вычислительный автомат стратегического сопровождения ТИС 450 км (Без графики)
            t = linspace(0, 1, obj.Cfg.Trajectory.Points);
            obj.X_True = linspace(obj.Cfg.Trajectory.X_limits(1), obj.Cfg.Trajectory.X_limits(2), obj.Cfg.Trajectory.Points);
            obj.Y_True = obj.Cfg.Trajectory.Y_center_true * ones(size(t));
            obj.Z_True = obj.Cfg.Trajectory.Z_base + obj.Cfg.Trajectory.Z_amplitude * sin(t * pi);
            
            vals = logspace(log10(4), log10(124), 20);
            obj.CountsVector = unique(round(vals));
            obj.Fixed_N_Stations = obj.CountsVector(obj.Cfg.Hardware.Fixed_N_Index);
            
            L = length(obj.CountsVector);
            max_N = max(obj.CountsVector);
            
            % Расширяем базовый крест ТИС под максимальную тактовую сетку накопления
            [P_max_exp, V_a_max, V_b_max] = service_expand_tact_matrix(obj.Cfg.Stations.Positions_Base, ...
                deg2rad(obj.Cfg.Hardware.D_Error_Degree)^2 * ones(4,1), ...
                deg2rad(obj.Cfg.Hardware.D_Error_Degree)^2 * ones(4,1), max_N);
            
            % Сквозной расчет репера CRLB через ядерную функцию lls3d_fisher_crlb.m
            crlb.X = zeros(obj.Cfg.Trajectory.Points, 1);
            crlb.Y = zeros(obj.Cfg.Trajectory.Points, 1);
            crlb.Z = zeros(obj.Cfg.Trajectory.Points, 1);
            for k = 1:obj.Cfg.Trajectory.Points
                [st_f, cx, cy, cz] = lls3d_fisher_crlb(P_max_exp, V_a_max, V_b_max, ...
                    obj.X_True(k), obj.Y_True(k), obj.Z_True(k));
                if st_f == 0, crlb.X(k) = cx; crlb.Y(k) = cy; crlb.Z(k) = cz; else, crlb.X(k) = NaN; crlb.Y(k) = NaN; crlb.Z(k) = NaN; end
            end
            
            % Подготовка статического пучка измерений Монте-Карло в фиксированной точке
            [P_exp_mc, V_a_mc, V_b_mc] = service_expand_tact_matrix(obj.Cfg.Stations.Positions_Base, ...
                deg2rad(obj.Cfg.Hardware.D_Error_Degree)^2 * ones(4,1), ...
                deg2rad(obj.Cfg.Hardware.D_Error_Degree)^2 * ones(4,1), obj.Fixed_N_Stations);
            
            alpha_mc_raw = zeros(obj.Fixed_N_Stations, obj.Cfg.Hardware.N_Monte_Carlo);
            beta_mc_raw  = zeros(obj.Fixed_N_Stations, obj.Cfg.Hardware.N_Monte_Carlo);
            
            for s = 1:obj.Cfg.Hardware.N_Monte_Carlo
                [a_vec, b_vec] = service_add_noise_ox(P_exp_mc, 0, obj.Cfg.Trajectory.Y_center_true, 10000, ...
                    obj.Cfg.Hardware.D_Error_Degree, 1337 + s);
                alpha_mc_raw(:, s) = a_vec; beta_mc_raw(:, s) = b_vec;
            end
            
            summaryOut = struct(); mcOut = struct();
            method_map = containers.Map({'LLS', 'WLLS', 'GN_Cartesian', 'GN_Polar'}, [1, 2, 3, 4]);
            
            for i = 1:length(obj.Cfg.ActiveMethods)
                methodName = obj.Cfg.ActiveMethods{i};
                m_idx = method_map(methodName);
                
                summary.rmse = zeros(L, 1);
                fixed_traj.pos = zeros(3, obj.Cfg.Trajectory.Points);
                
                for s_idx = 1:L
                    N_TOTAL = obj.CountsVector(s_idx);
                    P_curr = P_max_exp(:, 1:N_TOTAL);
                    V_a_curr = V_a_max(1:N_TOTAL); V_b_curr = V_b_max(1:N_TOTAL);
                    
                    res_pos = zeros(3, obj.Cfg.Trajectory.Points);
                    status_mc = zeros(1, obj.Cfg.Trajectory.Points);
                    
                    % Сквозная синхронизация семени для 200-км сценария накопления
                    alpha_matrix = zeros(N_TOTAL, obj.Cfg.Trajectory.Points);
                    beta_matrix  = zeros(N_TOTAL, obj.Cfg.Trajectory.Points);
                    
                    base_seed_far = 1337 + s_idx * 1000;
                    
                    for k_step = 1:obj.Cfg.Trajectory.Points
                        [a_vec, b_vec] = service_add_noise_ox(P_curr, obj.X_True(k_step), ...
                            obj.Y_True(k_step), obj.Z_True(k_step), obj.Cfg.Hardware.D_Error_Degree, base_seed_far + k_step);
                        alpha_matrix(:, k_step) = a_vec;
                        beta_matrix(:, k_step)  = b_vec;
                    end

                    
                    for k = 1:obj.Cfg.Trajectory.Points
                        alpha = alpha_matrix(:, k); beta = beta_matrix(:, k);
                        
                        % Вызовы расчетных функций геометрии ядра ТИС
                        if m_idx == 1
                            [st, lambda] = lls3d_position(P_curr, alpha, beta);
                        elseif m_idx == 2
                            % Вызываем lls3d_prepare_data.m для итерационного формирования весов Гаусса от дальностей
                            [~, W] = lls3d_prepare_data(P_curr, alpha, beta, V_a_curr, V_b_curr);
                            [st, lambda] = wlls3d_position(P_curr, alpha, beta, W);
                        elseif m_idx == 3
                            [st, lambda] = gn3d_position(P_curr, alpha, beta);
                        else
                            [st, lambda] = gn3d_position_polar(P_curr, alpha, beta);
                        end
                        status_mc(k) = st;
                        if st == 0, res_pos(:, k) = lambda; else, res_pos(:, k) = [NaN; NaN; NaN]; end
                    end
                    
                    mask = ~isnan(res_pos(1, :));
                    if any(mask)
                        err_x = res_pos(1, mask) - obj.X_True(mask); err_y = res_pos(2, mask) - obj.Y_True(mask); err_z = res_pos(3, mask) - obj.Z_True(mask);
                        summary.rmse(s_idx) = sqrt(mean(err_x.^2 + err_y.^2 + err_z.^2));
                    else, summary.rmse(s_idx) = NaN; end
                    
                    if N_TOTAL == obj.Fixed_N_Stations
                        fixed_traj.pos = res_pos;
                        fixed_traj.STATION_POSITIONS = P_curr;
                        for k = 1:obj.Cfg.Trajectory.Points
                            if status_mc(k) == 0
                                a_k = alpha_matrix(:, k); b_k = beta_matrix(:, k);
                                % Вызовы ядерных ковариаций
                                if m_idx == 1
                                    [~, sx, sy, sz] = lls3d_covariance_linear(P_curr, a_k, b_k, V_a_curr, V_b_curr, res_pos(:,k));
                                elseif m_idx == 2
                                    [~, W_cov] = lls3d_prepare_data(P_curr, a_k, b_k, V_a_curr, V_b_curr);
                                    [~, sx, sy, sz] = wlls3d_covariance_weighted(P_curr, a_k, b_k, V_a_curr, V_b_curr, res_pos(:,k), W_cov);
                                elseif m_idx == 3
                                    [~, sx, sy, sz] = gn3d_covariance_cartesian(P_curr, V_a_curr, V_b_curr, res_pos(:,k));
                                else
                                    [~, sx, sy, sz] = gn3d_covariance_polar_invariant(P_curr, V_a_curr, V_b_curr, res_pos(:,k));
                                end
                                fixed_traj.std_X(k) = sx; fixed_traj.std_Y(k) = sy; fixed_traj.std_Z(k) = sz;
                            else, fixed_traj.std_X(k) = NaN; fixed_traj.std_Y(k) = NaN; fixed_traj.std_Z(k) = NaN; end
                        end
                    end
                end
                
                % Статический Монте-Карло прогон на функциях ядра
                mc_y = zeros(obj.Cfg.Hardware.N_Monte_Carlo, 1);
                for s = 1:obj.Cfg.Hardware.N_Monte_Carlo
                    a_mc = alpha_mc_raw(:, s); b_mc = beta_mc_raw(:, s);
                    if m_idx == 1
                        [st, lambda] = lls3d_position(P_exp_mc, a_mc, b_mc);
                    elseif m_idx == 2
                        % Вызываем ядерный предобработчик lls3d_prepare_data для Монте-Карло выборок
                        [~, W_mc] = lls3d_prepare_data(P_exp_mc, a_mc, b_mc, V_a_mc, V_b_mc);
                        [st, lambda] = wlls3d_position(P_exp_mc, a_mc, b_mc, W_mc);
                    elseif m_idx == 3
                        [st, lambda] = gn3d_position(P_exp_mc, a_mc, b_mc);
                    else
                        [st, lambda] = gn3d_position_polar(P_exp_mc, a_mc, b_mc);
                    end
                    if st == 0, mc_y(s) = lambda(2); else, mc_y(s) = NaN; end
                end
                
                summaryOut.(methodName) = summary;
                obj.FixedStructuresCell{m_idx} = fixed_traj;
                mcOut.(methodName) = mc_y;
            end
            
            % Расчет шкал по ядерной lls3d_fisher_crlb
            VAR_A_4 = deg2rad(obj.Cfg.Hardware.D_Error_Degree)^2 * ones(4, 1); 
            VAR_B_4 = deg2rad(obj.Cfg.Hardware.D_Error_Degree)^2 * ones(4, 1);
            [st_f, cx, cy, cz] = lls3d_fisher_crlb(obj.Cfg.Stations.Positions_Base, VAR_A_4, VAR_B_4, 0, obj.Cfg.Trajectory.Y_center_true, 10000);
            if st_f == 0, max_ylim_km = (sqrt(cx^2 + cy^2 + cz^2) / 1000) * 1.20; else, max_ylim_km = 300; end
            
            counts = obj.CountsVector; fixedN = obj.Fixed_N_Stations;
            crlbOut = crlb; xTrueOut = obj.X_True;
        end
    end
    
    methods (Access = private)
        function initEnvironment(obj)
            vals = logspace(log10(4), log10(124), 20);
            obj.CountsVector = unique(round(vals));
            obj.Fixed_N_Stations = obj.CountsVector(obj.Cfg.Hardware.Fixed_N_Index);
            
            t = linspace(0, 1, obj.Cfg.Trajectory.Points);
            obj.X_True = linspace(obj.Cfg.Trajectory.X_limits(1), obj.Cfg.Trajectory.X_limits(2), obj.Cfg.Trajectory.Points);
            
            if isfield(obj.Cfg.Trajectory, 'Y_center_true')
                y_base_val = obj.Cfg.Trajectory.Y_center_true;
            else
                y_base_val = obj.Cfg.Trajectory.Y_static;
            end
            obj.Y_True = y_base_val * ones(size(t));
            
            if isfield(obj.Cfg.Trajectory, 'Z_static')
                obj.Z_True = obj.Cfg.Trajectory.Z_static * ones(size(t));
            else
                obj.Z_True = obj.Cfg.Trajectory.Z_base + obj.Cfg.Trajectory.Z_amplitude * sin(t * pi);
            end
            
            sandbox_dir = fileparts(mfilename('fullpath'));
            if isempty(sandbox_dir), sandbox_dir = pwd; end
            [project_root, ~] = fileparts(sandbox_dir);
            matlab_core_dir = fullfile(project_root, 'matlab');
            addpath(matlab_core_dir);
        end
        
        function [P_max, crlb] = computeTheoreticalLimits(obj)
            % Расчет репера CRLB барьера 30км через lls3d_fisher_crlb.m
            t_max = linspace(1, 4, max(obj.CountsVector));
            P_max = [spline(1:4, obj.Cfg.Stations.X_anchors, t_max); ...
                     spline(1:4, obj.Cfg.Stations.Y_anchors, t_max); ...
                     spline(1:4, obj.Cfg.Stations.Z_anchors, t_max)];
            
            N_max_stations = size(P_max, 2);
            crlb.X = zeros(obj.Cfg.Trajectory.Points, 1);
            crlb.Y = zeros(obj.Cfg.Trajectory.Points, 1);
            crlb.Z = zeros(obj.Cfg.Trajectory.Points, 1);
            
            for k = 1:obj.Cfg.Trajectory.Points
                V_alpha = deg2rad(obj.Cfg.Hardware.D_Error_Degree)^2 * ones(N_max_stations, 1);
                V_beta  = deg2rad(obj.Cfg.Hardware.D_Error_Degree)^2 * ones(N_max_stations, 1);
                
                [st_f, cx, cy, cz] = lls3d_fisher_crlb(P_max, V_alpha, V_beta, ...
                    obj.X_True(k), obj.Y_True(k), obj.Z_True(k));
                
                if st_f == 0, crlb.X(k) = cx; crlb.Y(k) = cy; crlb.Z(k) = cz; else, crlb.X(k) = NaN; crlb.Y(k) = NaN; crlb.Z(k) = NaN; end
            end
        end
        
        function [fixed, summary] = evaluateMethod(obj, m_idx)
            % Вычислительный автомат 30-км барьера, полностью завязанный на 10 ядер
            L = length(obj.CountsVector);
            summary.rmse = zeros(L, 1); summary.mean_miss = zeros(L, 1);
            summary.max_miss = zeros(L, 1); summary.bias_y = zeros(L, 1);
            
            fixed.pos = zeros(3, obj.Cfg.Trajectory.Points); fixed.STATION_POSITIONS = [];
            fixed.std_X = zeros(obj.Cfg.Trajectory.Points, 1); fixed.std_Y = zeros(obj.Cfg.Trajectory.Points, 1); fixed.std_Z = zeros(obj.Cfg.Trajectory.Points, 1);
            
            for s_idx = 1:L
                N = obj.CountsVector(s_idx);
                t_q = linspace(1, 4, N);
                P_curr = [spline(1:4, obj.Cfg.Stations.X_anchors, t_q); ...
                          spline(1:4, obj.Cfg.Stations.Y_anchors, t_q); ...
                          spline(1:4, obj.Cfg.Stations.Z_anchors, t_q)];
                      
                V_a = deg2rad(obj.Cfg.Hardware.D_Error_Degree)^2 * ones(N, 1);
                V_b = deg2rad(obj.Cfg.Hardware.D_Error_Degree)^2 * ones(N, 1);
                
                % ВОССТАНОВЛЕНИЕ СКВОЗНОЙ НЕЗАВИСИМОСТИ ШУМА (СЕМЯ ЗАВЯЗАНО НА S_IDX И K_STEP)
                alpha_matrix = zeros(N, obj.Cfg.Trajectory.Points);
                beta_matrix  = zeros(N, obj.Cfg.Trajectory.Points);
                
                base_seed = 1337 + s_idx * 1000; % Ортогональный сдвиг Гауссова генератора на каждом шаге N
                
                for k_step = 1:obj.Cfg.Trajectory.Points
                    [a_vec, b_vec] = service_add_noise_ox(P_curr, obj.X_True(k_step), ...
                        obj.Y_True(k_step), obj.Z_True(k_step), obj.Cfg.Hardware.D_Error_Degree, base_seed + k_step);
                    alpha_matrix(:, k_step) = a_vec;
                    beta_matrix(:, k_step)  = b_vec;
                end

                
                res_pos = zeros(3, obj.Cfg.Trajectory.Points); status = zeros(1, obj.Cfg.Trajectory.Points);
                
                for k = 1:obj.Cfg.Trajectory.Points
                    alpha = alpha_matrix(:, k); beta = beta_matrix(:, k);
                    if m_idx == 1
                        [st, lambda] = lls3d_position(P_curr, alpha, beta);
                    elseif m_idx == 2
                        % Сквозной вызов предобработчика весов Гаусса lls3d_prepare_data
                        [~, W] = lls3d_prepare_data(P_curr, alpha, beta, V_a, V_b);
                        [st, lambda] = wlls3d_position(P_curr, alpha, beta, W);
                    elseif m_idx == 3
                        [st, lambda] = gn3d_position(P_curr, alpha, beta);
                    else
                        [st, lambda] = gn3d_position_polar(P_curr, alpha, beta);
                    end
                    status(k) = st;
                    if st == 0, res_pos(:, k) = lambda; else, res_pos(:, k) = [NaN; NaN; NaN]; end
                end
                
                mask = ~isnan(res_pos(1, :));
                if any(mask)
                    err_x = res_pos(1, mask) - obj.X_True(mask); err_y = res_pos(2, mask) - obj.Y_True(mask); err_z = res_pos(3, mask) - obj.Z_True(mask);
                    summary.rmse(s_idx) = sqrt(mean(err_x.^2 + err_y.^2 + err_z.^2));
                    summary.mean_miss(s_idx) = mean(sqrt(err_x.^2 + err_y.^2 + err_z.^2));
                    summary.max_miss(s_idx) = max(sqrt(err_x.^2 + err_y.^2 + err_z.^2));
                    summary.bias_y(s_idx) = mean(err_y);
                else
                    summary.rmse(s_idx) = NaN; summary.mean_miss(s_idx) = NaN; summary.max_miss(s_idx) = NaN; summary.bias_y(s_idx) = NaN;
                end
                
                if N == obj.Fixed_N_Stations
                    fixed.pos = res_pos; fixed.STATION_POSITIONS = P_curr;
                    for k = 1:obj.Cfg.Trajectory.Points
                        if status(k) == 0
                            a_k = alpha_matrix(:, k); b_k = beta_matrix(:, k);
                            if m_idx == 1
                                [~, sx, sy, sz] = lls3d_covariance_linear(P_curr, a_k, b_k, V_a, V_b, res_pos(:,k));
                            elseif m_idx == 2
                                [~, W_cov] = lls3d_prepare_data(P_curr, a_k, b_k, V_a, V_b);
                                [~, sx, sy, sz] = wlls3d_covariance_weighted(P_curr, a_k, b_k, V_a, V_b, res_pos(:,k), W_cov);
                            elseif m_idx == 3
                                [~, sx, sy, sz] = gn3d_covariance_cartesian(P_curr, V_a, V_b, res_pos(:,k));
                            else
                                [~, sx, sy, sz] = gn3d_covariance_polar_invariant(P_curr, V_a, V_b, res_pos(:,k));
                            end
                            fixed.std_X(k) = sx; fixed.std_Y(k) = sy; fixed.std_Z(k) = sz;
                        else, fixed.std_X(k) = NaN; fixed.std_Y(k) = NaN; fixed.std_Z(k) = NaN; end
                    end
                end
            end
        end
    end
end

