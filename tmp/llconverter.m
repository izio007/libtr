classdef llconverter
    % =========================================================================
    % CORE RADAR KERNEL: UNIFIED COORDINATE CONVERTER PROCESSOR (SOLID)
    % GEODETIC DATUM CONTEXT: KRASOVSKY ELLIPSOID CONSTANTS
    %
    % PURPOSE:
    %   Высокоскоростной координатный процессор ТИС. Выполняет взаимный прецизионный
    %   перевод векторов состояний целей [3 x N] между приборными, локальными (ENU),
    %   геоцентрическими (ECEF) и географическими (LLA) системами координат.
    % =========================================================================
    
    properties (Constant, Access = private)
        % Фундаментальные радарные константы Красовского (llconverter.c)
        a  = 6378136.0;                    % Большая полуось эллипсоида, метры
        f  = 1.0 / 298.3;                  % Геометрическое сплюснутость
        e2 = (1.0 / 298.3) * (2 - 1.0 / 298.3); % Квадрат первого эксцентриситета
    end
    
    methods (Static, Access = public)
        function [az, el, r] = ll_xyz2aer(dr, R_ant)
            if nargin < 2 || isempty(R_ant), R_ant = eye(3); end
            
            % Матричный тензорный разворот приращений земли в СК полотна антенны
            dr_ant = R_ant * dr;
            
            dx = dr_ant(1, :);
            dy = dr_ant(2, :);
            dz = dr_ant(3, :);
            
            r = sqrt(dx.^2 + dy.^2 + dz.^2);
            az = atan2(dy, dx);
            el = atan2(dz, sqrt(dx.^2 + dy.^2));
        end
        
        function [dr] = ll_aer2xyz(az, el, r, R_ant)
            if nargin < 4 || isempty(R_ant), R_ant = eye(3); end
            
            dx_a = r .* cos(az) .* cos(el);
            dy_a = r .* sin(az) .* cos(el);
            dz_a = r .* sin(el);
            
            % Обратный разворот осей полотна антенны на декартову землю ТИС
            dr = R_ant.' * [dx_a; dy_a; dz_a];
        end
        
        function [ENU] = ll_ecef2enu(X_target, X_ref)
            [lat_r, lon_r, ~] = llconverter.ecef2lla_local(X_ref);
            
            dx = X_target(1, :) - X_ref(1);
            dy = X_target(2, :) - X_ref(2);
            dz = X_target(3, :) - X_ref(3);
            
            slat = sin(lat_r); clat = cos(lat_r);
            slon = sin(lon_r); clon = cos(lon_r);
            
            % Строгая ортогональная матрица пространственного поворота осей
            E = -slon .* dx + clon .* dy;
            N = -slat .* clon .* dx - slat .* slon .* dy + clat .* dz;
            U =  clat .* clon .* dx + clat .* slon .* dy + slat .* dz;
            
            ENU = [E; N; U];
        end
        
        function [X_target] = ll_enu2ecef(ENU, X_ref)
            [lat_r, lon_r, ~] = llconverter.ecef2lla_local(X_ref);
            
            E = ENU(1, :); N = ENU(2, :); U = ENU(3, :);
            
            slat = sin(lat_r); clat = cos(lat_r);
            slon = sin(lon_r); clon = cos(lon_r);
            
            % Обратный разворот локального бокса ТИС на геоцентрическую землю
            dx = -slon .* E - slat .* clon .* N + clat .* clon .* U;
            dy =  clon .* E - slat .* slon .* N + clat .* slon .* U;
            dz =  clat .* N + slat .* U;
            
            X_target = [dx + X_ref(1); dy + X_ref(2); dz + X_ref(3)];
        end
        
        function [lat, lon, alt] = ll_enu2lla(ENU, X_ref)
            X_ecef = llconverter.ll_enu2ecef(ENU, X_ref);
            [lat, lon, alt] = llconverter.ecef2lla_local(X_ecef);
        end
        
        function [ENU] = ll_lla2enu(lat, lon, alt, X_ref)
            X_ecef = llconverter.lla2ecef_local(lat, lon, alt);
            ENU = llconverter.ll_ecef2enu(X_ecef, X_ref);
        end
    end
    
    methods (Static, Access = private)
        function [lat, lon, alt] = ecef2lla_local(X)
            % Внутренний прецизионный алгоритм Боуринга на сфероиде Красовского
            a_k = llconverter.a; 
            e2_k = llconverter.e2;
            b = a_k * (1 - llconverter.f); 
            e_prime2 = (a_k^2 - b^2) / b^2;
            
            x = X(1, :); y = X(2, :); z = X(3, :);
            
            lon = atan2(y, x);
            p = sqrt(x.^2 + y.^2);
            psi = atan2(z .* a_k, p .* b);
            
            lat = atan2(z + e_prime2 .* b .* sin(psi).^3, p - e2_k * a_k * cos(psi).^3);
            N_phi = a_k ./ sqrt(1 - e2_k .* sin(lat).^2);
            alt = p ./ cos(lat) - N_phi;
        end
        
        function [X] = lla2ecef_local(lat, lon, alt)
            % Внутренний перевод географических координат в геоцентрический Декарт
            a_k = llconverter.a; 
            e2_k = llconverter.e2;
            
            N = a_k ./ sqrt(1.0 - e2_k .* sin(lat).^2);
            
            x = (N + alt) .* cos(lat) .* cos(lon);
            y = (N + alt) .* cos(lat) .* sin(lon);
            z = (N .* (1 - e2_k) + alt) .* sin(lat);
            
            X = [x; y; z];
        end
    end
end
