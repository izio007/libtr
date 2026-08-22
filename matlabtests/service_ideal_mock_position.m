function [status, lambda_ideal] = service_ideal_mock_position(P, X_target, Y_target, Z_target)
lambda_ideal = [NaN; NaN; NaN];
M = size(P, 2);

if M < 2
    status = 2; return;
end

H = zeros(2*M, 3);
b = zeros(2*M, 1);

for i = 1:M
    xs = P(1, i); ys = P(2, i); zs = P(3, i);
    dx = X_target - xs; 
    dy = Y_target - ys; 
    dz = Z_target - zs;
    
    rho_xy = sqrt(dx^2 + dy^2);
    if rho_xy < 1e-3, rho_xy = 1e-3; end
    
    alpha_ideal = atan2(dy, dx);
    beta_ideal  = atan2(dz, rho_xy);
    
    sa = sin(alpha_ideal); ca = cos(alpha_ideal);
    sb = sin(beta_ideal);  cb = cos(beta_ideal);
    
    H(2*i-1, 1) = sa;
    H(2*i-1, 2) = -ca;
    H(2*i-1, 3) = 0;
    b(2*i-1, 1) = sa*xs - ca*ys;
    
    H(2*i, 1) = -ca * sb;
    H(2*i, 2) = -sa * sb;
    H(2*i, 3) = cb;
    b(2*i, 1) = -ca*sb*xs - sa*sb*ys + cb*zs;
end

AtA = H.' * H;

if rcond(AtA) < eps || isnan(rcond(AtA))
    status = 2; return;
end

lambda_ideal = AtA \ (H.' * b);
status = 0;
end
