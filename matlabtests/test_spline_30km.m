% =========================================================================
% ПРИКЛАДНОЙ ИНТЕГРАЦИОННЫЙ ТЕСТ ТИС: ВАРИАНТ «МНОГОПОЗИЦИОННЫЙ БАРЬЕР 30 КМ»
% Responsibility: Управление параметрами, выбор методов ТИС, вывод и анализ
% Path: d:\workspace\libtr\matlabtests\test_spline_30km.m
% =========================================================================

clear; clc; close all;

% 1. ГЕОМЕТРИЧЕСКИЙ КОНФИГ БАРЬЕРА ТИС НА МЕСТНОСТИ (АУТЕНТИЧНЫЕ АНКЕРЫ)
cfg.Stations.X_anchors = [0, -5000, 5000, 625*4] - 8000;
cfg.Stations.Y_anchors =[0, 10000, 20000, 25000];
cfg.Stations.Z_anchors =[    1000,     1000,     1000,     1000]+500;

% 2. ПАРАМЕТРЫ ПРИКЛАДНОЙ ТРАЕКТОРИИ ПОЛЕТА ЦЕЛИ
cfg.Trajectory.X_limits = [-15000, 15000];
cfg.Trajectory.Y_static = 30000;
cfg.Trajectory.Z_static = 0;
cfg.Trajectory.Points   = 500;

% 3. ХАРАКТЕРИСТИКИ ИЗМЕРИТЕЛЬНОГО КОНТУРА ТИС
cfg.Hardware.D_Error_Degree = 2.0; % Настройка шума (вы меняете вручную)
cfg.Hardware.Fixed_N_Index  = 11;  % Уставка на 24 поста ТИС

% 4. ЦЕНТРАЛИЗОВАННЫЙ ВЫБОР МЕТОДОВ НА ИССЛЕДОВАНИЕ (УПРАВЛЕНИЕ ТУТ)
% Допустимые идентификаторы: 'LLS', 'WLLS', 'GN_Cartesian', 'GN_Polar'
cfg.ActiveMethods = {'LLS', 'WLLS', 'GN_Cartesian', 'GN_Polar'};

% 5. СТАРТ АВТОМАТИЧЕСКОГО КОНВЕЙЕРА И ИЗВЛЕЧЕНИЕ ЧИСТЫХ МАТРИЦ ДАННЫХ
sandbox = TisIntegrationSandbox(cfg);
[summaryData, countsVector, fixedN, crlbData, xTrue] = sandbox.run();

% 6. ПРЯМОЙ И ЖЕСТКИЙ ВЫЗОВ СЦЕНАРНЫХ ЭКРАНОВ СТРОГО ДЛЯ ВЫБРАННЫХ МЕТОДОВ
method_labels = {'1. Чистый линейный LLS ТИС', '2. Взвешенный WLLS ТИС', ...
                 '3. Декартов Gauss-Newton ТИС', '4. Полярный инвариант ТИС'};
             
method_map = containers.Map({'LLS', 'WLLS', 'GN_Cartesian', 'GN_Polar'}, [1, 2, 3, 4]);

for i = 1:length(cfg.ActiveMethods)
    methodName = cfg.ActiveMethods{i};
    m_idx = method_map(methodName);
    
    fixed_m = sandbox.getFixedStructure(methodName);
    summary_m = summaryData.(methodName);
    
    % Вызов оригинального графического экрана ТИС на верхнем прикладном уровне!
    matplot_verification_screen(xTrue, cfg.Trajectory.Y_static * ones(size(xTrue)), ...
        cfg.Stations.X_anchors, cfg.Stations.Y_anchors, ...
        fixed_m, summary_m, crlbData, countsVector, fixedN, method_labels{m_idx}, m_idx);
end

% 7. АВТОМАТИЗИРОВАННЫЙ ИНЖЕНЕРНО-АНАЛИТИЧЕСКИЙ ОТЧЕТ ТИС В КОНСОЛИ
fprintf('\n================================================================================\n');
fprintf('        ИНЖЕНЕРНО-АНАЛИТИЧЕСКИЙ ОТЧЕТ ТИС ПО ВАРИАНТУ «СПЛАЙН-БАРЬЕР 30 КМ»\n');
fprintf('================================================================================\n');
fprintf('Паспортные условия: Угловой шум датчиков = %.1f град., Цель на траверзе = %.1f км\n', ...
    cfg.Hardware.D_Error_Degree, cfg.Trajectory.Y_static / 1000);
fprintf('Контрольная точка анализа: Избыточность сети N = %d постов ТИС\n', fixedN);
fprintf('--------------------------------------------------------------------------------\n');

idx24 = find(countsVector == fixedN, 1);

for i = 1:length(cfg.ActiveMethods)
    method = cfg.ActiveMethods{i};
    rmseVal = summaryData.(method).rmse(idx24);
    biasVal = summaryData.(method).bias_y(idx24);
    maxMiss = summaryData.(method).max_miss(idx24);
    
    fprintf('Метод: %-12s | RMSE: %6.1f м | Bias Y: %6.1f м | Max Miss: %6.1f м\n', ...
        method, rmseVal, biasVal, maxMiss);
end
fprintf('--------------------------------------------------------------------------------\n');

% Анализ декартова сжатия МНК на флангах трассы ТИС
if any(strcmp(cfg.ActiveMethods, 'LLS')) && any(strcmp(cfg.ActiveMethods, 'GN_Polar'))
    lls_bias = abs(summaryData.LLS.bias_y(idx24));
    polar_bias = abs(summaryData.GN_Polar.bias_y(idx24));
    
    if lls_bias > 2 * polar_bias
        fprintf('⚠️  ВНИМАНИЕ: Зафиксировано тригонометрическое сжатие (Bias) линейного метода LLS.\n');
        fprintf('   Сдвиг LLS к измерительной базе составляет %.1f м против %.1f м у полярного GN.\n', ...
            lls_bias, polar_bias);
        fprintf('   Рекомендация: Для сопровождения на флангах барьера использовать строго GN_Polar.\n');
    else
        fprintf('✔️  Геометрическая устойчивость в норме. Смещение оценок к базе незначительно.\n');
    end
end

[~, peakIdx] = max(crlbData.Y);
fprintf('Анализ флангового вырождения: Теоретический пик CRLB на краю трассы (X = %.1f км) составляет %.1f м.\n', ...
    xTrue(peakIdx)/1000, crlbData.Y(peakIdx));
fprintf('================================================================================\n');
