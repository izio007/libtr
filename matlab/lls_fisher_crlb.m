function [status, crlb_X, crlb_Y, crlb_Z] = lls_fisher_crlb(P, var_alpha, var_beta, X_target, Y_target, Z_target)
% =========================================================================
% ФУНКЦИЯ РАСЧЕТА ТЕОРЕТИЧЕСКОГО ПРЕДЕЛА ТОЧНОСТИ (ГРАНИЦА РАО-КРАМЕРА - CRLB)
% Входные параметры:
%   P         - Физическая матрица координат измерительных пунктов [3 x M]
%   var_alpha - Вектор дисперсий шума азимутальных каналов [M x 1] (радианы^2)
%   var_beta  - Вектор дисперсий шума угломестных каналов [M x 1] (радианы^2)
%   X_target  - Истинная декартова координата цели X (метры)
%   Y_target  - Истинная декартова координата цели Y (метры)
%   Z_target  - Истинная декартова координата цели Z (метры)
% =========================================================================
crlb_X = NaN; crlb_Y = NaN; crlb_Z = NaN;
M = size(P, 2);

if M < 2 || length(var_alpha) < M || length(var_beta) < M
    status = 1; return;
end

J = zeros(2*M, 3);
W_noise = zeros(2*M, 1);

for i = 1:M
    xs = P(1, i); ys = P(2, i); zs = P(3, i);
    dx = X_target - xs; dy = Y_target - ys; dz = Z_target - zs;
    
    rho_xy = sqrt(dx^2 + dy^2); rho = sqrt(dx^2 + dy^2 + dz^2);
    if rho_xy < 1e-3, rho_xy = 1e-3; end
    if rho < 1e-3,    rho = 1e-3; end
    
    alpha_theo = atan2(dy, dx); beta_theo = atan2(dz, rho_xy);
    sa = sin(alpha_theo); ca = cos(alpha_theo);
    sb = sin(beta_theo);  cb = cos(beta_theo);
    
    J(2*i-1, 1) = sa;     J(2*i-1, 2) = -ca;    J(2*i-1, 3) = 0;
    J(2*i, 1)   = -ca * sb; J(2*i, 2)   = -sa * sb; J(2*i, 3)   = cb;
    
    W_noise(2*i-1) = 1.0 / (var_alpha(i) * (rho.^2));
    W_noise(2*i)   = 1.0 / (var_beta(i) * (rho.^2));
end

I_Fisher = J.' * diag(W_noise) * J;

if rcond(I_Fisher) < eps || isnan(rcond(I_Fisher))
    status = 2; return;
end

K_CRLB = inv(I_Fisher);
crlb_X = sqrt(K_CRLB(1, 1));
crlb_Y = sqrt(K_CRLB(2, 2));
crlb_Z = sqrt(K_CRLB(3, 3));
status = 0;
end
