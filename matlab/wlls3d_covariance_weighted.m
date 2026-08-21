function [status, std_X, std_Y, std_Z] = wlls3d_covariance_weighted(P, alpha, beta, var_alpha, var_beta, lambda_wlls, W_diag)
% =========================================================================
% ФУНКЦИЯ РАСЧЕТА СКО ДЛЯ ВЗВЕШЕННОГО МНК (WLLS COVARIANCE)
% =========================================================================
% Входные параметры:
%   P                - Матрица координат измерительных пунктов [3 x M]
%   alpha, beta      - Векторы измеренных углов [M x 1] (радианы)
%   var_alpha, beta  - Векторы дисперсий углового шума каналов [M x 1]
%   lambda_estimated - Оцененные координаты цели [x; y; z]
%   W_diag           - Вектор весов строк измерительной системы [2M x 1]
% =========================================================================

std_X = NaN; std_Y = NaN; std_Z = NaN;
M = size(P, 2);

if M < 2 || length(lambda_wlls) ~= 3 || length(W_diag) < 2*M
    status = 1; return;
end

H = zeros(2*M, 3);
for i = 1:M
    sa = sin(alpha(i)); ca = cos(alpha(i));
    sb = sin(beta(i));  cb = cos(beta(i));
    H(2*i-1, 1) = -sa;     H(2*i-1, 2) = ca;      H(2*i-1, 3) = 0;
    H(2*i, 1)   = -sb*ca;  H(2*i, 2)   = -sb*sa;  H(2*i, 3)   = cb;
end

W = diag(W_diag);
AtWA = H.' * W * H;
if rcond(AtWA) < 1e-12
    status = 2; return;
end

diag_Kb = zeros(2*M, 1);
for i = 1:M
    % Дальность считается строго до точки, найденной методом WLLS
    dx = lambda_wlls(1) - P(1, i); 
    dy = lambda_wlls(2) - P(2, i); 
    dz = lambda_wlls(3) - P(3, i);
    rho_sq = dx^2 + dy^2 + dz^2;
    
    diag_Kb(2*i-1) = var_alpha(i) * rho_sq;
    diag_Kb(2*i)   = var_beta(i) * rho_sq;
end

% Весовой МНК-оператор: C = (H'*W*H)^-1 * H'*W
C_op = AtWA \ (H.' * W);
K_lambda = C_op * diag(diag_Kb) * C_op.';

std_X = sqrt(K_lambda(1, 1));
std_Y = sqrt(K_lambda(2, 2));
std_Z = sqrt(K_lambda(3, 3));
status = 0;
end

