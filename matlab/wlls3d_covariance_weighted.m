function [status, std_X, std_Y, std_Z] = wlls3d_covariance_weighted(P, alpha, beta, var_alpha, var_beta, lambda_wlls, W_diag)
% =========================================================================
% ФУНКЦИЯ РАСЧЕТА ТЕОРЕТИЧЕСКОЙ КОВАРИАЦИИ ДЛЯ МЕТОДА WLLS (ОТ ОСИ OX)
% Входные параметры:
%   P           - Физическая матрица координат измерительных пунктов [3 x M]
%   alpha       - Вектор измеренных азимутов цели [M x 1] (радианы)
%   beta        - Вектор измеренных углов места цели [M x 1] (радианы)
%   var_alpha   - Вектор дисперсий шума азимутальных каналов [M x 1] (рад^2)
%   var_beta    - Вектор дисперсий шума угломестных каналов [M x 1] (рад^2)
%   lambda_wlls - Вектор оцененных координат от весового МНК [3 x 1] (метры)
%   W_diag      - Диагональный вектор весов измерительных каналов [2M x 1]
% Выходные параметры:
%   status      - Флаг выполнения (0 - успешно, 1 - сбой размерности, 2 - вырождение)
%   std_X,Y,Z   - Рассчитанные СКО погрешностей по декартовым осям (метры)
% =========================================================================
std_X = NaN; std_Y = NaN; std_Z = NaN;
M = size(P, 2);

if M < 2 || length(lambda_wlls) ~= 3 || length(W_diag) < 2*M || any(isnan(lambda_wlls))
    status = 1; return;
end

H = zeros(2*M, 3);
for i = 1:M
    sa = sin(alpha(i)); ca = cos(alpha(i));
    sb = sin(beta(i));  cb = cos(beta(i));
    H(2*i-1, 1) = sa;      H(2*i-1, 2) = -ca;     H(2*i-1, 3) = 0;
    H(2*i, 1)   = -ca * sb; H(2*i, 2)   = -sa * sb; H(2*i, 3)   = cb;
end

W = diag(W_diag);
AtWA = H.' * W * H;

if rcond(AtWA) < 2.2204e-16 || isnan(rcond(AtWA))
    status = 2; return;
end

diag_Kb = zeros(2*M, 1);
for i = 1:M
    dx = lambda_wlls(1) - P(1, i); dy = lambda_wlls(2) - P(2, i); dz = lambda_wlls(3) - P(3, i);
    rho_sq = dx^2 + dy^2 + dz^2;
    diag_Kb(2*i-1) = var_alpha(i) * rho_sq;
    diag_Kb(2*i)   = var_beta(i) * rho_sq;
end

C_op = AtWA \ (H.' * W);
K_lambda = C_op * diag(diag_Kb) * C_op.';

std_X = sqrt(K_lambda(1, 1));
std_Y = sqrt(K_lambda(2, 2));
std_Z = sqrt(K_lambda(3, 3));
status = 0;
end
