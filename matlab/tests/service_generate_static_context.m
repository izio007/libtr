function service_generate_static_context
% Persist scenario configurations; names are derived, never used as dispatch keys.
    scenarios=tis_trajectory_scenarios;
    for k=1:numel(scenarios)
        cfg=scenarios{k};
        save(tis_context_filename(cfg),'cfg');
    end
    cfg_single = struct();
    cfg_single.Stations.X_anchors = [-5000.0, 5000.0, -5000.0, 5000.0];
    cfg_single.Stations.Y_anchors = [-5000.0, -5000.0, 5000.0, 5000.0];
    cfg_single.Stations.Z_anchors = [0.0, 0.0, 0.0, 0.0];

    cfg_single.Trajectory.Points = 1;
    cfg_single.Trajectory.X_limits = [1200.0, 1200.0];
    cfg_single.Trajectory.Y_center_true = 15000.0;
    cfg_single.Trajectory.Z_base = 3000.0;
    cfg_single.Trajectory.Z_amplitude = 0.0;

    cfg_single.Hardware.D_Error_Degree = 0.1;
    cfg_single.Hardware.Random_Seed = 1337;
    cfg_single.Hardware.N_Monte_Carlo = 5000;
    cfg_single.Hardware.Fixed_N_Index = 1;

    cfg_single.Methods.ActiveMethods = {'Linear_LLS', 'Weighted_WLLS', 'Nonlinear_GN', 'Polar_GNP'};
    cfg_single.Methods.Labels = {'1. Чистый линейный LLS ТИС', '2. Взвешенный WLLS ТИС', ...
                                 '3. Декартов Gauss-Newton ТИС', '4. Полярный инвариант ТИС'};
    cfg_single.Methods.Solvers = {'lls_position', 'wlls_position', 'gn_position', 'gnp_position'};
    cfg_single.Methods.Covariances = {'lls_covariance', 'wlls_covariance', 'gn_covariance', 'gnp_covariance'};
    save('context_single_point.mat', 'cfg_single');

    % =========================================================================
    % --- 4. ВЕРИФИКАЦИОННЫЙ ПОЛИГОН: БЕНЧМАРК ПЯТИ СТРУКТУР ТИС ---
    % =========================================================================
    cfg_unit = struct();
    cfg_unit.Stations.X_anchors = [-5000.0, 5000.0, -5000.0, 5000.0];
    cfg_unit.Stations.Y_anchors = [-5000.0, -5000.0, 5000.0, 5000.0];
    cfg_unit.Stations.Z_anchors = [0.0, 0.0, 0.0, 0.0];

    cfg_unit.Trajectory.RangeSteps = [-10000.0, -8600.0, -5200.0, 2900.0, 22300.0, 68900.0, 180900.0, 160000.0];
    cfg_unit.Trajectory.Y_center_true = 15000.0;
    cfg_unit.Trajectory.Z_base = 3000.0;

    cfg_unit.Hardware.D_Error_Degree = 2.0;
    cfg_unit.Hardware.Random_Seed = 1337;
    cfg_unit.Hardware.N_Monte_Carlo = 5000;
    cfg_unit.Hardware.Fixed_N_Index = 1;

    cfg_unit.Methods.ActiveMethods = {'Linear_LLS', 'Weighted_WLLS', 'Nonlinear_GN', 'Polar_GNP'};
    cfg_unit.Methods.Labels = {'Linear_LLS', 'Weighted_WLLS', 'GN_Cartesian', 'GN_Polar'};
    cfg_unit.Methods.Solvers = {'lls_position', 'wlls_position', 'gn_position', 'gnp_position'};
    cfg_unit.Methods.Covariances = {'lls_covariance', 'wlls_covariance', 'gn_covariance', 'gnp_covariance'};
    save('context_unit_geometry.mat', 'cfg_unit');
end
