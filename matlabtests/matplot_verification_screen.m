function matplot_verification_screen(x_true, y_true, STATION_X_ANCHORS, STATION_Y_ANCHORS, fixed, summary, crlb, STATION_COUNTS_VECTOR, FIXED_N_STATIONS, methodName, window_idx)
% =========================================================================
% ГРАФИЧЕСКИЙ ДВИЖОК ДЛЯ 30-КМ ТЕСТА С АВТОМАТИЧЕСКИМ РАЗМЕЩЕНИЕМ ОКОН
% Responsibility: Квадрантная мозаичная раскладка 2х2 на основе window_idx (1...4)
% Path: d:\workspace\libtr\matlabtests\matplot_verification_screen.m
% =========================================================================

% 1. Автоматический расчет геометрии экрана пользователя
screen_dims = get(0, 'ScreenSize');
screen_w = screen_dims(3);
screen_h = screen_dims(4);

% Вычисляем размер одного компактного окна (четверть экрана с полями под панель задач)
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

figure('Name', sprintf('30 км тест: %s', methodName), 'Position', pos_vector);

t_mesh = linspace(1, length(STATION_X_ANCHORS), 500);
x_km = x_true / 1000;

% Расчет полного среднегеометрического СКО и репера CRLB Geom
fixed_std_Geom = sqrt(fixed.std_X.^2 + fixed.std_Y.^2 + fixed.std_Z.^2);
crlb_Geom = sqrt(crlb.X.^2 + crlb.Y.^2 + crlb.Z.^2);

% --- Сабплот 1-1: Облако декартовых оценок на фоне S-сплайна станций ---
subplot(2,2,1);
plot(spline(1:length(STATION_X_ANCHORS), STATION_X_ANCHORS, t_mesh)/1000, spline(1:length(STATION_Y_ANCHORS), STATION_Y_ANCHORS, t_mesh)/1000, 'g-', 'LineWidth', 2); hold on;
plot(x_true/1000, y_true/1000, 'k--', 'LineWidth', 2);

if ~isempty(fixed.STATION_POSITIONS)
    plot(fixed.STATION_POSITIONS(1,:)/1000, fixed.STATION_POSITIONS(2,:)/1000, 'b^', 'MarkerSize', 6);
end
if ~isempty(fixed.pos)
    plot(fixed.pos(1,:)/1000, fixed.pos(2,:)/1000, 'r.', 'MarkerSize', 4);
end

grid on; axis equal; xlim([-25 25]); ylim([-10 40]); 
xlabel('X, km'); ylabel('Y, km'); title('Облако оценок');

% --- Сабплот 1-2: Сопоставление СКО метода и серого репера CRLB ---
subplot(2,2,2);
plot(x_km, crlb.X, 'Color', [0.6 0.6 0.6], 'LineStyle', '--', 'LineWidth', 1.2); hold on;
plot(x_km, crlb.Y, 'Color', [0.6 0.6 0.6], 'LineStyle', '--', 'LineWidth', 1.2);
plot(x_km, crlb.Z, 'Color', [0.6 0.6 0.6], 'LineStyle', '--', 'LineWidth', 1.2);
plot(x_km, crlb_Geom, 'Color', [0.4 0.4 0.4], 'LineStyle', ':', 'LineWidth', 1.5);

plot(x_km, fixed.std_X, 'g-', 'LineWidth', 1.5);
plot(x_km, fixed.std_Y, 'b-', 'LineWidth', 1.5);
plot(x_km, fixed.std_Z, 'r-', 'LineWidth', 1.5);
plot(x_km, fixed_std_Geom, 'k-', 'LineWidth', 2.0);

grid on; xlim([-15 15]); ylim([0 600]); 
xlabel('X, km'); ylabel('Errors / CRLB, meters'); title('СКО метода и репера CRLB');

% --- Сабплот 2-1: Сходимость полного пространственного промаха (RMSE) ---
subplot(2,2,3);
plot(STATION_COUNTS_VECTOR, summary.rmse, 'r-o', 'LineWidth', 1.5); hold on;
plot(STATION_COUNTS_VECTOR, summary.mean_miss, 'b-s', 'LineWidth', 1.5);
plot(STATION_COUNTS_VECTOR, summary.max_miss, 'g-^', 'LineWidth', 1.5);
grid on; xlim([min(STATION_COUNTS_VECTOR) max(STATION_COUNTS_VECTOR)]);
xlabel('Number of Stations along Spline'); ylabel('Miss Magnitude, meters'); title('Сходимость промаха');

% --- Сабплот 2-2: Сходимость систематической ошибки Bias Y ---
subplot(2,2,4);
plot(STATION_COUNTS_VECTOR, summary.bias_y, 'm-d', 'LineWidth', 1.5);
grid on; xlim([min(STATION_COUNTS_VECTOR) max(STATION_COUNTS_VECTOR)]);
xlabel('Number of Stations along Spline'); ylabel('Systemic Range Bias (Y), meters'); title('Сходимость Bias Y');

% Общий заголовок на фигуру
sgtitle(methodName);
end
