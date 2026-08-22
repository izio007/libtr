function [status, lambda] = wlls3d_position(P, alpha, beta, W_diag)
% =========================================================================
% ФУНКЦИЯ КЛАССИЧЕСКОГО ВЗВЕШЕННОГО ЛИНЕЙНОГО 3D-ПОЗИЦИОНИРОВАНИЯ (WLLS)
% Входные параметры:
%   P      - Физическая матрица координат измерительных пунктов [3 x M]
%   alpha  - Вектор измеренных азимутов цели [M x 1] (радианы)
%   beta   - Вектор измеренных углов места цели [M x 1] (радианы)
%   W_diag - Диагональный вектор весов измерительных каналов [2M x 1]
% Выходные параметры:
%   status - Флаг выполнения (0 - успешно, 1 - сбой размерности, 2 - вырождение)
%   lambda - Оцененные декартовы координаты цели [x; y; z] (метры)
% =========================================================================
lambda = [NaN; NaN; NaN];
M = size(P, 2);

if M < 2 || length(W_diag) < 2*M
    status = 1; return;
end

H = zeros(2*M, 3);
b = zeros(2*M, 1);

for i = 1:M
    sa = sin(alpha(i)); ca = cos(alpha(i));
    sb = sin(beta(i));  cb = cos(beta(i));
    xs = P(1, i); ys = P(2, i); zs = P(3, i);
    
    H(2*i-1, 1) = sa;
    H(2*i-1, 2) = -ca;
    H(2*i-1, 3) = 0;
    b(2*i-1, 1) = sa*xs - ca*ys;
    
    H(2*i, 1) = -ca * sb;
    H(2*i, 2) = -sa * sb;
    H(2*i, 3) = cb;
    b(2*i, 1) = -ca*sb*xs - sa*sb*ys + cb*zs;
end

W = diag(W_diag);
AtWA = H.' * W * H;

if rcond(AtWA) < 2.2204e-16 || isnan(rcond(AtWA))
    status = 2; return;
end

lambda = AtWA \ (H.' * W * b);
status = 0;
end
