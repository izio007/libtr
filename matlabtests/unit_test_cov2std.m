function unit_test_cov2std()
% =========================================================================
% НАГЛЯДНЫЙ ВЕРИФИКАЦИОННЫЙ ЮНИТ-ТЕСТ С ЯВНЫМ РАСЧЕТОМ ПОЛУОСЕЙ И СВЕРКОЙ СКО
% СИС ТЕМНЫЙ КОНТЕНТ: СВЕРКА ГЕОМЕТРИЧЕСКИХ ВЕРШИН С ВЫХОДАМИ ЯДРА СЕЧЕНИЙ
% ПРОВЕРКА ВЫПОЛНЯЕТСЯ СТРОГО ПО КВАДРАТИЧНОЙ ФОРМЕ ЖЕСТКОСТИ (МАНИФЕСТ AI.md)
% PATH: unit_test_cov2std.m
% =========================================================================

fprintf('=== СТАРТ ГЕОМЕТРИЧЕСКОЙ ВЕРИФИКАЦИИ ПОЛУОСЕЙ: ll_cov2std ===\n');

% 1. ФИКСАЦИЯ СКОШЕННОЙ МАТРИЦЫ И ГЕОМЕТРИЧЕСКОГО БАЗИСA (ИЗОЛИРУЕМ Z)
K_cart = [
    2.5051,   1.9335,   0.0000;
    1.9335,   2.4385,   0.0000;
    0.0000,   0.0000,   1.0000
];

lambda_target   = [5.0; 6.0; 0.0];   % Центр эллипсоида погрешностей (Центр цели)
lambda_observer = [6.0; 2.0; 0.0];   % Позиция измерительного куста ТИС (Наблюдатель)

% 2. ТЕСТОВЫЙ ПРОГОН ИССЛЕДУЕМОГО МАТЕМАТИЧЕСКОГО ЯДРА СЕЧЕНИЯ
[status, sigma_radial, sigma_cross1, ~] = ll_cov2std(K_cart, lambda_target, lambda_observer);

if status ~= 0
    error('❌ Юнит-тест провален: Ядро сечения ТИС вернуло статус ошибки %d', status);
end

% 3. ВЫЧИСЛЕНИЕ СОБСТВЕННЫХ ВЕКТОРОВ И ИСТИННЫХ ПОЛУОСЕЙ ЭЛЛИПСА НА ПЛОСКОСТИ
K_2d = K_cart(1:2, 1:2);
[V_enu, D_enu] = eig(K_2d);

% Длины главных полуосей эллипса 1-sigma (максимальный и минимальный радиус-векторы)
semi_major_axis = sqrt(D_enu(2,2)); % Большая полуось (a)
semi_minor_axis = sqrt(D_enu(1,1)); % Малая полуось (b)

u_major = V_enu(:, 2); % Направление большой полуоси
u_minor = V_enu(:, 1); % Направление малой полуоси

% 4. ЯВНЫЙ РАСЧЕТ АБСОЛЮТНЫХ ДЕКАРТОВЫХ КООРДИНАТ ВЕРШИН (ПОЛУОСЕЙ ЭЛЛИПСА)
% Находим черные маркерные точки, лежащие строго на зеленой оболочке эллипса
pt_major_vertex = lambda_target(1:2) + u_major * semi_major_axis;
pt_minor_vertex = lambda_target(1:2) + u_minor * semi_minor_axis;

% 5. ВЫЧИСЛЕНИЕ ЧИСТЫХ ЕВКЛИДОВЫХ НОРМ (РАССТОЯНИЙ ОТ ЦЕНТРА ЦЕЛИ)
norm_major_axis = norm(pt_major_vertex - lambda_target(1:2));
norm_minor_axis = norm(pt_minor_vertex - lambda_target(1:2));

% Вычисление и прорисовка направлений ЛВ и Нормали
dr_u = lambda_target - lambda_observer;
u_r = dr_u / norm(dr_u);
u_cross1 = [-u_r(2); u_r(1); 0]; u_cross1 = u_cross1 / norm(u_cross1);

% Нахождение декартовых точек сечений ЛВ и нормали из ядра
pt_r_s = lambda_target + u_r * sigma_radial;
pt_c_s = lambda_target - u_cross1 * sigma_cross1; 

% 6. ВЫВОД СИНХРОННОЙ ТAБЛИЦЫ СВЕРКИ ГЕОМЕТРИИ И РАДИУСОВ СЕЧЕНИЯ ТИС
fprintf('\n===================================================================\n');
fprintf('     ТАБЛИЦА ГЕОМЕТРИЧЕСКИХ ПАРАМЕТРОВ И ИСТИННЫХ ПОЛУОСЕЙ ЭЛЛИПСА \n');
fprintf('===================================================================\n');
fprintf(' Параметр геометрии        | Истинная Евклидова норма (Длина полуоси) \n');
fprintf('-------------------------------------------------------------------\n');
fprintf(' Большая полуось эллипса   |                   %8.5f м\n', norm_major_axis);
fprintf(' Малая полуось эллипса     |                   %8.5f м\n', norm_minor_axis);
fprintf('-------------------------------------------------------------------\n');
fprintf(' Канал сечения ядра ТИС    | Вычисленный радиус сечения оболочки 1-sigma \n');
fprintf('-------------------------------------------------------------------\n');
fprintf(' Радиальный (вдоль ЛВ)     |                   %8.5f м\n', sigma_radial);
fprintf(' Поперечный (горизонталь)  |                   %8.5f м\n', sigma_cross1);
fprintf('===================================================================\n');

fprintf('\nАбсолютные декартовы координаты истинных вершин полуосей (Черные точки):\n');
fprintf('  Вершина большой полуоси: X = %8.5f, Y = %8.5f\n', pt_major_vertex(1), pt_major_vertex(2));
fprintf('  Вершина малой полуось:   X = %8.5f, Y = %8.5f\n', pt_minor_vertex(1), pt_minor_vertex(2));

% =========================================================================
% 7. СТРОГИЙ ДВУХЪЯКОРНЫЙ МАТЕМАТИЧЕСКИЙ АССЕРТ (ЖЕСТКИЙ КРИТЕРИЙ УСПЕХА)
% Подстановка всех вычисленных граничных векторов в квадратичную форму жесткости
% =========================================================================
Info_cart = inv(K_cart);

% Векторы смещения от центра цели до исследуемых граничных точек
dx_radial = pt_r_s(:) - lambda_target(:);
dx_cross  = pt_c_s(:) - lambda_target(:);
dx_major  = [pt_major_vertex(:); 0] - lambda_target(:);
dx_minor  = [pt_minor_vertex(:); 0] - lambda_target(:);

% Вычисление квадратичных форм (каждая обязана быть побитово равна строго 1.0)
eq_radial = dx_radial' * Info_cart * dx_radial;
eq_cross  = dx_cross'  * Info_cart * dx_cross;
eq_major  = dx_major'  * Info_cart * dx_major;
eq_minor  = dx_minor'  * Info_cart * dx_minor;

fprintf('\nПроверка квадратичных форм жесткости (Опорный инвариант = 1.0):\n');
fprintf('  Форма для точки сечения ЛВ:      %12.10f\n', eq_radial);
fprintf('  Форма для точки сечения нормали: %12.10f\n', eq_cross);
fprintf('  Форма для вершины большой оси:   %12.10f\n', eq_major);
fprintf('  Форма для вершины малой оси:     %12.10f\n', eq_minor);

% Жесткий допуск по машинному нулю
tol = 1e-10;
if abs(eq_radial - 1.0) > tol || abs(eq_cross - 1.0) > tol || ...
   abs(eq_major - 1.0) > tol  || abs(eq_minor - 1.0) > tol
    error('❌ Юнит-тест провален: Квадратичная форма не равна 1.0! Точки оторвались от оболочки!');
end

% 8. ГРАФИЧЕСКИЙ БЛОК: СТРОИМ АУТЕНТИЧНУЮ СЦЕНУ ENU
t = linspace(0, 2*pi, 200);
circle_pts = [cos(t); sin(t)];
ellipse_enu = V_enu * sqrt(D_enu) * circle_pts + lambda_target(1:2);

figure('Color', 'w', 'Name', 'ТИС Верификатор: Собственные полуоси и сечения эллипса');
hold on; grid on;
title('Абсолютная верификация длин и точек сечения в СК ENU');
xlabel('Восток (East / X), метры'); ylabel('Север (North / Y), метры');

% Отрисовка геометрии стенда ТИС
plot(lambda_observer(1), lambda_observer(2), 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'k', 'DisplayName', 'Наблюдатель (6; 2)');
plot(lambda_target(1), lambda_target(2), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', 'Центр цели (5; 6)');
plot(ellipse_enu(1,:), ellipse_enu(2,:), 'g-', 'LineWidth', 2.5, 'DisplayName', 'Сечение эллипсоида 1-sigma');

% Вывод траекторных линий осей ЛВ и поперечной Нормали
line_los_x = [lambda_observer(1) - u_r(1)*2, lambda_target(1) + u_r(1)*3];
line_los_y = [lambda_observer(2) - u_r(2)*2, lambda_target(2) + u_r(2)*3];
plot(line_los_x, line_los_y, 'm-', 'LineWidth', 1.5, 'DisplayName', 'Линия визирования (ЛВ)');

line_norm_x = [lambda_target(1) - u_cross1(1)*3, lambda_target(1) + u_cross1(1)*3];
line_norm_y = [lambda_target(2) - u_cross1(2)*3, lambda_target(2) + u_cross1(2)*3];
plot(line_norm_x, line_norm_y, '-', 'Color', [0.9 0.5 0], 'LineWidth', 1.5, 'DisplayName', 'Поперечная нормаль');

% Отрисовка ИСТИННЫХ вершин полуосей эллипса (Черные маркеры строго на зеленой линии)
plot(pt_major_vertex(1), pt_major_vertex(2), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6, 'DisplayName', 'Вершина большой полуоси эллипса');
plot(pt_minor_vertex(1), pt_minor_vertex(2), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6, 'DisplayName', 'Вершина малой полуоси эллипса');

% Отрисовка синих точек сечений ЛВ и нормали из ядра ТИС
plot(pt_r_s(1), pt_r_s(2), 'ko', 'MarkerFaceColor', 'b', 'MarkerSize', 9, 'DisplayName', 'Явная точка сечения ЛВ');
plot(pt_c_s(1), pt_c_s(2), 'ko', 'MarkerFaceColor', 'b', 'MarkerSize', 9, 'DisplayName', 'Явная точка сечения нормали');

% Силовые маркерные векторы СКО внутри оболочки
line([lambda_target(1) pt_r_s(1)], [lambda_target(2) pt_r_s(2)], 'Color', 'b', 'LineWidth', 3, 'HandleVisibility', 'off');
line([lambda_target(1) pt_c_s(1)], [lambda_target(2) pt_c_s(2)], 'Color', 'b', 'LineWidth', 3, 'HandleVisibility', 'off');

axis equal; xlim([2 8]); ylim([1 9]); legend('Location', 'best');

% ВЫВОД ЗЕЛЕНОГО СТАТУСА ТОЛЬКО ПРИ ИСТИННОМ ПРОХОЖДЕНИИ АССЕРТОВ
fprintf('\n=======================================================\n');
fprintf('  СТАТУС ЮНИТ-ТЕСТА: УСПЕШНО ПРОЙДЕН (SUCCESS)\n');
fprintf('  Побитовое нахождение точек на оболочке 1-sigma доказано.\n');
fprintf('=======================================================\n');
end
