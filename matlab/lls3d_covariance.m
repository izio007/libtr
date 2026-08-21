function [status, K_lambda, std_3d] = lls3d_covariance(P, alpha, beta, var_alpha, var_beta, lambda_estimated)
K_lambda = zeros(3,3);
std_3d = 0;
MAX_STATIONS = 64;
M = size(P, 2);

if M < 2 || M > MAX_STATIONS || ...
   length(alpha) < M || length(beta) < M || ...
   length(var_alpha) < M || length(var_beta) < M || ...
   length(lambda_estimated) ~= 3
    status = 1;
    return;
end

if any(isnan(lambda_estimated)) || any(isinf(lambda_estimated))
    status = 2;
    return;
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
    status = 3;
    return;
end

x = lambda_estimated(1); y = lambda_estimated(2); z = lambda_estimated(3);
diag_Ky = zeros(2*M, 1);

for i = 1:M
    dx = x - P(1, i); dy = y - P(2, i); dz = z - P(3, i);
    rho = sqrt(dx^2 + dy^2 + dz^2);
    if rho < 1e-3, rho = 1e-3; end
    diag_Ky(2*i-1) = var_alpha(i) * (rho^2);
    diag_Ky(2*i)   = var_beta(i) * (rho^2);
end

C_op = AtA \ H.';
K_lambda = C_op * diag(diag_Ky) * C_op.';

trace_val = trace(K_lambda);
if trace_val < 0 || isnan(trace_val) || isinf(trace_val)
    status = 4;
    K_lambda = zeros(3,3);
    return;
end

std_3d = sqrt(trace_val);
status = 0;
end
