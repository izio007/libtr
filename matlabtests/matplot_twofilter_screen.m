function matplot_twofilter_screen(t_axes, X_true, X_meas, X_filtered_history, W_alt_power_history)
% PLOT_TIS_RESULTS Функция визуализации результатов двухоконной фильтрации ТИС
% Изолирована от математических расчетов.

    figure('Name', 'ФИНАЛЬНЫЙ АВТОМАТ ТИС', 'NumberTitle', 'off');
    
    % --- РИСУНОК 1. График траекторий ---
    subplot(2,1,1); 
    plot(t_axes, X_true, 'k-', 'LineWidth', 2); 
    hold on;
    
    t_meas_axes = t_axes(~isnan(X_meas)); 
    X_meas_valid = X_meas(~isnan(X_meas));
    
    plot(t_meas_axes, X_meas_valid, 'r.', 'MarkerSize', 10); 
    plot(t_axes, X_filtered_history, 'g-', 'LineWidth', 2);
    
    grid on; 
    title('РИСУНОК 1. ТРАЕКТОРИЯ И ДВУХОКОННЫЙ ФИЛЬТР КООРДИНАТНЫХ АНОМАЛИЙ ТИС');
    xlabel('Время t, с'); 
    ylabel('Координата X, км');
    legend('Истинный курс', 'Отметки датчика', 'Выход фильтра', 'Location', 'best');

    % --- РИСУНОК 2. Мощность альтернативного окна ---
    subplot(2,1,2); 
    plot(t_axes, W_alt_power_history, 'b-', 'LineWidth', 2); 
    grid on;
    
    title('РИСУНОК 2. АКТИВНОСТЬ ВТОРОГО ОКНА С УЧЕТОМ ТАЙМАУТА 70С');
    xlabel('Время t, с'); 
    ylabel('Кол. |W_{alt}|'); 
    ylim([-0.5, max(W_alt_power_history) + 5]);
end
