function [status, lambda] = lls3d_position(P, alpha, beta)
lambda = [0; 0; 0];
MAX_STATIONS = 64; 
M = size(P, 2);

if M < 2 || M > MAX_STATIONS || length(alpha) < M || length(beta) < M
    status = 1;
    return;
end

H = zeros(2*M, 3);
b = zeros(2*M, 1);

for i = 1:M
    sa = sin(alpha(i)); ca = cos(alpha(i));
    sb = sin(beta(i));  cb = cos(beta(i));
    xs = P(1, i); ys = P(2, i); zs = P(3, i);
    
    H(2*i-1, 1) = -sa;
    H(2*i-1, 2) =  ca;
    H(2*i-1, 3) =  0;
    b(2*i-1, 1) = -sa*xs + ca*ys;
    
    H(2*i, 1) = -sb * ca;
    H(2*i, 2) = -sb * sa;
    H(2*i, 3) =  cb;
    b(2*i, 1) = -sb*ca*xs - sb*sa*ys + cb*zs;
end

AtA = H.' * H;

if rcond(AtA) < 1e-12 || any(isnan(AtA(:))) || any(isinf(AtA(:)))
    status = 2;
    return;
end

lambda = AtA \ (H.' * b);
status = 0;
end
