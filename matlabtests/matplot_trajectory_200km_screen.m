function matplot_trajectory_200km_screen(x_true, y_true, STATION_POSITIONS, res_pos, res_std, mc_y_estimations, true_y_center, methodName, window_idx, STATION_COUNTS_VECTOR)
% =========================================================================
% ГРАФИЧЕСКИЙ ДВИЖОК ДАЛЬНЕГО ТЕСТА С АВТОМАТИЧЕСКИМ РАЗМЕЩЕНИЕМ ОКОН
% =========================================================================

% 1. Расчет геометрии монитора пользователя
screen_dims = get(0, 'ScreenSize');
screen_w = screen_dims(3);
screen_h = screen_dims(4);

fig_w = floor(screen_w / 2) - 15;
fig_h = floor(screen_h / 2) - 45;

switch window_idx
    case 1, pos_vector = [10, screen_h/2 + 5, fig_w, fig_h];
    case 2, pos_vector = [10, 45, fig_w, fig_h];
    case 3, pos_vector = [screen_w/2 + 5, screen_h/2 + 5, fig_w, fig_h];
    case 4, pos_vector = [screen_w/2 + 5, 45, fig_w, fig_h];
    otherwise, pos_vector = [100, 100, fig_w, fig_h];
end

figure('Name', sprintf('Дальний тест: %s', methodName), 'Position', pos_vector);

% --- Сабплот 1: Траекторное облако оценок ---
subplot(3,1,1);
plot(x_true/1000, y_true/1000, 'k--', 'LineWidth', 2); hold on;
plot(res_pos.X/1000, res_pos.Y/1000, 'r.', 'MarkerSize', 4);
plot(STATION_POSITIONS(1,:)/1000, STATION_POSITIONS(2,:)/1000, 'b^', 'MarkerSize', 6, 'LineWidth', 1.5);
grid on; xlim([-800 800]); ylim([0 300]);
xlabel('X, km'); ylabel('Y, km'); title(methodName);

% --- Сабплот 2: Динамика сходимости погрешности ОТНОСИТЕЛЬНО ПРЕДЕЛА CRLB ---
subplot(3,1,2);
plot(STATION_COUNTS_VECTOR, res_std/1000, 'b-o', 'LineWidth', 1.5);
grid on; xlim([4 124]); 
ylim([0 max_ylim_km]); % Шкала жестко привязана к верхнему пределу CRLB (N=4)
xlabel('Number of Accumulated Measurements (N)'); ylabel('Global RMSE, km');
title('Динамика сходимости погрешности от объема выборки');

% --- Сабплот 3: Эмпирическое распределение Монте-Карло ---
subplot(3,1,3);
histogram(mc_y_estimations/1000, 0:5:650, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', [0.5 0.5 0.5]); hold on;
xline(true_y_center/1000, 'r--', 'LineWidth', 2);
grid on; xlim([-10 650]);
xlabel('Y coordinate estimation, km'); ylabel('Counts');
title(sprintf('Empirical Distribution at Center (True Y = %d km)', round(true_y_center/1000)));
end
