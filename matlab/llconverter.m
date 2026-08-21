function [status, K_spherical, std_R, std_Cross, std_Z] = llconverter(P, lambda_estimated, K_decart)
% =========================================================================
% МОДУЛЬ ТЕНЗОРНОГО ПРЕОБРАЗОВАНИЯ КОВАРИАЦИИ В СФЕРИЧЕСКИЙ БАЗИС ЦЕЛИ
% =========================================================================
% Входные параметры:
%   P                - Матрица координат измерительных пунктов [3 x M]
%   lambda_estimated - Оцененные текущие декартовы координаты цели [x; y; z]
%   K_decart         - Исходная декартова матрица ковариации 3х3
% Выходные параметры:
%   status           - Флаг выполнения (0 - успешно, >0 - критический сбой)
%   K_spherical      - Преобразованная ковариационная матрица 3х3
%   std_R            - СКО ошибки по дальности прилета (Along-Track), м
%   std_Cross        - СКО ошибки бокового ухода (Cross-Track), м
%   std_Z            - СКО ошибки удержания высоты, м
% =========================================================================

K_spherical = zeros(3,3);
std_R = NaN; std_Cross = NaN; std_Z = NaN;

if length(lambda_estimated) ~= 3 || size(K_decart, 1) ~= 3 || size(K_decart, 2) ~= 3
    status = 1; return;
end

if any(isnan(lambda_estimated)) || any(isinf(lambda_estimated))
    status = 2; return;
end

x = lambda_estimated(1);
y = lambda_estimated(2);
z = lambda_estimated(3);

% 1. Расчет геометрического центра масс текущей измерительной сетки
x_center = mean(P(1, :));
y_center = mean(P(2, :));
z_center = mean(P(3, :));

% 2. Формирование вектора направления от центра базы на текущую позицию цели
dx_c = x - x_center;
dy_c = y - y_center;
dz_c = z - z_center;
rho_c = sqrt(dx_c^2 + dy_c^2 + dz_c^2);

if rho_c < 1e-3, rho_c = 1e-3; end

% Направляющие косинусы радиальной оси визирования
r_x = dx_c / rho_c;
r_y = dy_c / rho_c;
r_z = dz_c / rho_c;

% Проекция на плоскость XY для построения ортогонального базиса горизонта
rho_xy = sqrt(dx_c^2 + dy_c^2);
if rho_xy < 1e-3, rho_xy = 1e-3; end

% 3. Построение строгой ортогональной матрицы перехода U (3x3)
% Строка 1: Радиальное направление (ось Along-Track / Дальность)
U(1, 1) = r_x;        U(1, 2) = r_y;        U(1, 3) = r_z;
% Строка 2: Горизонтальная нормаль к лучу цели (ось Cross-Track / Боковой снос)
U(2, 1) = -dy_c/rho_xy; U(2, 2) = dx_c/rho_xy;  U(2, 3) = 0;
% Строка 3: Вертикальная нормаль (ось удержания Высоты Z)
U(3, 1) = -r_x*r_z/rho_xy; U(3, 2) = -r_y*r_z/rho_xy; U(3, 3) = rho_xy/rho_c;

% 4. Тензорный поворот декартовой ковариации: K_sph = U * K_decart * U'
K_spherical = U * K_decart * U.';

% Проверка корректности диагональных элементов после вращения
if K_spherical(1,1) < 0 || K_spherical(2,2) < 0 || K_spherical(3,3) < 0 || ...
   any(isnan(K_spherical(:))) || any(isinf(K_spherical(:)))
    status = 3; return;
end

% 5. Извлечение чистых инвариантных физических компонент промаха цели
std_R     = sqrt(K_spherical(1, 1)); % Продольный промах по дальности
std_Cross = sqrt(K_spherical(2, 2)); % Боковой путевой уход
std_Z     = sqrt(K_spherical(3, 3)); % Ошибка высоты

status = 0;
end
