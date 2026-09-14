function DataContext = service_init_geometry_30km(contextFileName)
% CORE ENGINE: INVARIANT DATA CONTEXT DISPATCHER (30KM SPLINE ISOLATION)
% SYSTEM MATRIX CONTEXT: S-SHAPE BARRIER SPLINE DISCRETIZATION / SRP ISOLATION
    if ~exist(contextFileName, 'file')
        error('Критический сбой ОЗУ: Файл контекста %s не найден.', contextFileName);
    end
    savedData = load(contextFileName);
    fFields = fields(savedData);
    cfg = savedData.(fFields{1});
    Points = 500;
    DataContext.Points = Points;
    vals = logspace(log10(4), log10(124), 20);
    DataContext.CountsVector = unique(round(vals));
    fixed_idx = cfg.Hardware.Fixed_N_Index;
    DataContext.Hardware.Fixed_N_Stations = DataContext.CountsVector(fixed_idx);
    N_FIXED = DataContext.Hardware.Fixed_N_Stations;
    X_anc = cfg.Stations.X_anchors;
    Y_anc = cfg.Stations.Y_anchors;
    Z_anc = cfg.Stations.Z_anchors;
    num_anchors = length(X_anc);
    max_N_total = max(DataContext.CountsVector);
    t_max = linspace(1, num_anchors, max_N_total);
    DataContext.P_max_matrix = [spline(1:num_anchors, X_anc, t_max); ...
                                spline(1:num_anchors, Y_anc, t_max); ...
                                spline(1:num_anchors, Z_anc, t_max)];
    DataContext.Fixed_N_Stations = N_FIXED;
    DataContext.X_true = linspace(cfg.Trajectory.X_limits(1), cfg.Trajectory.X_limits(2), Points);
    DataContext.Y_true = cfg.Trajectory.Y_center_true * ones(1, Points);
    DataContext.Z_true = zeros(1, Points);
    err_deg = cfg.Hardware.D_Error_Degree;
    rad_err = (err_deg * pi) / 180.0;
    DataContext.var_alpha_max = (rad_err^2) * ones(max_N_total, 1);
    DataContext.var_beta_max  = (rad_err^2) * ones(max_N_total, 1);
    DataContext.alpha_noisy_matrix = zeros(max_N_total, Points);
    DataContext.beta_noisy_matrix  = zeros(max_N_total, Points);
    for i = 1:max_N_total
        dx = DataContext.X_true - DataContext.P_max_matrix(1, i);
        dy = DataContext.Y_true - DataContext.P_max_matrix(2, i);
        dz = DataContext.Z_true - DataContext.P_max_matrix(3, i);
        d_horiz = sqrt(dx.^2 + dy.^2);
        DataContext.alpha_noisy_matrix(i, :) = atan2(dy, dx) + rad_err * randn(1, Points);
        DataContext.beta_noisy_matrix(i, :)  = atan2(dz, d_horiz) + rad_err * randn(1, Points);
    end
    DataContext.cfg = cfg;
    DataContext.Methods = cfg.Methods;
end
