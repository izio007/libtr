function service_run_multi_criteria_bench(fid, fh_solver, fh_covariance, labelName)
% CORE SIMULATION KERNEL: AUTOMATED MULTI-CRITERIA STRAIN TESTING BENCHMARK
% SYSTEM MATRIX CONTEXT: PURE ANALYTICAL SHIELD / ZERO NOISE MACHINE ZERO CHECK

    DataContext = service_init_geometry_criteria('context_unit_geometry.mat');
    range_steps = DataContext.X_true;
    Points = length(range_steps);
    var_alpha_base = DataContext.var_alpha_max;
    var_beta_base  = DataContext.var_beta_max;

    % --- СТРУКТУРА 1: ЦЕЛЬ ВНУТРИ БАЗОВОГО КВАДРАТА СДВИГ Z ---
    DataContext1 = DataContext;
    P_active1 = DataContext1.P_max_matrix(:, 1:4);
    for k = 1:Points
        dx = DataContext1.X_true(k) - P_active1(1, :); dy = DataContext1.Y_true(k) - P_active1(2, :); dz = DataContext1.Z_true(k) - P_active1(3, :);
        DataContext1.alpha_noisy_matrix(1:4, k) = atan2(dy, dx).'; DataContext1.beta_noisy_matrix(1:4, k)  = atan2(dz, sqrt(dx.^2 + dy.^2)).';
    end
    Out1 = run_tactical_solver(DataContext1, 4, fh_solver, fh_covariance);
    crlb1 = service_calc_crlb_trajectory(DataContext1, 4);
    crlb_Geom1 = sqrt(crlb1.X.^2 + crlb1.Y.^2 + crlb1.Z.^2);
    mock_delta1 = zeros(1, Points);
    for k = 1:Points
        mock_delta1(k) = sqrt((Out1.X_est(k)-DataContext1.X_true(k))^2 + (Out1.Y_est(k)-DataContext1.Y_true(k))^2 + (Out1.Z_est(k)-DataContext1.Z_true(k))^2);
    end
    service_print_atomic_report(1, range_steps, Out1.rmse, crlb_Geom1, mock_delta1, labelName);

    % --- СТРУКТУРА 2: ЦЕЛЬ СНАРУЖИ В КВАДРАНТАХ ПО ДАЛЬНОСТИ ---
    DataContext2 = DataContext;
    P_active2 = DataContext2.P_max_matrix(:, 1:4);
    for k = 1:Points
        q_num = mod(k - 1, 4) + 1; R_val = abs(range_steps(k));
        x_signs = [1, -1, -1, 1]; y_signs = [1, 1, -1, -1];
        DataContext2.X_true(k) = R_val * x_signs(q_num); DataContext2.Y_true(k) = 15000.0 * y_signs(q_num);
        dx = DataContext2.X_true(k) - P_active2(1, :); dy = DataContext2.Y_true(k) - P_active2(2, :); dz = DataContext2.Z_true(k) - P_active2(3, :);
        DataContext2.alpha_noisy_matrix(1:4, k) = atan2(dy, dx).'; DataContext2.beta_noisy_matrix(1:4, k)  = atan2(dz, sqrt(dx.^2 + dy.^2)).';
    end
    Out2 = run_tactical_solver(DataContext2, 4, fh_solver, fh_covariance);
    crlb2 = service_calc_crlb_trajectory(DataContext2, 4);
    crlb_Geom2 = sqrt(crlb2.X.^2 + crlb2.Y.^2 + crlb2.Z.^2);
    mock_delta2 = zeros(1, Points);
    for k = 1:Points
        mock_delta2(k) = sqrt((Out2.X_est(k)-DataContext2.X_true(k))^2 + (Out2.Y_est(k)-DataContext2.Y_true(k))^2 + (Out2.Z_est(k)-DataContext2.Z_true(k))^2);
    end
    service_print_atomic_report(2, range_steps, Out2.rmse, crlb_Geom2, mock_delta2, labelName);

    % --- СТРУКТУРА 3: ИЗМЕРИТЕЛЬНАЯ ДВОЙКА СТАНЦИЙ (М=2) ---
    DataContext3 = DataContext;
    P_active3 = DataContext3.P_max_matrix(:, 1:2);
    for k = 1:Points
        dx = DataContext3.X_true(k) - P_active3(1, :); dy = DataContext3.Y_true(k) - P_active3(2, :); dz = DataContext3.Z_true(k) - P_active3(3, :);
        DataContext3.alpha_noisy_matrix(1:2, k) = atan2(dy, dx).'; DataContext3.beta_noisy_matrix(1:2, k)  = atan2(dz, sqrt(dx.^2 + dy.^2)).';
    end
    Out3 = run_tactical_solver(DataContext3, 2, fh_solver, fh_covariance);
    crlb3 = service_calc_crlb_trajectory(DataContext3, 2);
    crlb_Geom3 = sqrt(crlb3.X.^2 + crlb3.Y.^2 + crlb3.Z.^2);
    mock_delta3 = zeros(1, Points);
    for k = 1:Points
        mock_delta3(k) = sqrt((Out3.X_est(k)-DataContext3.X_true(k))^2 + (Out3.Y_est(k)-DataContext3.Y_true(k))^2 + (Out3.Z_est(k)-DataContext3.Z_true(k))^2);
    end
    service_print_atomic_report(3, range_steps, Out3.rmse, crlb_Geom3, mock_delta3, labelName);

    % --- СТРУКТУРА 4: ЭКСТРЕМАЛЬНАЯ ВЫСОТА ЦЕЛИ Z = 0 ---
    DataContext4 = DataContext;
    DataContext4.Z_true(:) = 0.0;
    P_active4 = DataContext4.P_max_matrix(:, 1:4);
    for k = 1:Points
        dx = DataContext4.X_true(k) - P_active4(1, :); dy = DataContext4.Y_true(k) - P_active4(2, :); dz = 0.0 - P_active4(3, :);
        DataContext4.alpha_noisy_matrix(1:4, k) = atan2(dy, dx).'; DataContext4.beta_noisy_matrix(1:4, k)  = atan2(dz, sqrt(dx.^2 + dy.^2)).';
    end
    Out4 = run_tactical_solver(DataContext4, 4, fh_solver, fh_covariance);
    crlb4 = service_calc_crlb_trajectory(DataContext4, 4);
    crlb_Geom4 = sqrt(crlb4.X.^2 + crlb4.Y.^2 + crlb4.Z.^2);
    mock_delta4 = zeros(1, Points);
    for k = 1:Points
        mock_delta4(k) = sqrt((Out4.X_est(k)-DataContext4.X_true(k))^2 + (Out4.Y_est(k)-DataContext4.Y_true(k))^2 + (Out4.Z_est(k)-DataContext4.Z_true(k))^2);
    end
    service_print_atomic_report(4, range_steps, Out4.rmse, crlb_Geom4, mock_delta4, labelName);

    % --- СТРУКТУРА 5: МНОГОКРАТНЫЕ ТАКТЫ НАКОПЛЕНИЯ С ПОСТОВ ---
    max_M = length(var_alpha_base);
    DataContext5 = DataContext;
    [DataContext5.P_max_matrix, DataContext5.var_alpha_max, DataContext5.var_beta_max] = service_expand_tact_matrix(DataContext5.P_max_matrix(:, 1:4), var_alpha_base(1:4), var_beta_base(1:4), max_M);
    for k = 1:Points
        dx = DataContext5.X_true(k) - DataContext5.P_max_matrix(1, 1:max_M); dy = DataContext5.Y_true(k) - DataContext5.P_max_matrix(2, 1:max_M); dz = DataContext5.Z_true(k) - DataContext5.P_max_matrix(3, 1:max_M);
        DataContext5.alpha_noisy_matrix(1:max_M, k) = atan2(dy, dx).'; DataContext5.beta_noisy_matrix(1:max_M, k)  = atan2(dz, sqrt(dx.^2 + dy.^2)).';
    end
    Out5 = run_tactical_solver(DataContext5, max_M, fh_solver, fh_covariance);
    crlb5 = service_calc_crlb_trajectory(DataContext5, max_M);
    crlb_Geom5 = sqrt(crlb5.X.^2 + crlb5.Y.^2 + crlb5.Z.^2);
    mock_delta5 = zeros(1, Points);
    for k = 1:Points
        mock_delta5(k) = sqrt((Out5.X_est(k)-DataContext5.X_true(k))^2 + (Out5.Y_est(k)-DataContext5.Y_true(k))^2 + (Out5.Z_est(k)-DataContext5.Z_true(k))^2);
    end
    service_print_atomic_report(5, range_steps, Out5.rmse, crlb_Geom5, mock_delta5, labelName);
end
