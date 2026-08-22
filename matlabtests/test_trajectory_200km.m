% =========================================================================
% ПРИКЛАДНОЙ ИНТЕГРАЦИОННЫЙ ТЕСТ ТИС: ВАРИАНТ «СТРАТЕГИЧЕСКИЙ КУСТ 450 КМ»
% Responsibility: 100% побитовое соответствие вызова matplot_trajectory_200km_screen_dynamic
% Path: d:\workspace\libtr\matlabtests\test_trajectory_200km.m
% =========================================================================

clear; clc; close all;

% 1. ГЕОМЕТРИЧЕСКИЙ КОНФИГ КРЕСТА ОПОРНЫХ СТАНЦИЙ ТИС НА МЕСТНОСТИ
cfg.Stations.Positions_Base = [-20000,  20000,      0,      0; 
                                    0,      0, -20000,  20000; 
                                    0,      0,      0,      0];

% 2. ПАРАМЕТРЫ СВЕРХДАЛЬНЕЙ ТРАЕКТОРИИ ПОЛЕТА ЦЕЛИ
cfg.Trajectory.X_limits     = [-150000, 150000];
cfg.Trajectory.Y_center_true = 450000; % Стратегический рубеж сопровождения 450 км
cfg.Trajectory.Points        = 300;
cfg.Trajectory.Z_amplitude   = 5000;
cfg.Trajectory.Z_base        = 10000;

% 3. ХАРАКТЕРИСТИКИ ИЗМЕРИТЕЛЬНОГО КОНТУРА ТИС И СТАТИСТИКИ
cfg.Hardware.D_Error_Degree = 2.0;
cfg.Hardware.Fixed_N_Index  = 11;    % Уставка на 24 накопленных такта ТИС
cfg.Hardware.N_Monte_Carlo  = 5000;  % Объем статистических пробросов Монте-Карло

% 4. ЦЕНТРАЛИЗОВАННЫЙ ВЫБОР МЕТОДОВ НА ИСТЬСПЫТАНИЕ
cfg.ActiveMethods = {'LLS', 'WLLS', 'GN_Cartesian', 'GN_Polar'};

% 5. СТАРТ АВТОМАТИЧЕСКОГО КОНВЕЙЕРА И ИЗВЛЕЧЕНИЕ ЧИСТЫХ МАТРИЦ ДАННЫХ
sandbox = TisIntegrationSandbox(cfg);
[summaryData, countsVector, fixedN, mcDataOut, max_ylim_km, xTrue] = sandbox.runTrajectory200km();

% Восстанавливаем плоский вектор истинной дальности из оригинального ядра
yTrue = cfg.Trajectory.Y_center_true * ones(size(xTrue));

method_labels = {'1. Чистый линейный LLS ТИС', '2. Взвешенный WLLS ТИС', ...
                 '3. Декартов GN ТИС', '4. Полярный инвариант ТИС'};
             
method_map = containers.Map({'LLS', 'WLLS', 'GN_Cartesian', 'GN_Polar'},[1,2,3,4]);

% =========================================================================
% 6. ПРЯМОЙ ВЫЗОВ ОРИГИНАЛЬНОГО ДИНАМИЧЕСКОГО ЭКРАНА ТИС НА ПРИКЛАДНОМ УРОВНЕ
% =========================================================================
for i = 1:length(cfg.ActiveMethods)
    methodName = cfg.ActiveMethods{i};
    m_idx = method_map(methodName);
    
    % Извлекаем честное декартово облако траекторных оценок [3 x Points]
    fixed_m = sandbox.getFixedStructure(methodName);
    summary_m_rmse = summaryData.(methodName).rmse;
    mc_y_m = mcDataOut.(methodName);
    
    % Формируем структуру plot_pos строго по реальным координатам полета цели
    clear plot_pos;
    plot_pos.X = fixed_m.pos(1, :); % Честный декартов трек цели от -150 до +150 км
    plot_pos.Y = fixed_m.pos(2, :); % Траекторная оценка дальности с учетом Bias-сжатия
    
    % Сквозной вызов оригинального графического экрана 
    matplot_trajectory_200km_screen_dynamic(...
        xTrue, yTrue, cfg.Stations.Positions_Base, plot_pos, summary_m_rmse, ...
        mc_y_m, cfg.Trajectory.Y_center_true, method_labels{m_idx}, m_idx, countsVector, max_ylim_km);
end


% 7. АВТОМАТИЗИРОВАННЫЙ ИНЖЕНЕРНО-АНАЛИТИЧЕСКИЙ ОТЧЕТ ТИС В КОНСОЛИ
fprintf('        ИНЖЕНЕРНО-АНАЛИТИЧЕСКИЙ ОТЧЕТ ТИС ПО ВАРИАНТУ «СТРАТЕГИЧЕСКИЙ КУСТ 450 КМ»\n');
fprintf('Паспортные условия: Угловой шум датчиков = %.1f град., Рубеж сопровождения = %.1f км\n', ...
    cfg.Hardware.D_Error_Degree, cfg.Trajectory.Y_center_true / 1000);
fprintf('Контрольная точка анализа: Временное накопление = %d тактов ТИС\n', fixedN);
fprintf('Объем статистических испытаний Монте-Карло = %d пробросов\n', cfg.Hardware.N_Monte_Carlo);

idx24 = find(countsVector == fixedN, 1);

for i = 1:length(cfg.ActiveMethods)
    method = cfg.ActiveMethods{i};
    rmseVal = summaryData.(method).rmse(idx24) / 1000; 
    stdMC = std(mcDataOut.(method)) / 1000;           
    biasMC = (mean(mcDataOut.(method)) - cfg.Trajectory.Y_center_true) / 1000;
    
    fprintf('Метод: %-12s | RMSE (траектория): %6.2f км | СКО MC (dY): %6.2f км | Bias MC (Y): %+6.2f км\n', ...
        method, rmseVal, stdMC, biasMC);
end
fprintf('--------------------------------------------------------------------------------\n');

if any(strcmp(cfg.ActiveMethods, 'LLS')) && any(strcmp(cfg.ActiveMethods, 'GN_Polar'))
    lls_rmse_far = summaryData.LLS.rmse(idx24) / 1000;
    polar_rmse_far = summaryData.GN_Polar.rmse(idx24) / 1000;
    
    if lls_rmse_far > 1.8 * polar_rmse_far
        fprintf('⚠️  КРИТИЧЕСКОЕ ПРЕДУПРЕЖДЕНИЕ: На рубеже 450 км зафиксирован крах декартовой линеаризации LLS.\n');
        fprintf('   Линейный промах составляет %.1f км против %.1f км у полярного итерационного МНК.\n', ...
            lls_rmse_far, polar_rmse_far);
        fprintf('   Причина: Тригонометрическое Bias-сжатие плоскостей связи стягивает LLS к базе.\n');
        fprintf('   Рекомендация: В алгоритмах фильтрации ТИС дальнего рубежа метод LLS ЗАПРЕТИТЬ к применению.\n');
    else
        fprintf('✔️  Точностные характеристики линейных и нелинейных ядер ТИС сопоставимы.\n');
    end
end


