function matplot_trajectory_200km_screen_dynamic(x_true, y_true, STATION_POSITIONS_BASE, fixed, summary_rmse, mc_y, y_center_true, method_name, m_idx, STATION_COUNTS_VECTOR, max_ylim_km)
% =========================================================================
% ОРИГИНАЛЬНЫЙ ГРАФИЧЕСКИЙ ДВИЖОК ТИС: ДИНАМИЧЕСКИЙ СТРАТЕГИЧЕСКИЙ ЭКРАН 450 КМ
% Responsibility: Выравнивание вертикальных шкал сходимости RMSE от 0 до 600 км
% Path: d:\workspace\libtr\matlabtests\matplot_trajectory_200km_screen_dynamic.m
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

figure('Name', method_name, 'Position', pos_vec);

% Сабплот 1: Дальняя траектория ТИС в масштабе со станциями креста
subplot(3,1,1);
plot(STATION_POSITIONS_BASE(1,:)/1000, STATION_POSITIONS_BASE(2,:)/1000, 'b^', 'MarkerSize', 8); hold on;
plot(x_true/1000, y_true/1000, 'k--', 'LineWidth', 2);
if isfield(fixed, 'X') && isfield(fixed, 'Y')
    plot(fixed.X/1000, fixed.Y/1000, 'r.', 'MarkerSize', 4);
elseif isfield(fixed, 'pos')
    plot(fixed.pos(1,:)/1000, fixed.pos(2,:)/1000, 'r.', 'MarkerSize', 4);
end
grid on; xlim([-160 160]); ylim([-50 500]); title('Strategic Trajectory, km');

% Сабплот 2: Динамика сходимости погрешности от объема выборки (тактов)
subplot(3,1,2);
plot(STATION_COUNTS_VECTOR, summary_rmse/1000, 'b-o', 'LineWidth', 1.5);
grid on; xlim([min(STATION_COUNTS_VECTOR) max(STATION_COUNTS_VECTOR)]); 

% ЖЕСТКОЕ ВЫРАВНИВАНИЕ ВЕРТИКАЛЬНОЙ ШКАЛЫ RMSE ОТ 0 ДО 600 КМ ДЛЯ ВСЕХ ОКН ТИС
ylim([0 600]); 
title('RMSE Сonvergence vs Accumulated Measurements (N), km');

% Сабплот 3: Изолированная плотность распределения Монте-Карло по оси Y
subplot(3,1,3);
mc_y_km = mc_y / 1000;
histogram(mc_y_km, 50, 'FaceColor', [0.7 0.7 0.7]); hold on;
xline(y_center_true/1000, 'r--', 'LineWidth', 2);
grid on; title('Empirical Distribution at Center (True Y = 450 km)');
xlabel('Y coordinate estimation, km'); ylabel('Counts');

% Визуальный зажим оси X для предотвращения растягивания от единичных сингулярностей
xlim([100 800]); 

sgtitle(method_name);
end
