function [alpha_measured, beta_measured,next] = service_add_noise_ox(P_exp, x_true, y_true, z_true, DOA_ERROR_DEGREE, context)
% =========================================================================
% СЛУЖЕБНАЯ ФУНКЦИЯ: СИНХРОННЫЙ ГЕНЕРАТОР ШУМА ДАТЧИКОВ ТИС ОТ ОСИ OX
% =========================================================================

N_total = size(P_exp, 2);
VAR_RAD = deg2rad(DOA_ERROR_DEGREE)^2;

% Numeric seed is a stateless compatibility entry; continued runs use context.
if isnumeric(context), context=engine_rng_init(context); end

dx = x_true - P_exp(1, :);
dy = y_true - P_exp(2, :);
dz = z_true - P_exp(3, :);

[na,next]=engine_rng_normal(context,1,N_total);
[nb,next]=engine_rng_normal(next,1,N_total);
alpha_measured = atan2(dy, dx) + sqrt(VAR_RAD) * na;
beta_measured  = atan2(dz, sqrt(dx.^2 + dy.^2)) + sqrt(VAR_RAD) * nb;
end
