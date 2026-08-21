function matplot_verification_screen(x_true, y_true, STATION_X_ANCHORS, STATION_Y_ANCHORS, fixed, summary, crlb, STATION_COUNTS_VECTOR, FIXED_N_STATIONS, methodName)
% =========================================================================
% ГРАФИЧЕСКИЙ ДВИЖОК: СТРОГИЙ ВЫВОД ПОЛНОГО ЭКРАНА СРАВНЕНИЯ (5 ГРАФИКОВ)
% =========================================================================
x_km = x_true / 1000;
t_mesh = linspace(1, length(STATION_X_ANCHORS), 500);

% Находим среднегеометрическую (полную) ошибку метода и репера
fixed_std_Geom = sqrt(fixed.std_X.^2 + fixed.std_Y.^2 + fixed.std_Z.^2);
crlb_Geom = sqrt(crlb.X.^2 + crlb.Y.^2 + crlb.Z.^2);

% --- ЕДИНАЯ ИСПЫТАТЕЛЬНАЯ ФИГУРА ---
figure('Name', sprintf('Аналитический экран: %s', methodName), 'Position', [50 50 1200 800]);

% График 1-1: Физическая геометрия сплайна и облако оценок такта
subplot(2,2,1);
plot(spline(1:length(STATION_X_ANCHORS), STATION_X_ANCHORS, t_mesh)/1000, spline(1:length(STATION_Y_ANCHORS), STATION_Y_ANCHORS, t_mesh)/1000, 'g-', 'LineWidth', 2); hold on;
plot(x_true/1000, y_true/1000, 'k--', 'LineWidth', 2);
plot(fixed.STATION_POSITIONS(1,:)/1000, fixed.STATION_POSITIONS(2,:)/1000, 'b^', 'MarkerSize', 6);
plot(fixed.pos(1,:)/1000, fixed.pos(2,:)/1000, 'r.', 'MarkerSize', 4);
grid on; axis equal; xlim([-25 25]); ylim([-10 40]); xlabel('X, km'); ylabel('Y, km');
title(sprintf('Облако оценок (Станций = %d)', FIXED_N_STATIONS));

% График 1-2: ОБЪЕДИНЕННЫЙ ПРОФИЛЬ СКО С РЕПЕРОМ СЕРЫМИ ЛИНИЯМИ + СРЕДНЕГЕОМЕТРИЧЕСКАЯ
subplot(2,2,2);
% Подложка: Серые линии теоретического предела Рао-Крамера (CRLB)
plot(x_km, crlb.X, 'Color', [0.6 0.6 0.6], 'LineStyle', '--', 'LineWidth', 1.2); hold on;
plot(x_km, crlb.Y, 'Color', [0.6 0.6 0.6], 'LineStyle', '--', 'LineWidth', 1.2);
plot(x_km, crlb.Z, 'Color', [0.6 0.6 0.6], 'LineStyle', '--', 'LineWidth', 1.2);
plot(x_km, crlb_Geom, 'Color', [0.4 0.4 0.4], 'LineStyle', ':', 'LineWidth', 1.5);

% Лицо: Цветные расчетные профили погрешностей метода
plot(x_km, fixed.std_X, 'g-', 'LineWidth', 1.8);
plot(x_km, fixed.std_Y, 'b-', 'LineWidth', 1.8);
plot(x_km, fixed.std_Z, 'r-', 'LineWidth', 1.8);
plot(x_km, fixed_std_Geom, 'k-', 'LineWidth', 2.0); % Среднегеометрическая оценка

grid on; xlim([-20 20]); xlabel('X, km'); ylabel('Errors / CRLB, meters');
legend('CRLB X', 'CRLB Y', 'CRLB Z', 'CRLB Geom', 'СКО X', 'СКО Y', 'СКО Z', 'Среднегеом. СКО', 'Location', 'northeast');
title('Сопоставление СКО метода и репера CRLB');

% График 2-1: Глобальная сходимость промаха от плотности сетки (RMSE, Mean, Max)
subplot(2,2,3);
plot(STATION_COUNTS_VECTOR, summary.rmse, 'r-o', 'LineWidth', 2); hold on;
plot(STATION_COUNTS_VECTOR, summary.mean_miss, 'b-s', 'LineWidth', 1.5);
plot(STATION_COUNTS_VECTOR, summary.max_miss, 'g-^', 'LineWidth', 1.5);
grid on; xlabel('Number of Stations along Spline'); ylabel('Miss Magnitude, meters');
title('Сходимость промаха от плотности сетки'); 
legend('RMSE', 'Mean Miss', 'Max Miss', 'Location', 'northeast');

% График 2-2: Глобальная сходимость Bias Y к абсолютному нулю
subplot(2,2,4);
plot(STATION_COUNTS_VECTOR, summary.bias_y, 'm-d', 'LineWidth', 2);
grid on; xlabel('Number of Stations along Spline'); ylabel('Systemic Range Bias (Y), meters');
title('Сходимость Bias Y');
end
