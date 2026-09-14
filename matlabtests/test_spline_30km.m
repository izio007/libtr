% =========================================================================
% ПРИКЛАДНОЙ ИНТЕГРАЦИОННЫЙ ТЕСТ ТИС: ВАРИАНТ «МНОГОПОЗИЦИОННЫЙ БАРЬЕР 30 КМ»
% Path: f:\sy\workspace\libtr\matlab\test_spline_30km.m
% =========================================================================

clear; clc; close all;

% Загрузка изолированной измерительной шины данных ближней зоны
DataContext = service_init_geometry_30km('context_30km.mat');

cfg_methods   = DataContext.Methods.ActiveMethods;
method_labels = DataContext.Methods.Labels;
solver_names  = DataContext.Methods.Solvers;
cov_names     = DataContext.Methods.Covariances;

xTrue = DataContext.X_true;
yTrue = DataContext.Y_true;
countsVector = DataContext.CountsVector;
fixedN       = DataContext.Fixed_N_Stations;

% Вычисление теоретического декартова порога Рао-Крамера
crlbData = service_calc_crlb_trajectory(DataContext, fixedN);

X_anchors = DataContext.P_max_matrix(1, 1:4); % Исходные 4 базовых анкера для spline
Y_anchors = DataContext.P_max_matrix(2, 1:4);

% ГЛАВНЫЙ ВЫЧИСЛИТЕЛЬНЫЙ КОНВЕЙЕР ТАКТОВ ТРАЕКТОРИИ ТИС
for i = 1:length(cfg_methods)
    fh_sol = str2func(solver_names{i});
    fh_cov = str2func(cov_names{i});
    
    fixed_m = run_tactical_solver(DataContext, fixedN, fh_sol, fh_cov);
    
    summary_m = struct();
    summary_m.rmse      = zeros(size(countsVector));
    summary_m.mean_miss = zeros(size(countsVector));
    summary_m.max_miss  = zeros(size(countsVector));
    summary_m.bias_y    = zeros(size(countsVector));
    
    for n_idx = 1:length(countsVector)
        N_curr = countsVector(n_idx);
        out_n = run_tactical_solver(DataContext, N_curr, fh_sol, fh_cov);
        
        summary_m.rmse(n_idx) = mean(out_n.rmse, 'omitnan');
        
        dx_miss = out_n.X_est - xTrue;
        dy_miss = out_n.Y_est - yTrue;
        dz_miss = out_n.Z_est - DataContext.Z_true;
        miss_dist = sqrt(dx_miss.^2 + dy_miss.^2 + dz_miss.^2);
        
        summary_m.mean_miss(n_idx) = mean(miss_dist, 'omitnan');
        summary_m.max_miss(n_idx)  = max(miss_dist, [], 'omitnan');
        summary_m.bias_y(n_idx)    = mean(out_n.Y_est - yTrue, 'omitnan');
    end
    
    % СТРOГO ОРИГИНАЛЬНЫЙ ВЫЗОВ ЭКРАНА ПО СИГНАТУРЕ ИЗ 11 АРГУМЕНТОВ (ИСТОЧНИК 15)
    matplot_verification_screen(xTrue, yTrue, X_anchors, Y_anchors, ...
        fixed_m, summary_m, crlbData, countsVector, fixedN, method_labels{i}, i);
end
