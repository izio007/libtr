function [alpha_measured, beta_measured] = service_add_noise_ox(P_exp, x_true, y_true, z_true, DOA_ERROR_DEGREE, RANDOM_SEED)
% =========================================================================
% СЛУЖЕБНАЯ ФУНКЦИЯ: СИНХРОННЫЙ ГЕНЕРАТОР ШУМА ДАТЧИКОВ ТИС ОТ ОСИ OX
% Path: d:\workspace\libtr\matlabtests\service_add_noise_ox.m
% =========================================================================

N_total = size(P_exp, 2);
VAR_RAD = deg2rad(DOA_ERROR_DEGREE)^2;

rng(RANDOM_SEED);

dx = x_true - P_exp(1, :); 
dy = y_true - P_exp(2, :); 
dz = z_true - P_exp(3, :);

alpha_measured = atan2(dy, dx) + sqrt(VAR_RAD) * randn(1, N_total);
beta_measured  = atan2(dz, sqrt(dx.^2 + dy.^2)) + sqrt(VAR_RAD) * randn(1, N_total);
end
