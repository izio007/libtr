function [x_true, y_true, z_true, STATION_POSITIONS] = gen_scenario_30km(N_STATIONS, x_offset)
    % Генерирует траекторию и позиции станций (S-сплайн)
    TRAJECTORY_POINTS_COUNT = 500;
    t_steps = linspace(0, 1, TRAJECTORY_POINTS_COUNT);
    x_true = -15000 + 30000 * t_steps;
    y_true = 30000 * ones(size(t_steps));
    z_true = zeros(size(t_steps));
    
    % Заглушки для якорей (заполните значениями)
    STATION_X_ANCHORS = [0, -5000, 5000, 2500] + x_offset;
    STATION_Y_ANCHORS = [0, 1000, -1000, 0];
    STATION_Z_ANCHORS = [0, 0, 0, 0];
    
    t_anchors = 1:4;
    t_query = linspace(1, 4, N_STATIONS);
    STATION_POSITIONS = [spline(t_anchors, STATION_X_ANCHORS, t_query); ...
                         spline(t_anchors, STATION_Y_ANCHORS, t_query); ...
                         spline(t_anchors, STATION_Z_ANCHORS, t_query)];
end
