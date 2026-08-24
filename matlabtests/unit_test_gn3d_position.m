function unit_test_gn3d_position()
% =========================================================================
% ЮНИТ-ТЕСТ: АТОМАРНАЯ ПРОВЕРКА ФУНКЦИИ GN3D_POSITION ТИС
% Path: d:\workspace\libtr\matlabtests\unit_test_gn3d_position.m
% =========================================================================

fprintf('ЗАПУСК АТОМАРНОГО ЮНИТ-ТЕСТА ДЛЯ ФУНКЦИИ: gn3d_position\n');

rmse_results = zeros(8, 1); crlb_results = zeros(8, 1); mock_delta = zeros(8, 1);

for criteria_idx = 1:5
    rmse_results(:) = 0; crlb_results(:) = 0; mock_delta(:) = 0;
    
    for r_idx = 1:8
        [P_base, x_true, y_true, z_true, N_measurements, range_steps, config] = ...
            service_init_geometry_criteria(criteria_idx, r_idx);
        
        VAR_ALPHA_BASE = deg2rad(config.DOA_ERROR_DEGREE)^2 * ones(size(P_base, 2), 1);
        VAR_BETA_BASE  = deg2rad(config.DOA_ERROR_DEGREE)^2 * ones(size(P_base, 2), 1);
        
        if criteria_idx == 5
            N_total_exp = size(P_base, 2) * min(10, max(1, round(40 / size(P_base, 2))));
        else
            N_total_exp = N_measurements;
        end
        
        [P_exp, V_alpha_exp, V_beta_exp] = service_expand_tact_matrix(P_base, VAR_ALPHA_BASE, VAR_BETA_BASE, N_total_exp);
        
        [st_f, cx, cy, cz] = lls_fisher_crlb(P_exp, V_alpha_exp, V_beta_exp, x_true, y_true, z_true);
        if st_f == 0, crlb_results(r_idx) = sqrt(cx^2 + cy^2 + cz^2); else, crlb_results(r_idx) = Inf; end
        
        [st_m, lambda_ideal] = service_ideal_mock_position(P_exp, x_true, y_true, z_true);
        if st_m == 0
            mock_delta(r_idx) = sqrt((lambda_ideal(1)-x_true)^2 + (lambda_ideal(2)-y_true)^2 + (lambda_ideal(3)-z_true)^2) * 1000;
        else
            mock_delta(r_idx) = NaN;
        end
        
        [alpha, beta] = service_add_noise_ox(P_exp, x_true, y_true, z_true, config.DOA_ERROR_DEGREE, config.CHOSEN_SEED);
        
        [status, lambda] = gn3d_position(P_exp, alpha, beta);
        if status == 0 && ~any(isnan(lambda))
            rmse_results(r_idx) = sqrt((lambda(1)-x_true)^2 + (lambda(2)-y_true)^2 + (lambda(3)-z_true)^2);
        else
            rmse_results(r_idx) = NaN;
        end
    end
    service_print_atomic_report(criteria_idx, range_steps, rmse_results, crlb_results, mock_delta, 'GN_Cartesian');
end
end
