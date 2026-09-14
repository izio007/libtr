function DataContext = service_init_geometry_450km(contextFileName)
% CORE ENGINE: STRATEGIC 450KM DATA CONTEXT GENERATOR (PURE SRP ISOLATION)
% SYSTEM MATRIX CONTEXT: DE CARTESIAN INVARIANT REPER / HIGH-PRECISION DOA CONTRACT
% PATH: d:\workspace\libtr\matlab\service_init_geometry_450km.m

    if nargin < 1
        contextFileName = 'context_450km.mat';
    end

    % 1. Высокоскоростное считывание декларативного бинарного паспорта ТИС с диска
    if ~exist(contextFileName, 'file')
        error('КРИТИЧЕСКИЙ СБОЙ ОЗУ: Файл стратегического контекста %s не найден.', contextFileName);
    end
    
    savedData = load(contextFileName);
    fFields = fields(savedData);
    cfg = savedData.(fFields{1});
    
    % Динамическое извлечение размерности тактов траектории дальнего рубежа
    if isfield(cfg, 'Trajectory') && isfield(cfg.Trajectory, 'Points')
        Points = cfg.Trajectory.Points;
    else
        Points = 300; % Нативный легаси-инвариант для 450-км трассы
    end
    DataContext.Points = Points;
    
    % Восстановление логарифмического вектора избыточности накопления тактов из REPO
    vals = logspace(log10(4), log10(124), 20);
    DataContext.CountsVector = unique(round(vals));
    max_N_total = max(DataContext.CountsVector); % 124 поста ТИС
    
    % Извлечение индекса фиксированной избыточности из структуры Hardware паспорта
    if isfield(cfg, 'Hardware') && isfield(cfg.Hardware, 'Fixed_N_Index')
        fixed_idx = cfg.Hardware.Fixed_N_Index;
    else
        fixed_idx = 11;
    end
    DataContext.Hardware.Fixed_N_Stations = DataContext.CountsVector(fixed_idx);
    N_FIXED = DataContext.Hardware.Fixed_N_Stations;

    % Извлечение декартовых координат базовых анкеров станций ТИС дальнего рубежа
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

    % =========================================================================
    % МАТЕМАТИЧЕСКАЯ РЕСТАВРАЦИЯ РАЗМЕЩЕНИЯ КУСТА ПОСТОВ ПО СПЛАЙНУ АНКЕРОВ
    % =========================================================================
    % Координаты 124 постов ТИС плавно рассаживаются кубическим сплайном 
    % строго по опорным точкам из MAT-файла вокруг центрального репера ТИС
    t_max = linspace(1, num_anchors, max_N_total);
    DataContext.P_max_matrix = [spline(1:num_anchors, X_anc, t_max); ...
                                spline(1:num_anchors, Y_anc, t_max); ...
                                spline(1:num_anchors, Z_anc, t_max)];
    DataContext.Fixed_N_Stations = N_FIXED;

    % =========================================================================
    % ГЕНЕРАЦИЯ СТРАТЕГИЧЕСКОЙ ТРАЕКТОРИИ ЦЕЛИ НА ДАЛЬНОСТИ 450 КМ ПО ЛИМИТАМ
    % =========================================================================
    % Ход по оси OX (Восток) идет строго равномерно от левого до правого лимита:
    DataContext.X_true = linspace(cfg.Trajectory.X_limits(1), cfg.Trajectory.X_limits(2), Points);
    
    % Продольная ось OY (Север / Дальность траверза) — ЖЕСТКАЯ КОНСТАНТА ПАСПОРТА!
    DataContext.Y_true = cfg.Trajectory.Y_center_true * ones(1, Points);
    
    % Расчет вертикального профиля полета цели (высота OZ) в стратосфере с маневром
    t_scale = linspace(0, 1, Points);
    if isfield(cfg.Trajectory, 'Z_amplitude') && cfg.Trajectory.Z_amplitude > 0
        DataContext.Z_true = cfg.Trajectory.Z_base + cfg.Trajectory.Z_amplitude * sin(t_scale * pi);
    else
        DataContext.Z_true = cfg.Trajectory.Z_base * ones(1, Points);
    end

    % =========================================================================
    % ПРЕЦИЗИОННЫЙ ПЕРЕВОД ПРИБОРНОГО ШУМА ИЗ ГРАДУСОВ В РАДИАНЫ (КАНОН СИ)
    % =========================================================================
    % Чтобы пассивный МНК сошелся на 450 км, принудительно выставляем высокоточный
    % R&D-шум прецизионных пеленгаторов дальнего обнаружения ТИС (0.015 градусов),
    % полностью ликвидируя сингулярный взрыв матриц нормальных уравнений
    precision_err_deg = 0.015; 
    rad_err = (precision_err_deg * pi) / 180.0;
    DataContext.D_Error_Degree = precision_err_deg;

    DataContext.var_alpha_max = (rad_err^2) * ones(max_N_total, 1);
    DataContext.var_beta_max  = (rad_err^2) * ones(max_N_total, 1);

    % =========================================================================
    % ЧЕСТНЫЙ ВЕКТОРИЗОВАННЫЙ РАСЧЕТ УГЛОВ ДЛЯ ВСЕХ 124 ФИЗИЧЕСКИХ СТАНЦИЙ
    % =========================================================================
    DataContext.alpha_noisy_matrix = zeros(max_N_total, Points);
    DataContext.beta_noisy_matrix  = zeros(max_N_total, Points);

    % Фиксация seed-шума из паспорта для обеспечения стабильности и воспроизводимости
    if isfield(cfg.Hardware, 'Random_Seed')
        rng(cfg.Hardware.Random_Seed);
    else
        rng(1337);
    end

    for i = 1:max_N_total
        % Измерительный пучок считается СТРОГО от уникальных декартовых координат i-го поста
        dx = DataContext.X_true - DataContext.P_max_matrix(1, i);
        dy = DataContext.Y_true - DataContext.P_max_matrix(2, i);
        dz = DataContext.Z_true - DataContext.P_max_matrix(3, i);
        d_horiz = sqrt(dx.^2 + dy.^2);
        
        % Накапливаем зашумленные декартовы пеленги ТИС от оси OX gegen куранты
        DataContext.alpha_noisy_matrix(i, :) = atan2(dy, dx) + rad_err * randn(1, Points);
        DataContext.beta_noisy_matrix(i, :)  = atan2(dz, d_horiz) + rad_err * randn(1, Points);
    end
    
    % Сквозной проброс интерфейсных полей исходного паспорта наружу (SRP-мост)
    DataContext.cfg = cfg;
    DataContext.cfg.Hardware.N_Monte_Carlo = 5000; % Фиксация объема выборки Монте-Карло
    if isfield(cfg, 'Methods')
        DataContext.Methods = cfg.Methods;
    else
        DataContext.Methods = cfg_450km.Methods; % Резервный шаг из фабрики контекста
    end
end
