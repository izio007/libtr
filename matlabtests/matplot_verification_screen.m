function matplot_verification_screen(x_true, y_true, STATION_X_ANCHORS, STATION_Y_ANCHORS, fixed, summary, crlb, STATION_COUNTS_VECTOR, FIXED_N_STATIONS, method_label, m_idx)
% =========================================================================
% ОРИГИНАЛЬНЫЙ ГРАФИЧЕСКИЙ ДВИЖОК ТИС: ЧИСТАЯ МОЗАИКА 2х2 ДЛЯ СПЛАЙНА 30 КМ
% Path: d:\workspace\libtr\matlabtests\matplot_verification_screen.m
% =========================================================================

screen_dims = get(0, 'ScreenSize');
screen_w = screen_dims(3); screen_h = screen_dims(4);
fig_w = floor(screen_w / 2) - 15; fig_h = floor(screen_h / 2) - 45;

switch m_idx
    case 1, pos_vec = [10, screen_h/2 + 5, fig_w, fig_h];
    case 2, pos_vec = [10, 45, fig_w, fig_h];
    case 3, pos_vec = [screen_w/2 + 5, screen_h/2 + 5, fig_w, fig_h];
    case 4, pos_vec = [screen_w/2 + 5, 45, fig_w, fig_h];
end

figure('Name', method_label, 'Position', pos_vec);

% Сабплот 1: Траектория и облако оценок
subplot(2,2,1);
t_m = linspace(1, 4, 500);
plot(spline(1:4, STATION_X_ANCHORS, t_m)/1000, spline(1:4, STATION_Y_ANCHORS, t_m)/1000, 'g-', 'LineWidth', 2); hold on;
plot(x_true/1000, y_true/1000, 'k--', 'LineWidth', 2);
if isfield(fixed, 'pos') && ~isempty(fixed.pos)
    plot(fixed.pos(1,:)/1000, fixed.pos(2,:)/1000, 'r.', 'MarkerSize', 4);
end
grid on; axis equal; xlim([-25 25]); ylim([-10 40]); title('Облако оценок 30км');

% =========================================================================
% Сабплот 2: Теоретические компоненты СКО против CRLB (ПОЛНЫЙ ВЫВОД 4 ЛИНИЙ)
% =========================================================================
subplot(2,2,2);

% Расчет суммарного пространственного предела Рао-Крамера ТИС
crlb_Geom = sqrt(crlb.X.^2 + crlb.Y.^2 + crlb.Z.^2);

% Вывод всех четырех канонических линий репера Фишера
plot(x_true/1000, crlb.X, 'k--', 'LineWidth', 1); hold on; % Теоретический порог X
plot(x_true/1000, crlb.Y, 'k:',  'LineWidth', 1);          % Теоретический порог Y
plot(x_true/1000, crlb.Z, 'k-.', 'LineWidth', 1);          % Теоретический порог Z
plot(x_true/1000, crlb_Geom, 'k-', 'LineWidth', 1.2);       % Полный теоретический CRLB

if isfield(fixed, 'std_X')
    plot(x_true/1000, fixed.std_X, 'g-', 'LineWidth', 1.5);
    plot(x_true/1000, fixed.std_Y, 'b-', 'LineWidth', 1.5);
    plot(x_true/1000, fixed.std_Z, 'r-', 'LineWidth', 1.5);
    fixed_std_Geom = sqrt(fixed.std_X.^2 + fixed.std_Y.^2 + fixed.std_Z.^2);
    plot(x_true/1000, fixed_std_Geom, 'k-', 'LineWidth', 2.0);
end
grid on; xlim([-15 15]); ylim([0 1400]); title('Errors / CRLB, meters');


% Сабплот 3: Сходимость полного промаха RMSE от числа станций N
subplot(2,2,3);
plot(STATION_COUNTS_VECTOR, summary.rmse, 'b-s', 'LineWidth', 1.5); hold on;
plot(STATION_COUNTS_VECTOR, summary.mean_miss, 'g-o', 'LineWidth', 1.5);
plot(STATION_COUNTS_VECTOR, summary.max_miss, 'r-d', 'LineWidth', 1.5);
grid on; xlim([min(STATION_COUNTS_VECTOR) max(STATION_COUNTS_VECTOR)]); title('RMSE / Mean / Max Miss vs N');

% Сабплот 4: Систематический Bias Y от числа станций N
subplot(2,2,4);
plot(STATION_COUNTS_VECTOR, summary.bias_y, 'm-d', 'LineWidth', 1.5);
grid on; xlim([min(STATION_COUNTS_VECTOR) max(STATION_COUNTS_VECTOR)]); title('Bias Y vs N');
sgtitle(method_label);
end
