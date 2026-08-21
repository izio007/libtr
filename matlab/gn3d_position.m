function [status, lambda] = gn3d_position(P, alpha, beta)
lambda = [0; 0; 0];
M = size(P, 2);

% --- Шаг 1: Базовый линейный МНК ---
H_lls = zeros(2*M, 3);
b_lls = zeros(2*M, 1);

for i = 1:M
    sa = sin(alpha(i)); ca = cos(alpha(i));
    sb = sin(beta(i));  cb = cos(beta(i));
    xs = P(1, i); ys = P(2, i); zs = P(3, i);
    
    H_lls(2*i-1, 1) = -sa;    H_lls(2*i-1, 2) =  ca;    H_lls(2*i-1, 3) =  0;
    b_lls(2*i-1, 1) = -sa*xs + ca*ys;
    
    H_lls(2*i, 1) = -sb * ca; H_lls(2*i, 2) = -sb * sa; H_lls(2*i, 3) =  cb;
    b_lls(2*i, 1) = -sb*ca*xs - sb*sa*ys + cb*zs;
end

AtA = H_lls.' * H_lls;
if rcond(AtA) < 1e-12
    status = 1; return; % Геометрический отказ линейного шага
end
lambda_lls = AtA \ (H_lls.' * b_lls);

% --- Шаг 2: Один нелинейный шаг Гаусса-Ньютона ---
x = lambda_lls(1); y = lambda_lls(2); z = lambda_lls(3);
J = zeros(2*M, 3);
delta_Y = zeros(2*M, 1);

for i = 1:M
    dx = x - P(1, i); dy = y - P(2, i); dz = z - P(3, i);
    rho_xy = sqrt(dx^2 + dy^2); rho = sqrt(dx^2 + dy^2 + dz^2);
    if rho_xy < 1e-3, rho_xy = 1e-3; end
    if rho < 1e-3, rho = 1e-3; end
    
    alpha_theo = atan2(dy, dx); beta_theo  = atan2(dz, rho_xy);
    
    d_alpha = alpha(i) - alpha_theo;
    d_alpha = atan2(sin(d_alpha), cos(d_alpha));
    d_beta  = beta(i) - beta_theo;
    
    delta_Y(2*i-1) = d_alpha;
    delta_Y(2*i)   = d_beta;
    
    sa = sin(alpha_theo); ca = cos(alpha_theo);
    sb = sin(beta_theo);  cb = cos(beta_theo);
    
    J(2*i-1, 1) = -sa / rho_xy; J(2*i-1, 2) =  ca / rho_xy; J(2*i-1, 3) =  0;
    J(2*i, 1) = -ca * sb / rho; J(2*i, 2) = -sa * sb / rho; J(2*i, 3) =  cb / rho;
end

JtJ = J.' * J;
if rcond(JtJ) < 1e-12
    lambda = lambda_lls; % Если нелинейный шаг выродился, возвращаем LLS
    status = 0; return;
end

lambda = lambda_lls + (JtJ \ (J.' * delta_Y));
status = 0;
end
