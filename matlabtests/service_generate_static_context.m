function service_generate_static_context
% FACTORY KERNEL: DECLARATIVE STATIC PASSPORT CONFIGURATION CONTEXTS (STRICT SRP ALIGNMENT)
% SYSTEM MATRIX CONTEXT: DE CARTESIAN INVARIANT REPER / SOLID COMPATIBILITY
% PATH: f:\sy\workspace\libtr\matlab\service_generate_static_context.m

    % =========================================================================
    % --- 1. КОНТЕКСТ БЛИЖНЕЙ ЗОНЫ: ПОЛЕТНЫЙ СЦЕНАРИЙ 30 КМ ---
    % =========================================================================
    cfg_30km = struct();
    % Геометрия измерительного базиса (координаты 4-х анкеров станций ТИС)
    cfg_30km.Stations.X_anchors = [0.0, -5000.0, 5000.0, 2500.0] - 8000.0;
    cfg_30km.Stations.Y_anchors = [0.0, 10000.0, 20000.0, 25000.0];
    cfg_30km.Stations.Z_anchors = [1000.0, 1000.0, 1000.0, 1000.0] + 500.0;
    
    % Параметры прямолинейной траектории наведения цели
    cfg_30km.Trajectory.Points = 500;
    cfg_30km.Trajectory.X_limits = [-15000.0, 15000.0]; 
    cfg_30km.Trajectory.Y_center_true = 30000.0;       
    cfg_30km.Trajectory.Z_base = 0.0;
    cfg_30km.Trajectory.Z_amplitude = 0.0;
    
    % Аппаратные уставки точности и избыточности накопления тактов
    cfg_30km.Hardware.D_Error_Degree = 2.0;            
    cfg_30km.Hardware.Random_Seed = 1337;
    cfg_30km.Hardware.N_Monte_Carlo = 5000;
    cfg_30km.Hardware.Fixed_N_Index = 11;              
    
    % ПОБИТОВОЕ ВЫРАВНИВАНИЕ ИНДЕКСОВ ШИНЫ МЕТОДОВ ПОД КЛАСС TisIntegrationSandbox
    cfg_30km.Methods.ActiveMethods = {'Linear_LLS', 'Weighted_WLLS', 'Nonlinear_GN', 'Polar_GNP'};
    cfg_30km.Methods.Labels = {'1. Чистый линейный LLS ТИС', '2. Взвешенный WLLS ТИС', ...
                               '3. Декартов Gauss-Newton ТИС', '4. Полярный инвариант ТИС'};
    cfg_30km.Methods.Solvers = {'lls_position', 'wlls_position', 'gn_position', 'gnp_position'};
    cfg_30km.Methods.Covariances = {'lls_covariance', 'wlls_covariance', 'gn_covariance', 'gnp_covariance'};
    save('context_30km.mat', 'cfg_30km');

    % =========================================================================
    % --- 2. КОНТЕКСТ ДАЛЬНЕЙ ЗОНЫ: СТРАТЕГИЧЕСКИЙ РУБЕЖ 450 КМ ---
    % =========================================================================
    cfg_450km = struct();
    cfg_450km.Stations.X_anchors = [-20000.0, 20000.0, 0.0, 0.0];
    cfg_450km.Stations.Y_anchors = [0.0, 0.0, -20000.0, 20000.0];
    cfg_450km.Stations.Z_anchors = [200.0, 200.0, 200.0, 200.0];
    
    cfg_450km.Trajectory.Points = 300;
    cfg_450km.Trajectory.X_limits = [-150000.0, 150000.0];
    cfg_450km.Trajectory.Y_center_true = 450000.0;     
    cfg_450km.Trajectory.Z_base = 10000.0;              
    cfg_450km.Trajectory.Z_amplitude = 5000.0;         
    
    cfg_450km.Hardware.D_Error_Degree = 0.015; % Прецизионный дальний шум
    cfg_450km.Hardware.Random_Seed = 1337;
    cfg_450km.Hardware.N_Monte_Carlo = 5000;
    cfg_450km.Hardware.Fixed_N_Index = 11;
    
    cfg_450km.Methods.ActiveMethods = {'Linear_LLS', 'Weighted_WLLS', 'Nonlinear_GN', 'Polar_GNP'};
    cfg_450km.Methods.Labels = {'1. Чистый линейный LLS ТИС', '2. Взвешенный WLLS ТИС', ...
                                '3. Декартов Gauss-Newton ТИС', '4. Полярный инвариант ТИС'};
    cfg_450km.Methods.Solvers = {'lls_position', 'wlls_position', 'gn_position', 'gnp_position'};
    cfg_450km.Methods.Covariances = {'lls_covariance', 'wlls_covariance', 'gn_covariance', 'gnp_covariance'};
    save('context_450km.mat', 'cfg_450km');

    % =========================================================================
    % --- 3. СТАТИЧЕСКИЙ КОНТЕКСТ НА ОДНУ ДЕТЕРМИНИРОВАННУЮ ТОЧКУ ---
    % =========================================================================
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
    
    cfg_unit.Trajectory.RangeSteps = [-10000.0, -8600.0, -5200.0, 2900.0, 22300.0, 68900.0, 180900.0, 450000.0];
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
