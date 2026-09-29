function scenarios = tis_trajectory_scenarios
% Integration scenario parameters: edit Y_center_true once per scenario.
    near = struct();
    % Геометрия измерительного базиса (координаты 4-х анкеров станций ТИС)
    near.Stations.X_anchors = [0.0, -5000.0, 5000.0, 2500.0] - 8000.0;
    near.Stations.Y_anchors = [0.0, 10000.0, 20000.0, 25000.0];
    near.Stations.Z_anchors = [1000.0, 1000.0, 1000.0, 1000.0] + 500.0;

    % Параметры прямолинейной траектории наведения цели
    near.Trajectory.Points = 500;
    near.Trajectory.X_limits = [-15000.0, 15000.0];
    near.Trajectory.Y_center_true = 30000.0;
    near.Trajectory.Z_base = 0.0;
    near.Trajectory.Z_amplitude = 0.0;

    % Аппаратные уставки точности и избыточности накопления тактов
    near.Hardware.D_Error_Degree = 2.0;
    near.Hardware.Random_Seed = 1337;
    near.Hardware.N_Monte_Carlo = 5000;
    near.Hardware.Fixed_N_Index = 11;

    % Независимые методы оценивания.
    near.Methods.ActiveMethods = {'Linear_LLS', 'Weighted_WLLS', 'Nonlinear_GN', 'Polar_GNP'};
    near.Methods.Labels = {'1. Чистый линейный LLS ТИС', '2. Взвешенный WLLS ТИС', ...
                               '3. Декартов Gauss-Newton ТИС', '4. Полярный инвариант ТИС'};
    near.Methods.Solvers = {'lls_position', 'wlls_position', 'gn_position', 'gnp_position'};
    near.Methods.Covariances = {'lls_covariance', 'wlls_covariance', 'gn_covariance', 'gnp_covariance'};

    % =========================================================================
    % Дальний траекторный сценарий.
    % =========================================================================
    far = struct();
    far.Stations.X_anchors = [-20000.0, 20000.0, 0.0, 0.0];
    far.Stations.Y_anchors = [0.0, 0.0, -20000.0, 20000.0];
    far.Stations.Z_anchors = [200.0, 200.0, 200.0, 200.0];

    far.Trajectory.Points = 300;
    far.Trajectory.X_limits = [-150000.0, 150000.0];
    far.Trajectory.Y_center_true = 450000.0;
    far.Trajectory.Z_base = 10000.0;
    far.Trajectory.Z_amplitude = 5000.0;

    far.Hardware.D_Error_Degree = 0.015; % Прецизионный дальний шум
    far.Hardware.Random_Seed = 1337;
    far.Hardware.N_Monte_Carlo = 5000;
    far.Hardware.Fixed_N_Index = 11;

    far.Methods.ActiveMethods = {'Linear_LLS', 'Weighted_WLLS', 'Nonlinear_GN', 'Polar_GNP'};
    far.Methods.Labels = {'1. Чистый линейный LLS ТИС', '2. Взвешенный WLLS ТИС', ...
                                '3. Декартов Gauss-Newton ТИС', '4. Полярный инвариант ТИС'};
    far.Methods.Solvers = {'lls_position', 'wlls_position', 'gn_position', 'gnp_position'};
    far.Methods.Covariances = {'lls_covariance', 'wlls_covariance', 'gn_covariance', 'gnp_covariance'};

    scenarios={near,far};
end
