function [status, std_X, std_Y, std_Z] = lls3d_covariance_linear(P, alpha, beta, var_alpha, var_beta, lambda_lls)
% =========================================================================
% СТРОГАЯ ФУНКЦИЯ РАСЧЕТА СКО ДЛЯ ЛИНЕЙНОГО МНК (LLS COVARIANCE)
% =========================================================================
% Входные параметры:
%   P                - Матрица координат измерительных пунктов [3 x M]
%   alpha, beta      - Векторы измеренных углов [M x 1] (радианы)
%   var_alpha, beta  - Векторы дисперсий углового шума каналов [M x 1]
%   lambda_estimated - Оцененные линейные координаты цели [x; y; z]
% Выходные параметры:
%   status           - Флаг выполнения (0 - успешно, >0 - сбой)
%   std_X, std_Y, Z  - Изолированные СКО по осям (в метрах)
% =========================================================================
std_X = NaN; std_Y = NaN; std_Z = NaN;
M = size(P, 2);

if M < 2 || length(lambda_lls) ~= 3
    status = 1; return;
end

H = zeros(2*M, 3);
for i = 1:M
    sa = sin(alpha(i)); ca = cos(alpha(i));
    sb = sin(beta(i));  cb = cos(beta(i));
    H(2*i-1, 1) = -sa;     H(2*i-1, 2) = ca;      H(2*i-1, 3) = 0;
    H(2*i, 1)   = -sb*ca;  H(2*i, 2)   = -sb*sa;  H(2*i, 3)   = cb;
end

AtA = H.' * H;
if rcond(AtA) < 1e-12
    status = 2; return;
end

% Матрица дисперсий ошибок измерений в линейном масштабе плоскостей
diag_Kb = zeros(2*M, 1);
for i = 1:M
    % Дальность считается СТРОГО до точки, которую выдал LLS
    dx = lambda_lls(1) - P(1, i); 
    dy = lambda_lls(2) - P(2, i); 
    dz = lambda_lls(3) - P(3, i);
    rho_sq = dx^2 + dy^2 + dz^2;
    
    diag_Kb(2*i-1) = var_alpha(i) * rho_sq;
    diag_Kb(2*i)   = var_beta(i) * rho_sq;
end

% Классический линейный МНК-оператор: C = (H' * H)^-1 * H'
C_op = AtA \ H.';
K_lambda = C_op * diag(diag_Kb) * C_op.';

std_X = sqrt(K_lambda(1, 1));
std_Y = sqrt(K_lambda(2, 2));
std_Z = sqrt(K_lambda(3, 3));
status = 0;
end

