TRAJECTORY_POINTS_COUNT = 1000;
TARGET_X_START  = -15000;
TARGET_X_FINISH =  15000;
TARGET_Y_STATIC =  30000; 
TARGET_Z_STATIC =  0;

% Геометрия опорных точек сплайна
STATION_X_ANCHORS = [0, -5000, 5000, 625*4] + 8000;
STATION_Y_ANCHORS =[0, 10000, 20000, 25000];
STATION_Z_ANCHORS =[    1000,     1000,     1000,     1000];

DOA_ERROR_DEGREE = 0.4;
RANDOM_SEED = 1337;

% Вектор всех исследуемых вариантов для сводных графиков
vals = logspace(log10(start), log10(stop), n);
vals_int = round(vals);
vals_int = unique(vals_int);  % убираем повторы из‑за округления
STATION_COUNTS_VECTOR = vals_int; 

% Фиксированное количество станций для детального временного графика (Старый формат)
FIXED_N_STATIONS = STATION_COUNTS_VECTOR(19);



% Генерация траектории движения цели
t_steps = linspace(0, 1, TRAJECTORY_POINTS_COUNT);
x_true = TARGET_X_START + (TARGET_X_FINISH - TARGET_X_START) * t_steps;
y_true = TARGET_Y_STATIC * ones(size(t_steps));
z_true = TARGET_Z_STATIC * ones(size(t_steps));

% Генерация физических координат 107 шаров вдоль смещенного сплайна
t_anchors = 1:length(STATION_X_ANCHORS);
t_query = linspace(1, length(STATION_X_ANCHORS), N_STATIONS);
STATION_POSITIONS = [spline(t_anchors, STATION_X_ANCHORS, t_query); ...
                     spline(t_anchors, STATION_Y_ANCHORS, t_query); ...
                     spline(t_anchors, STATION_Z_ANCHORS, t_query)];

% Паспортные дисперсии шума в радианах для каждого канала
VAR_ALPHA = deg2rad(DOA_ERROR_DEGREE)^2 * ones(N_STATIONS, 1);
VAR_BETA  = deg2rad(DOA_ERROR_DEGREE)^2 * ones(N_STATIONS, 1);

% Буферы для накопления истинной теоретической границы Рао-Крамера (CRLB)
crlb_std_X = zeros(TRAJECTORY_POINTS_COUNT, 1);
crlb_std_Y = zeros(TRAJECTORY_POINTS_COUNT, 1);
crlb_std_Z = zeros(TRAJECTORY_POINTS_COUNT, 1);

% =========================================================================
% ВЫЧИСЛЕНИЕ МАТРИЦЫ ФИШЕРА И ГРАНИЦЫ РАО-КРАМЕРА (ПО ВСЕЙ ТРАЕКТОРИИ)
% =========================================================================
for k = 1:TRAJECTORY_POINTS_COUNT
    X_t = x_true(k);
    Y_t = y_true(k);
    Z_t = z_true(k);
    
    % Инициализация информационной матрицы Фишера 3х3
    I_Fisher = zeros(3, 3);
    
    for i = 1:N_STATIONS
        xs = STATION_POSITIONS(1, i);
        ys = STATION_POSITIONS(2, i);
        zs = STATION_POSITIONS(3, i);
        
        % Реальные декартовы расстояния от i-го шара до текущей точки цели
        dx = X_t - xs; 
        dy = Y_t - ys; 
        dz = Z_t - zs;
        
        rho_xy = sqrt(dx^2 + dy^2); 
        rho = sqrt(dx^2 + dy^2 + dz^2);
        
        if rho_xy < 1e-3, rho_xy = 1e-3; end
        if rho < 1e-3, rho = 1e-3; end
        
        % Теоретические ракурсы визирования (без случайного шума!)
        alpha_theo = atan2(dy, dx); 
        beta_theo  = atan2(dz, rho_xy);
        
        sa = sin(alpha_theo); ca = cos(alpha_theo);
        sb = sin(beta_theo);  cb = cos(beta_theo);
        
        % Строки Якобиана (чувствительность углов к изменению декартовых координат)
        J_alpha = [-sa/rho_xy,  ca/rho_xy, 0];
        J_beta  = [-ca*sb/rho, -sa*sb/rho, cb/rho];
        
        % Накопление информационной матрицы Фишера (сумма вкладов всех 107 шаров)
        I_Fisher = I_Fisher + (J_alpha.' * J_alpha) / VAR_ALPHA(i) + ...
                              (J_beta.'  * J_beta)  / VAR_BETA(i);
    end
    
    % Проверка обусловленности геометрии (информационного раскрыва)
    if rcond(I_Fisher) > 1e-12
        % Матрица ковариации Рао-Крамера — строгая аналитическая инверсия Фишера
        K_CRLB = inv(I_Fisher);
        
        % Теоретический предел СКО в метрах (корень из диагональных элементов)
        crlb_std_X(k) = sqrt(K_CRLB(1, 1)); % Боковой уход
        crlb_std_Y(k) = sqrt(K_CRLB(2, 2)); % Дальность прилета
        crlb_std_Z(k) = sqrt(K_CRLB(3, 3)); % Высота цели
    else
        crlb_std_X(k) = NaN;
        crlb_std_Y(k) = NaN;
        crlb_std_Z(k) = NaN;
    end
end

% =========================================================================
% СТРОГАЯ АКАДЕМИЧЕСКАЯ ВИЗУАЛИЗАЦИЯ (2 САБПЛОТА: ГЕОМЕТРИЯ И ПОТЕНЦИАЛ ФИШЕРА)
% =========================================================================
figure('Name', 'Анализ потенциала измерительной системы через матрицу Фишера (CRLB)');

% Сабплот 1: Истинная физическая геометрия взаимного расположения
subplot(2,1,1);
t_mesh = linspace(1, length(STATION_X_ANCHORS), 500);
plot(spline(t_anchors, STATION_X_ANCHORS, t_mesh)/1000, spline(t_anchors, STATION_Y_ANCHORS, t_mesh)/1000, 'g-', 'LineWidth', 2); hold on;
plot(x_true/1000, y_true/1000, 'k--', 'LineWidth', 2);
plot(STATION_POSITIONS(1,:)/1000, STATION_POSITIONS(2,:)/1000, 'b^', 'MarkerSize', 6, 'LineWidth', 1.5);
grid on; axis equal;
xlabel('X, km'); ylabel('Y, km');
xlim([-25 25]); ylim([-5 40]);
title(sprintf('Физическая геометрия: Смещенный сплайн шаров (+8км) и траектория (N=%d)', N_STATIONS));

% Сабплот 2: Истинная теоретическая граница Рао-Крамера (CRLB)
subplot(2,1,2);
plot(x_true/1000, crlb_std_X, 'g-', 'LineWidth', 2); hold on;
plot(x_true/1000, crlb_std_Y, 'b-', 'LineWidth', 2);
plot(x_true/1000, crlb_std_Z, 'r-', 'LineWidth', 2);
grid on;
xlabel('X, km'); ylabel('Theoretical CRLB STD, meters');
xlim([-15 15]); ylim([0 max([crlb_std_X; crlb_std_Y])*1.1]);
legend('Боковой уход (X)', 'Дальность прилета (Y)', 'Ошибка высоты (Z)', 'Location', 'northeast');
title('Чистые аналитические профили функций промаха (Нижняя граница Рао-Крамера)');
