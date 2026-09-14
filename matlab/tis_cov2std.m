function [status, sigma_radial, sigma_cross1, sigma_cross2] = tis_cov2std(K_cart, lambda_target, lambda_observer)
% =========================================================================
% ФУНКЦИЯ ВЫЧИСЛЕНИЯ СИГМ ИСТИННОГО СЕЧЕНИЯ 3D-ЭЛЛИПСОИДА В СК ENU
%
% Входные параметры:
%   K_cart          - Полная декартова ковариационная матрица [3 x 3] (м^2)
%   lambda_target   - Вектор текущих координат центра эллипсоида [3 x 1] (м ENU)
%   lambda_observer - Вектор координат центра измерительного куста ТИС [3 x 1] (м ENU)
%
% Выходные параметры:
%   status          - Флаг выполнения (0 - успешно, 1 - сбой размерности, 2 - вырождение)
%   sigma_radial    - Истинный радиус эллипсоида строго вдоль 3D луча зрения, м
%   sigma_cross1    - Полуось сечения в горизонтальной плоскости (3D), м
%   sigma_cross2    - Полуось сечения в вертикальной плоскости (3D), м
% =========================================================================

sigma_radial = NaN; sigma_cross1 = NaN; sigma_cross2 = NaN;

% 1. АВАРИЙНАЯ ЗАЩИТА ОТ ДЕФЕКТОВ РАЗМЕРНОСТИ МАТРИЦ В ОЗУ
if ~isequal(size(K_cart), [3 3]) || length(lambda_target) ~= 3 || length(lambda_observer) ~= 3
    status = 1; return;
end

% 2. РАСЧЕТ ОТНОСИТЕЛЬНОГО ВЕКТОРА И ПРОВЕРКА ВЫРОЖДЕНИЯ ДАЛЬНОСТИ
dr = lambda_target(:) - lambda_observer(:);
r_meters = norm(dr);

if r_meters < 1e-3
    status = 2; return;
end

% Единичный вектор радиального направления (линия визирования)
u_r = dr / r_meters;

% 3. ПОСТРОЕНИЕ ОРТОГОНАЛЬНОГО БАЗИСА ПЛОСКОСТЕЙ ВИЗИРОВАНИЯ
if hypot(u_r(1), u_r(2)) > 1e-5
    u_cross1 = [-u_r(2); u_r(1); 0]; 
    u_cross1 = u_cross1 / norm(u_cross1);
else
    u_cross1 = [1; 0; 0];
end
u_cross2 = cross(u_r, u_cross1);

% Полная ортонормированная матрица перехода в СК наблюдателя
R = [u_r, u_cross1, u_cross2];

% 4. АБСОЛЮТНАЯ АНАЛИТИЧЕСКАЯ ПРОВЕРКА ОБУСЛОВЛЕННОСТИ ИСХОДНОЙ КОВАРИАЦИИ
if rcond(K_cart) < eps
    status = 2; return;
end

% 5. ПЕРЕХОД В ПРОСТРАНСТВО ЖЕСТКОСТИ (МАТРИЦА ФОРМЫ ЭЛЛИПСОИДА)
Info_cart = inv(K_cart);

% Пересчет информационной матрицы в локальный базис луча зрения
Info_los = R' * Info_cart * R;

% 6. ИСТИННОЕ СЕЧЕНИЕ: Извлекаем радиусы пересечения осей с оболочкой эллипсоида
sigma_radial = 1 / sqrt(Info_los(1,1));
sigma_cross1 = 1 / sqrt(Info_los(2,2));
sigma_cross2 = 1 / sqrt(Info_los(3,3));

status = 0;
end
