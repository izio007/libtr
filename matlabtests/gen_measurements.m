function [alpha_m_matrix, beta_m_matrix, crlb] = gen_measurements(STATION_POSITIONS, x_true, y_true, z_true, DOA_ERROR_DEGREE)
% =========================================================================
% СИНХРОННЫЙ ГЕНЕРАТОР ИЗМЕРИТЕЛЬНОЙ ВЫБОРКИ (СКВЕРНЫЕ КОНСТАНТЫ УДАЛЕНЫ)
% Responsibility: Динамический расчет углов и CRLB по входному шуму сценария
% Path: d:\workspace\libtr\matlabtests\gen_measurements.m
% =========================================================================

N_STATIONS = size(STATION_POSITIONS, 2);
K_points = length(x_true);
VAR_RAD = deg2rad(DOA_ERROR_DEGREE)^2;

alpha_m_matrix = zeros(N_STATIONS, K_points);
beta_m_matrix  = zeros(N_STATIONS, K_points);

crlb.X = zeros(K_points, 1); 
crlb.Y = zeros(K_points, 1);
crlb.Z = zeros(K_points, 1); 

rng(1337); % Жесткая фиксация реализации шума для честного сравнения

for k = 1:K_points
    % 1. Расчет репера Фишера (CRLB) по входному значению дисперсии шума
    [st_f, cx, cy, cz] = lls3d_fisher_crlb(STATION_POSITIONS, VAR_RAD * ones(N_STATIONS, 1), VAR_RAD * ones(N_STATIONS, 1), x_true(k), y_true(k), z_true(k));
    if st_f == 0
        crlb.X(k) = cx; crlb.Y(k) = cy; crlb.Z(k) = cz;
    end
    
    % 2. Генерация пеленгов строго по динамическим координатам траектории
    for i = 1:N_STATIONS
        dx = x_true(k) - STATION_POSITIONS(1, i);
        dy = y_true(k) - STATION_POSITIONS(2, i);
        dz = z_true(k) - STATION_POSITIONS(3, i);
        
        r_xy = sqrt(dx^2 + dy^2);
        if r_xy < 1e-3, r_xy = 1e-3; end
        
        alpha_m_matrix(i, k) = atan2(dy, dx) + sqrt(VAR_RAD) * randn();
        beta_m_matrix(i, k)  = atan2(dz, r_xy) + sqrt(VAR_RAD) * randn();
    end
end
end
