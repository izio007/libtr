function DataContext = service_init_geometry_unit(contextFileName)
% CORE ENGINE: INVARIANT DATA CONTEXT DISPATCHER (QUIET UNIT ISOLATION CONTRACT)
% SYSTEM MATRIX CONTEXT: MULTI-CRITERIA STRAIN TESTING / ZERO NOISE ANALYTICAL BASE
% PATH: d:\workspace\libtr\matlabtests\service_init_geometry_unit.m

    if nargin < 1
        contextFileName = 'context_unit_geometry.mat';
    end

    % 1. Высокоскоростное считывание декларативного бинарного паспорта ТИС с диска
    if ~exist(contextFileName, 'file')
        error('КРИТИЧЕСКИЙ СБОЙ ОЗУ: Файл контекста полигона %s не найден.', contextFileName);
    end
    
    savedData = load(contextFileName);
    fFields = fields(savedData);
    cfg = savedData.(fFields{1});
    
    % Восстановление логарифмического вектора избыточности накопления тактов из REPO
    vals = logspace(log10(4), log10(124), 20);
    DataContext.CountsVector = unique(round(vals));
    
    % Фиксация стартового индекса накопления избыточности для Сабплотов 1 и 2
    if isfield(cfg, 'Hardware') && isfield(cfg.Hardware, 'Fixed_N_Index')
        fixed_idx = cfg.Hardware.Fixed_N_Index;
    else
        fixed_idx = 1; % Фиксируем строго базовую четверку постов
    end
    DataContext.Hardware.Fixed_N_Stations = DataContext.CountsVector(fixed_idx);
    N_FIXED = DataContext.Hardware.Fixed_N_Stations;
    
    % Извлечение декартовых координат базовых анкеров станций ТИС из MAT-файла
    if isfield(cfg, 'Stations')
        X_anc = cfg.Stations.X_anchors;
        Y_anc = cfg.Stations.Y_anchors;
        Z_anc = cfg.Stations.Z_anchors;
    else
        X_anc = cfg.X_anchors;
        Y_anc = cfg.Y_anchors;
        Z_anc = cfg.Z_anchors;
    end
    num_anchors = length(X_anc);
    
    max_N_total = max(DataContext.CountsVector); % 124 поста ТИС
    t_max = linspace(1, num_anchors, max_N_total);
    
    % Сплайновое развертывание 124 декартовых координат измерительного полигона
    DataContext.P_max_matrix = [spline(1:num_anchors, X_anc, t_max); ...
                                spline(1:num_anchors, Y_anc, t_max); ...
                                spline(1:num_anchors, Z_anc, t_max)];
    DataContext.Fixed_N_Stations = N_FIXED;
    
    % =========================================================================
    % ПОБИТОВОЕ СОПРЯЖЕНИЕ ВЕКТОРОВ ШАГОВ ДАЛЬНОСТИ ИЗ ПАСПОРТА REPO
    % =========================================================================
    % Атомарный бенчмарк пяти структур работает строго по 8 реперным точкам дальности!
    DataContext.X_true = cfg.Trajectory.RangeSteps;
    Points = length(DataContext.X_true);
    DataContext.Points = Points;
    
    % Поперечная ось траверза (Y) и высота (Z) жестко считываются из конфигурации
    DataContext.Y_true = cfg.Trajectory.Y_center_true * ones(1, Points);
    DataContext.Z_true = cfg.Trajectory.Z_base * ones(1, Points);
    
    % =========================================================================
    % МАТЕМАТИЧЕСКАЯ СТЕРИЛИЗАЦИЯ ДИСПЕРСИЙ ВЕСОВ И АНАЛИТИЧЕСКИХ ПЕЛЕНГОВ
    % =========================================================================
    % В соответствии с lls_theory.m, для контроля машинного нуля МНК веса Гаусса-Маркова 
    % обязаны быть строго нулевыми, исключая ложную асимметрию расчетных шкал!
    DataContext.var_alpha_max = zeros(max_N_total, 1);
    DataContext.var_beta_max  = zeros(max_N_total, 1);
    
    DataContext.alpha_noisy_matrix = zeros(max_N_total, Points);
    DataContext.beta_noisy_matrix  = zeros(max_N_total, Points);
    
    for i = 1:max_N_total
        % Сверхточный аналитический расчет углов визирования цели ENU от оси OX
        dx = DataContext.X_true - DataContext.P_max_matrix(1, i);
        dy = DataContext.Y_true - DataContext.P_max_matrix(2, i);
        dz = DataContext.Z_true - DataContext.P_max_matrix(3, i);
        d_horiz = sqrt(dx.^2 + dy.^2);
        
        % Кристально чистые бесшумные пеленги без randn() наложения флуктуаций
        DataContext.alpha_noisy_matrix(i, :) = atan2(dy, dx);
        DataContext.beta_noisy_matrix(i, :)  = atan2(dz, d_horiz);
    end
    
    DataContext.cfg = cfg;
    if isfield(cfg, 'Methods')
        DataContext.Methods = cfg.Methods;
    end
end
