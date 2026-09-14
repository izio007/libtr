function unit_test_cov2std_3d()
% =========================================================================
% ВЕРИФИКАЦИОННЫЙ ЮНИТ-ТЕСТ С ЯВНЫМ РАСЧЕТОМ ТОЧЕК 3D-ГРАНИЦЫ И СВЕРКОЙ СКО
% СИС ТЕМНЫЙ КОНТЕНТ: СКВОЗНОЙ КОНТРОЛЬ ПОЛУОСЕЙ И СЕЧЕНИЙ ОБЪЕМНОЙ ОБOЛОЧКИ
% ПРОВЕРКА ВЫПОЛНЯЕТСЯ СТРОГО ПО КВАДРАТИЧНОЙ ФОРМЕ ЖЕСТКОСТИ (МАНИФЕСТ AI.md)
% PATH: unit_test_cov2std_3d.m
% =========================================================================

fprintf('=== СТАРТ ПОЛНОЙ 3D-ВЕРИФИКАЦИИ ПОЛУОСЕЙ И СЕЧЕНИЙ: ll_cov2std ===\n');

% 1. ИНИЦИАЛИЗАЦИЯ ПОЛНОЙ СКОШЕННОЙ ТРЕХМЕРНОЙ КОВАРИАЦИОННОЙ МАТРИЦЫ ТИС
K_cart = [
    2.5051,   1.9335,   0.2000;
    1.9335,   2.4385,   0.1000;
    0.2000,   0.1000,   1.5000
];

lambda_target   = [5.0; 6.0; 2.0];   % Трехмерный центр эллипсоида погрешностей цели
lambda_observer = [6.0; 2.0; 0.5];   % Трехмерная позиция измерительного куста ТИС

% 2. ТЕСТОВЫЙ ПРОГОН ИССЛЕДУЕМОГО МАТЕМАТИЧЕСКОГО ЯДРА СЕЧЕНИЯ ТИС
[status, sigma_radial, sigma_cross1, sigma_cross2] = ll_cov2std(K_cart, lambda_target, lambda_observer);

if status ~= 0
    error('❌ Юнит-тест провален: Ядро сечения ТИС вернуло статус ошибки %d', status);
end

% 3. ВЫЧИСЛЕНИЕ СОБСТВЕННЫХ ВЕКТОРОВ И ИСТИННЫХ ГЛАВНЫХ ПОЛУОСЕЙ 3D-ЭЛЛИПСОИДА
[V_3d, D_3d] = eig(K_cart);

% Длины трех главных полуосей пространственного эллипсоида 1-sigma
semi_axis1 = sqrt(D_3d(1,1)); % Минимальная полуось (c)
semi_axis2 = sqrt(D_3d(2,2)); % Средняя полуось (b)
semi_axis3 = sqrt(D_3d(3,3)); % Максимальная полуось (a)

u_axis1 = V_3d(:, 1); % Направление минимальной полуоси
u_axis2 = V_3d(:, 2); % Направление средней полуоси
u_axis3 = V_3d(:, 3); % Направление максимальной полуоси

% 4. РАСЧЕТ АБСОЛЮТНЫХ ТРЕХМЕРНЫХ КООРДИНАТ ВЕРШИН (ГЛАВНЫХ ПОЛУОСЕЙ ЭЛЛИПСОИДА)
% Находим три опорные черные точки, лежащие строго на объемной зеленой оболочке
pt_axis1_vertex = lambda_target(:) + u_axis1 * semi_axis1;
pt_axis2_vertex = lambda_target(:) + u_axis2 * semi_axis2;
pt_axis3_vertex = lambda_target(:) + u_axis3 * semi_axis3;

% 5. ПОСТРОЕНИЕ ИСТИННОГО ОРТОНОРМИРОВАННОГО 3D-БАЗИСА ЛУЧА ВИЗИРОВАНИЯ
dr = lambda_target(:) - lambda_observer(:);
r_meters = norm(dr);
u_r = dr / r_meters; % Орт 1: Направление линии визирования (ЛВ)

if hypot(u_r(1), u_r(2)) > 1e-5
    u_cross1 = [-u_r(2); u_r(1); 0]; 
    u_cross1 = u_cross1 / norm(u_cross1); % Орт 2: Поперечная горизонталь
else
    u_cross1 = [1; 0; 0];
end
u_cross2 = cross(u_r, u_cross1); % Орт 3: Поперечная вертикаль

% Сборка репера для проверки ортогональности (машинный нуль)
R_check = [u_r, u_cross1, u_cross2];
if norm(R_check' * R_check - eye(3)) > 1e-12
    error('❌ Юнит-тест провален: Сформированный 3D-базис луча визирования не ортогонален!');
end

% 6. ЯВНЫЙ ГЕОМЕТРИЧЕСКИЙ РАСЧЕТ АБСОЛЮТНЫХ ТРЕХМЕРНЫХ КООРДИНАТ ТОЧЕК СЕЧЕНИЯ
pt_radial_sect = lambda_target(:) + u_r * sigma_radial;       % Точка протыкания луча ЛВ
pt_cross1_sect = lambda_target(:) + u_cross1 * sigma_cross1; % Точка горизонтального сечения
pt_cross2_sect = lambda_target(:) + u_cross2 * sigma_cross2; % Точка вертикального сечения

% 7. ВЫЧИСЛЕНИЕ ЧИСТЫХ ЕВКЛИДОВЫХ НОРМ (РАССТОЯНИЙ ОТ ЦЕНТРА ЦЕЛИ В 3D)
norm_axis1  = norm(pt_axis1_vertex - lambda_target(:));
norm_axis2  = norm(pt_axis2_vertex - lambda_target(:));
norm_axis3  = norm(pt_axis3_vertex - lambda_target(:));

norm_radial = norm(pt_radial_sect - lambda_target(:));
norm_cross1 = norm(pt_cross1_sect - lambda_target(:));
norm_cross2 = norm(pt_cross2_sect - lambda_target(:));

% =========================================================================
% 8. ВЫВОД СИНХРОННОЙ ТAБЛИЦЫ СВЕРКИ И ПОЛНЫЙ ИНЖЕНЕРНЫЙ ОТЧЕТ В ОЗУ
% =========================================================================
fprintf('\n===================================================================\n');
fprintf('     ТАБЛИЦА ГЕОМЕТРИЧЕСКИХ ПАРАМЕТРОВ И ИСТИННЫХ ПОЛУОСЕЙ ЭЛЛИПСОИДА \n');
fprintf('===================================================================\n');
fprintf(' Параметр 3D-геометрии     | Истинная Евклидова норма (Длина полуоси) \n');
fprintf('-------------------------------------------------------------------\n');
fprintf(' Минимальная ось эллипсоида|                   %8.5f м\n', norm_axis1);
fprintf(' Средняя ось эллипсоида    |                   %8.5f м\n', norm_axis2);
fprintf(' Максимальная ось эллипсоид|                   %8.5f м\n', norm_axis3);
fprintf('-------------------------------------------------------------------\n');
fprintf(' Измерительный канал ТИС   | Вычисленный радиус сечения оболочки 1-sigma \n');
fprintf('-------------------------------------------------------------------\n');
fprintf(' Радиальный (вдоль ЛВ)     |                   %8.5f м\n', sigma_radial);
fprintf(' Поперечный (Cross1)       |                   %8.5f м\n', sigma_cross1);
fprintf(' Вертикальный (Cross2)     |                   %8.5f м\n', sigma_cross2);
fprintf('===================================================================\n');

fprintf('\nАбсолютные декартовы 3D-координаты истинных вершин полуосей (Черные точки):\n');
fprintf('  Вершина минимальной оси: X = %8.5f, Y = %8.5f, Z = %8.5f\n', pt_axis1_vertex);
fprintf('  Вершина средней оси:     X = %8.5f, Y = %8.5f, Z = %8.5f\n', pt_axis2_vertex);
fprintf('  Вершина максимальной оси: X = %8.5f, Y = %8.5f, Z = %8.5f\n', pt_axis3_vertex);

% =========================================================================
% 9. СТРОГИЙ ДВУХЪЯКОРНЫЙ МАТЕМАТИЧЕСКИЙ АССЕРТ (ЖЕСТКИЙ КРИТЕРИЙ УСПЕХА)
% Подстановка всех шести пространственных векторов в квадратичную форму жесткости
% =========================================================================
if rcond(K_cart) < eps
    error('❌ Юнит-тест провален: Матрица ковариации вырождена.');
end
Info_cart = inv(K_cart);

% Векторы смещения от центра цели до исследуемых пространственных точек
dx_radial = pt_radial_sect - lambda_target(:);
dx_cross1 = pt_cross1_sect - lambda_target(:);
dx_cross2 = pt_cross2_sect - lambda_target(:);
dx_axis1  = pt_axis1_vertex - lambda_target(:);
dx_axis2  = pt_axis2_vertex - lambda_target(:);
dx_axis3  = pt_axis3_vertex - lambda_target(:);

% Вычисление квадратичных форм (каждая обязана быть побитово равна строго 1.0)
eq_radial = dx_radial' * Info_cart * dx_radial;
eq_cross1 = dx_cross1' * Info_cart * dx_cross1;
eq_cross2 = dx_cross2' * Info_cart * dx_cross2;
eq_axis1  = dx_axis1'  * Info_cart * dx_axis1;
eq_axis2  = dx_axis2'  * Info_cart * dx_axis2;
eq_axis3  = dx_axis3'  * Info_cart * dx_axis3;

fprintf('\nПроверка квадратичных форм жесткости (Опорный инвариант = 1.0):\n');
fprintf('  Форма для точки сечения ЛВ:      %12.10f\n', eq_radial);
fprintf('  Форма для точки сечения Cross1:  %12.10f\n', eq_cross1);
fprintf('  Форма для точки сечения Cross2:  %12.10f\n', eq_cross2);
fprintf('  Форма для вершины минимальной оси:%12.10f\n', eq_axis1);
fprintf('  Форма для вершины средней оси:   %12.10f\n', eq_axis2);
fprintf('  Форма для вершины максимальной оси:%12.10f\n', eq_axis3);

% Жесткий допуск по машинному нулю
tol = 1e-10;
if abs(eq_radial - 1.0) > tol || abs(eq_cross1 - 1.0) > tol || abs(eq_cross2 - 1.0) > tol || ...
   abs(eq_axis1 - 1.0) > tol  || abs(eq_axis2 - 1.0) > tol  || abs(eq_axis3 - 1.0) > tol
    error('❌ Юнит-тест провален: Квадратичная форма не равна 1.0! Точки оторвались от 3D-оболочки!');
end

% 10. ГРАФИЧЕСКИЙ БЛОК: СТРОИМ ПРОСТРАНСТВЕННУЮ 3D-СЦЕНУ ENU
[X_sph, Y_sphere, Z_sphere] = sphere(40);
sphere_pts = [X_sph(:).'; Y_sphere(:).'; Z_sphere(:).'];
ellipsoid_3d = V_3d * sqrt(D_3d) * sphere_pts + lambda_target(:);

X_ell = reshape(ellipsoid_3d(1,:), size(X_sph));
Y_ell = reshape(ellipsoid_3d(2,:), size(Y_sphere));
Z_ell = reshape(ellipsoid_3d(3,:), size(Z_sphere));

figure('Color', 'w', 'Name', 'ТИС 3D-Верификатор: Собственные полуоси и сечения жесткости');
surf(X_ell, Y_ell, Z_ell, 'FaceColor', 'g', 'FaceAlpha', 0.12, 'EdgeColor', 'g', 'EdgeAlpha', 0.03, 'DisplayName', 'Эллипсоид 1-sigma');
hold on; grid on;

% Отображение опорных объектов
plot3(lambda_observer(1), lambda_observer(2), lambda_observer(3), 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'k', 'DisplayName', 'Наблюдатель (ENU)');
plot3(lambda_target(1), lambda_target(2), lambda_target(3), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', 'Центр цели');

% Отрисовка ИСТИННЫХ 3D-вершин главных полуосей (Черные маркеры строго на зеленой сетке)
plot3(pt_axis1_vertex(1), pt_axis1_vertex(2), pt_axis1_vertex(3), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6, 'DisplayName', 'Вершина минимальной оси');
plot3(pt_axis2_vertex(1), pt_axis2_vertex(2), pt_axis2_vertex(3), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6, 'DisplayName', 'Вершина средней оси');
plot3(pt_axis3_vertex(1), pt_axis3_vertex(2), pt_axis3_vertex(3), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6, 'DisplayName', 'Вершина максимальной оси');

% Линии самих главных полуосей из центра эллипсоида
line([lambda_target(1) pt_axis1_vertex(1)], [lambda_target(2) pt_axis1_vertex(2)], [lambda_target(3) pt_axis1_vertex(3)], 'Color', 'k', 'LineStyle', ':', 'LineWidth', 1.5, 'HandleVisibility', 'off');
line([lambda_target(1) pt_axis2_vertex(1)], [lambda_target(2) pt_axis2_vertex(2)], [lambda_target(3) pt_axis2_vertex(3)], 'Color', 'k', 'LineStyle', ':', 'LineWidth', 1.5, 'HandleVisibility', 'off');
line([lambda_target(1) pt_axis3_vertex(1)], [lambda_target(2) pt_axis3_vertex(2)], [lambda_target(3) pt_axis3_vertex(3)], 'Color', 'k', 'LineStyle', ':', 'LineWidth', 1.5, 'HandleVisibility', 'off');

% Отрисовка верифицированных синих точек сечений на 3D-оболочке из ядра ТИС
plot3(pt_radial_sect(1), pt_radial_sect(2), pt_radial_sect(3), 'ko', 'MarkerFaceColor', 'b', 'MarkerSize', 9, 'DisplayName', 'Точка сечения ЛВ');
plot3(pt_cross1_sect(1), pt_cross1_sect(2), pt_cross1_sect(3), 'ko', 'MarkerFaceColor', 'b', 'MarkerSize', 9, 'DisplayName', 'Точка сечения Cross1');
plot3(pt_cross2_sect(1), pt_cross2_sect(2), pt_cross2_sect(3), 'ko', 'MarkerFaceColor', 'c', 'MarkerSize', 9, 'DisplayName', 'Точка сечения Cross2');
% Прорисовка силовых векторов СКО каналов визирования
line([lambda_target(1) pt_radial_sect(1)], [lambda_target(2) pt_radial_sect(2)], [lambda_target(3) pt_radial_sect(3)], 'Color', 'b', 'LineWidth', 3, 'HandleVisibility', 'off');
line([lambda_target(1) pt_cross1_sect(1)],  [lambda_target(2) pt_cross1_sect(2)],  [lambda_target(3) pt_cross1_sect(3)],  'Color', 'b', 'LineWidth', 3, 'HandleVisibility', 'off');
line([lambda_target(1) pt_cross2_sect(1)],  [lambda_target(2) pt_cross2_sect(2)],  [lambda_target(3) pt_cross2_sect(3)],  'Color', 'c', 'LineWidth', 3, 'HandleVisibility', 'off');
% Линия ЛВ для объемной ориентации
line_los_x = [lambda_observer(1), lambda_target(1) + u_r(1)*2];
line_los_y = [lambda_observer(2), lambda_target(2) + u_r(2)*2];
line_los_z = [lambda_observer(3), lambda_target(3) + u_r(3)*2];

plot3(line_los_x, line_los_y, line_los_z, 'm-', 'LineWidth', 1.2, 'DisplayName', 'Линия визирования (ЛВ)');
view(3); 
axis equal; 
legend('Location', 'best');
title('Абсолютная 3D-верификация длин и точек сечения оболочки');
xlabel('Восток (East / X), метры'); 
ylabel('Север (North / Y), метры'); 
zlabel('Высота (Up / Z), метры');
% ВЫВОД ЗЕЛЕНОГО СТАТУСА ТОЛЬКО ПРИ ИСТИННОМ ПРОХОЖДЕНИИ АССЕРТОВ
fprintf('  СТАТУС ЮНИТ-ТЕСТА: УСПЕШНО ПРОЙДЕН (SUCCESS)\n');
fprintf('  Побитовое нахождение 3D-вершин полуосей на оболочке доказано.\n');

end