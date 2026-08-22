function [P_base, x_true, y_true, z_true, N_measurements, range_steps, sys_config] = service_init_geometry_criteria(criteria_idx, range_idx)
% =========================================================================
% СЛУЖЕБНАЯ ФУНКЦИЯ: ЕДИНЫЙ ЦЕНТРАЛЬНЫЙ КОНФИГУРАТОР ДАННЫХ И ГЕОМЕТРИИ ТИС
% Responsibility: Единственная точка задания сеток, шумов и RANDOM_SEED
% Path: d:\workspace\libtr\matlabtests\service_init_geometry_criteria.m
% =========================================================================

sys_config.DOA_ERROR_DEGREE = 2.0;
sys_config.CHOSEN_SEED       = 1337; 

range_steps = logspace(log10(1000), log10(450000 + 11000), 8) - 11000;
range_steps(1) = -10000; 

R_current = range_steps(range_idx);

P_square = [-20000, 20000, 20000, -20000; 
             20000, 20000, -20000, -20000; 
             0, 0, 0, 0];

switch criteria_idx
    case 1 
        P_base = P_square;
        x_true = 5420; 
        y_true = -3120; 
        z_true = 2500 + abs(R_current) * 0.01; 
        N_measurements = 4;
        
    case 2 % Критерий 2: Цель снаружи, последовательный обход ВСЕХ 4 квадрантов ТИС
        P_base = P_square;
        R_abs = abs(R_current);
        
        % Распределяем 8 точек сетки по 4 квадрантам (по 2 точки на квадрант)
        quadrant = mod(range_idx - 1, 4) + 1;
        
        switch quadrant
            case 1 % 1-й квадрант: X > 0, Y > 0 (шаги 1, 5)
                x_true =  R_abs * 0.7; 
                y_true =  R_abs * 0.7;
            case 2 % 2-й квадрант: X < 0, Y > 0 (шаги 2, 6)
                x_true = -R_abs * 0.7; 
                y_true =  R_abs * 0.7;
            case 3 % 3-й квадрант: X < 0, Y < 0 (шаги 3, 7)
                x_true = -R_abs * 0.7; 
                y_true = -R_abs * 0.7;
            case 4 % 4-й квадрант: X > 0, Y < 0 (шаги 4, 8)
                x_true =  R_abs * 0.7; 
                y_true = -R_abs * 0.7;
        end
        z_true = 8000;
        N_measurements = 4;
        
    case 3 
        P_base = [-10000, 10000; 0, 0; 0, 0]; 
        x_true = 0; y_true = abs(R_current); z_true = 5000;
        N_measurements = 2;
        
    case 4 
        P_base = P_square;
        x_true = 0; y_true = abs(R_current); z_true = 0;
        N_measurements = 4;
        
    case 5 
        P_base = P_square;
        x_true = 12000; y_true = abs(R_current); z_true = 6000;
        N_measurements = 4;
end
end
