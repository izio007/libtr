function crlb = service_calc_crlb_trajectory(DataContext, N_active)
% COMPUTATION KERNEL: INVARIANT THEORETICAL RAO-CRAMER SECTIONS CALCULATOR
% SYSTEM MATRIX CONTEXT: STRICT GENERAL PRINCIPLE / K_CART TO LOS COV2STD Contract
% PATH: f:\sy\workspace\libtr\matlab\service_calc_crlb_trajectory.m

    Points = length(DataContext.X_true);
    
    crlb.X = zeros(1, Points); % Поле обратной совместимости для легаси-экранов
    crlb.Y = zeros(1, Points);
    crlb.Z = zeros(1, Points);
    
    % Канонические ракурсные поля ТИС, которые жестко ищет Сабплот 2!
    crlb.radial = zeros(1, Points);
    crlb.cross1 = zeros(1, Points);
    crlb.cross2 = zeros(1, Points);
    
    % Входные дисперсии приборного шума измерительной сети из ОЗУ контейнера
    var_alpha = DataContext.var_alpha_max(1:N_active);
    var_beta  = DataContext.var_beta_max(1:N_active);
    P_active  = DataContext.P_max_matrix(:, 1:N_active);
    
    % Координаты центра измерительного куста ТИС (геометрический наблюдатель)
    lambda_observer = mean(P_active, 2);

    for k = 1:Points
        % Истинная 3D-координата цели на текущем такте траектории k
        lambda_true_k = [DataContext.X_true(k); ...
                         DataContext.Y_true(k); ...
                         DataContext.Z_true(k)];
                     
        alpha_ideal_k = zeros(N_active, 1);
        beta_ideal_k  = zeros(N_active, 1);
        
        % Векторизованный сбор эталонных аналитических пеленгов такта
        for i = 1:N_active
            dx = lambda_true_k(1) - P_active(1, i);
            dy = lambda_true_k(2) - P_active(2, i);
            dz = lambda_true_k(3) - P_active(3, i);
            
            alpha_ideal_k(i) = atan2(dy, dx);
            beta_ideal_k(i)  = atan2(dz, sqrt(dx^2 + dy^2));
        end
        
        % 1. СТРOГO ОРИГИНАЛЬНЫЙ ВЫЗОВ МАТЕМАТИЧЕСКОГО ЯДРА CRLB КОИВАРИАЦИИ
        [status_crlb, K_crlb] = crlb_covariance(P_active, alpha_ideal_k, beta_ideal_k, ...
                                                var_alpha, var_beta, lambda_true_k);
        
        if status_crlb == 0
            % 2. СТРOГO ОРИГИНАЛЬНЫЙ ВЫЗОВ ЯДРА ПЕРЕВОДА ДЕКАРТОВЫХ КОМПОНЕНТ В СЕЧЕНИЯ ЛУЧА
            [status_std, s_rad, s_cr1, s_cr2] = ll_cov2std(K_crlb, lambda_true_k, lambda_observer);
            
            if status_std == 0
                % Наполнение ракурсных шкал точности ТИС (Истинный физический смысл)
                crlb.radial(k) = s_rad;
                crlb.cross1(k) = s_cr1;
                crlb.cross2(k) = s_cr2;
                
                % Дублирование полей для полной обратной совместимости легаси-осей
                crlb.X(k) = sqrt(max(K_crlb(1, 1), 0.0));
                crlb.Y(k) = sqrt(max(K_crlb(2, 2), 0.0));
                crlb.Z(k) = sqrt(max(K_crlb(3, 3), 0.0));
            else
                crlb.radial(k) = NaN; crlb.cross1(k) = NaN; crlb.cross2(k) = NaN;
                crlb.X(k) = NaN;      crlb.Y(k) = NaN;      crlb.Z(k) = NaN;
            end
        else
            crlb.radial(k) = NaN; crlb.cross1(k) = NaN; crlb.cross2(k) = NaN;
            crlb.X(k) = NaN;      crlb.Y(k) = NaN;      crlb.Z(k) = NaN;
        end
    end
end
