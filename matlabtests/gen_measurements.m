function [alpha_m_matrix, beta_m_matrix, crlb] = gen_measurements(STATION_POSITIONS, x_true, y_true, z_true, DOA_ERROR_DEG)
    N_STATIONS = size(STATION_POSITIONS, 2);
    K_points = length(x_true);
    VAR_RAD = deg2rad(DOA_ERROR_DEG)^2;
    
    % Инициализация
    alpha_m_matrix = zeros(N_STATIONS, K_points);
    beta_m_matrix  = zeros(N_STATIONS, K_points);
    crlb.X = zeros(K_points, 1); crlb.Y = zeros(K_points, 1);
    crlb.Z = zeros(K_points, 1); crlb.G = zeros(K_points, 1);
    
    rng(1337); % Стабилизация
    
    for k = 1:K_points
        % Расчет CRLB (ядро)
        [st_f, cx, cy, cz] = lls3d_fisher_crlb(STATION_POSITIONS, VAR_RAD * ones(N_STATIONS, 1), VAR_RAD * ones(N_STATIONS, 1), x_true(k), y_true(k), z_true(k));
        if st_f == 0
            crlb.X(k, 1) = cx; 
            crlb.Y(k, 1) = cy; 
            crlb.Z(k, 1) = cz;
            crlb.G(k, 1) = sqrt(cx^2 + cy^2 + cz^2);
        else
            crlb.X(k, 1) = NaN; crlb.Y(k, 1) = NaN; crlb.Z(k, 1) = NaN; crlb.G(k, 1) = NaN;
        end

        
        % Генерация зашумленных пеленгов
        for i = 1:N_STATIONS
            dx = x_true(k) - STATION_POSITIONS(1, i);
            dy = y_true(k) - STATION_POSITIONS(2, i);
            dz = z_true(k) - STATION_POSITIONS(3, i);
            alpha_m_matrix(i, k) = atan2(dy, dx) + sqrt(VAR_RAD) * randn();
            beta_m_matrix(i, k)  = atan2(dz, sqrt(dx^2 + dy^2)) + sqrt(VAR_RAD) * randn();
        end
    end
end
