function matplot_trajectory_200km_screen_dynamic(x_true, y_true, STATION_POSITIONS, res_pos, res_std, mc_y_estimations, true_y_center, methodName, window_idx, STATION_COUNTS_VECTOR, max_ylim_km)
% =========================================================================
% ГРАФИЧЕСКИЙ ДВИЖОК ДАЛЬНЕГО СТРЕСС-ТЕСТА С ЖЕСТКИМ РЕПЕРОМ МАСШТАБА RMSE
% Responsibility: Мозаичная раскладка 2х2 с фиксацией ylim по пределу CRLB
% Path: d:\workspace\libtr\matlabtests\matplot_trajectory_200km_screen_dynamic.m
% =========================================================================

% 1. Расчет геометрии монитора пользователя
screen_dims = get(0, 'ScreenSize');
screen_w = screen_dims(3);
screen_h = screen_dims(4);

% Вычисляем размер одного компактного окна (четверть экрана с полями)
fig_w = floor(screen_w / 2) - 15;
fig_h = floor(screen_h / 2) - 45;

% 2. Квадрантная логика размещения на основе жесткого индекса окна
switch window_idx
    case 1 % Левый верхний угол (LLS)
        pos_vector = [10, screen_h/2 + 5, fig_w, fig_h];
    case 2 % Левый нижний угол (WLLS)
        pos_vector = [10, 45, fig_w, fig_h];
    case 3 % Правый верхний угол (Декартов GN)
        pos_vector = [screen_w/2 + 5, screen_h/2 + 5, fig_w, fig_h];
    case 4 % Правый нижний угол (Полярный инвариант)
        pos_vector = [screen_w/2 + 5, 45, fig_w, fig_h];
    otherwise
        pos_vector = [100, 100, fig_w, fig_h];
end

figure('Name', methodName, 'Position', pos_vector);

% --- Сабплот 1: Траекторное облако оценок ---
subplot(3,1,1);
plot(x_true/1000, y_true/1000, 'k--', 'LineWidth', 2); hold on;
plot(res_pos.X/1000, res_pos.Y/1000, 'r.', 'MarkerSize', 4);
plot(STATION_POSITIONS(1,:)/1000, STATION_POSITIONS(2,:)/1000, 'b^', 'MarkerSize', 6, 'LineWidth', 1.5);
grid on; xlim([-800 800]); ylim([0 550]); % Диапазон расширен под 450 км
xlabel('X, km'); ylabel('Y, km'); title(methodName);

% --- Сабплот 2: Динамика сходимости С ЖЕСТКИМ ПРЕДЕЛОМ ШКАЛЫ ПО CRLB ---
subplot(3,1,2);
plot(STATION_COUNTS_VECTOR, res_std/1000, 'b-o', 'LineWidth', 1.5);
grid on; xlim([4 124]); 
ylim([0 max_ylim_km]); % Честная фиксация масштаба по теоретическому пределу
xlabel('Number of Accumulated Measurements (N)'); ylabel('Global RMSE, km');
title('Динамика сходимости погрешности от объема выборки');

% --- Сабплот 3: Эмпирическое распределение Монте-Карло ---
subplot(3,1,3);
histogram(mc_y_estimations/1000, 0:10:950, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', [0.5 0.5 0.5]); hold on;
xline(true_y_center/1000, 'r--', 'LineWidth', 2);
grid on; xlim([-10 950]);
xlabel('Y coordinate estimation, km'); ylabel('Counts');
title(sprintf('Empirical Distribution at Center (True Y = %d km)', round(true_y_center/1000)));
end
