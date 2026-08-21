function [status, pos_out, std_R, std_Cross, std_Z] = triangulate(P, alpha, beta, var_alpha, var_beta, use_clustering)
% =========================================================================
% ВЕРХНЕУРОВНЕВЫЙ ДИСПЕТЧЕР ТАКТА ВЫЧИСЛЕНИЙ (ПРОТОТИП СИ-БИБЛИОТЕКИ)
% =========================================================================
% Входные параметры:
%   P              - Матрица физических координат станций [3 x M]
%   alpha, beta    - Векторы сырых измеренных углов [M x 1] (радианы)
%   var_alpha, beta- Векторы паспортных дисперсий шума [M x 1] (радианы^2)
%   use_clustering - Селектор препроцессинга (0 - Гаусс-веса, 1 - Кластеризация)
% Выходные параметры:
%   status         - Сводный флаг успешности такта (0 - ОК, >0 - код ошибки)
%   pos_out        - Найденные 3D декартовы координаты цели [x; y; z]
%   std_R          - СКО промаха по дальности прилета (Along-Track), м
%   std_Cross      - СКО промаха бокового ухода (Cross-Track), м
%   std_Z          - СКО промаха по высоте, м
% =========================================================================

pos_out = [0; 0; 0];
std_R = NaN; std_Cross = NaN; std_Z = NaN;

% Подключаем низкоуровневую статическую линейную алгебру 3х3
ml = matlinear();

% =========================================================================
% ЭТАП 1: ПРЕДВАРИТЕЛЬНАЯ ПОДГОТОВКА ДАННЫХ (ПРЕПРОЦЕССИНГ)
% =========================================================================
if use_clustering == 1
    % Идея №1: Пространственно-угловая кластеризация на базе "лидера"
    [st_prep, P_w, alpha_w, beta_w, var_alpha_w, var_beta_w] = ...
        lls3d_prepare_data_cluster(P, alpha, beta, var_alpha, var_beta);
    if st_prep ~= 0, status = 10 + st_prep; return; end
    
    % Для кластеризованных данных веса в уравнениях МНК остаются единичными
    M_w = size(P_w, 2);
    W_diag = ones(2*M_w, 1);
else
    % Идея №3: Автономное непрерывное Гауссово демпфирование весов
    [st_prep, W_diag] = lls3d_prepare_data(P, alpha, beta, var_alpha, var_beta);
    if st_prep ~= 0, status = 20 + st_prep; return; end
    
    P_w = P; alpha_w = alpha; beta_w = beta;
    var_alpha_w = var_alpha; var_beta_w = var_beta;
end

% =========================================================================
% ЭТАП 2: ВЗВЕШЕННОЕ 3D-ПОЗИЦИОНИРОВАНИЕ (WLLS)
% =========================================================================
M_current = size(P_w, 2);
H = zeros(2*M_current, 3);
b = zeros(2*M_current, 1);

% Ручная сборка взвешенной измерительной матрицы (в стиле Си-буфера)
for i = 1:M_current
    sa = sin(alpha_w(i)); ca = cos(alpha_w(i));
    sb = sin(beta_w(i));  cb = cos(beta_w(i));
    xs = P_w(1, i); ys = P_w(2, i); zs = P_w(3, i);
    
    H(2*i-1, 1) = -sa;    H(2*i-1, 2) =  ca;    H(2*i-1, 3) = 0;
    b(2*i-1, 1) = -sa*xs + ca*ys;
    
    H(2*i, 1)   = -sb*ca; H(2*i, 2)   = -sb*sa; H(2*i, 3)   = cb;
    b(2*i, 1)   = -sb*ca*xs - sb*sa*ys + cb*zs;
end

% Применение демпфирующих весов
W = diag(W_diag);
AtWA = H.' * W * H;
AtWb = H.' * W * b;

% Нахождение координат через статический Холецкий-буфер matlinear
[st_solve, pos_out] = ml.solve_system(AtWA, AtWb);
if st_solve ~= 0, status = 2; return; end

% =========================================================================
% ЭТАП 3: РАСЧЕТ И ПРЕОБРАЗОВАНИЕ КОВАРИАЦИИ ДЛЯ КОНТРОЛЯ ПРОМАХА
% =========================================================================
% Считаем базовую взвешенную декартову ковариацию координат
[st_cov_decart, K_decart] = ml.inverse(AtWA);
if st_cov_decart ~= 0, status = 3; return; end

% Масштабируем декартов тензор на линейный коэффициент ошибок в метрах
diag_Kb = zeros(2*M_current, 1);
for i = 1:M_current
    dx = pos_out(1) - P_w(1, i); 
    dy = pos_out(2) - P_w(2, i); 
    dz = pos_out(3) - P_w(3, i);
    rho = sqrt(dx^2 + dy^2 + dz^2);
    if rho < 1e-3, rho = 1e-3; end
    
    diag_Kb(2*i-1) = var_alpha_w(i) * (rho^2);
    diag_Kb(2*i)   = var_beta_w(i) * (rho^2);
end

C_op = AtWA \ (H.' * W);
K_decart_scaled = C_op * diag(diag_Kb) * C_op.';

% Вызываем конвертер осей для вывода инвариантных физических СКО промаха
[st_conv, ~, std_R, std_Cross, std_Z] = llconverter(P_w, pos_out, K_decart_scaled);
if st_conv ~= 0, status = 4; return; end

status = 0;
end
