function SolverOut = run_tactical_solver(DataContext, N_Stations, fh_solver, fh_covariance)
% COMPUTATION KERNEL: TACTICAL PATH EXECUTION RUNNER (STERILE INTERFACE CONTRACT)
% SYSTEM MATRIX CONTEXT: DE CARTESIAN INVARIANT SEPARATION / PURE SHIELD CONTRACT
% PATH: f:\sy\workspace\libtr\matlab\run_tactical_solver.m

    Points = length(DataContext.X_true);
    SolverOut.X_est = zeros(1, Points); SolverOut.Y_est = zeros(1, Points); SolverOut.Z_est = zeros(1, Points);
    SolverOut.X     = zeros(1, Points); SolverOut.Y     = zeros(1, Points); SolverOut.Z     = zeros(1, Points);
    
    SolverOut.std_X = zeros(1, Points); SolverOut.std_Y = zeros(1, Points); SolverOut.std_Z = zeros(1, Points);
    
    var_alpha_base = DataContext.var_alpha_max; var_beta_base  = DataContext.var_beta_max;

    % Прямая нарезка активной измерительной базы под текущую уставку избыточности N_Stations
    P_active  = DataContext.P_max_matrix(:, 1:N_Stations);
    var_alpha = var_alpha_base(1:N_Stations); var_beta  = var_beta_base(1:N_Stations);
    
    % Потоковый обсчет тактов траектории МНК-ядрами ТИС
    for t = 1:Points
        % ИЗМЕРИТЕЛЬНЫЙ ПУЧОК СТЕРИЛЕН: Берем честные зашумленные пеленги, 
        % рассчитанные именно для текущих N_Stations из корня генератора геометрии!
        alpha_t = DataContext.alpha_noisy_matrix(1:N_Stations, t);
        beta_t  = DataContext.beta_noisy_matrix(1:N_Stations, t);
        
        % Слепой вызов МНК-позиционера ТИС
        [status_sol, lambda_est] = fh_solver(P_active, alpha_t, beta_t, var_alpha, var_beta);
        
        if status_sol == 0
            SolverOut.X_est(t) = lambda_est(1); SolverOut.Y_est(t) = lambda_est(2); SolverOut.Z_est(t) = lambda_est(3);
            SolverOut.X(t)     = lambda_est(1); SolverOut.Y(t)     = lambda_est(2); SolverOut.Z(t)     = lambda_est(3);
            
            % Аналитический перенос ошибок погрешностей (Ковариационный канон ТИС)
            [status_cov, K_c] = fh_covariance(P_active, alpha_t, beta_t, var_alpha, var_beta, lambda_est);
            
            if status_cov == 0
                SolverOut.std_X(t) = sqrt(max(K_c(1,1), 0.0));
                SolverOut.std_Y(t) = sqrt(max(K_c(2,2), 0.0));
                SolverOut.std_Z(t) = sqrt(max(K_c(3,3), 0.0));
            else
                SolverOut.std_X(t) = NaN; SolverOut.std_Y(t) = NaN; SolverOut.std_Z(t) = NaN;
            end
        else
            SolverOut.X_est(t) = NaN; SolverOut.Y_est(t) = NaN; SolverOut.Z_est(t) = NaN;
            SolverOut.X(t)     = NaN; SolverOut.Y(t)     = NaN; SolverOut.Z(t)     = NaN;
            SolverOut.std_X(t) = NaN; SolverOut.std_Y(t) = NaN; SolverOut.std_Z(t) = NaN;
        end
    end
    
    dx = SolverOut.X_est - DataContext.X_true;
    dy = SolverOut.Y_est - DataContext.Y_true;
    dz = SolverOut.Z_est - DataContext.Z_true;
    SolverOut.rmse = sqrt(dx.^2 + dy.^2 + dz.^2);
    
    SolverOut.pos = [SolverOut.X_est; SolverOut.Y_est; SolverOut.Z_est];
end
