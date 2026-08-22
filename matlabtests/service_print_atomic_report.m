function service_print_atomic_report(criteria_idx, range_steps, rmse_results, crlb_results, mock_delta, labelName)
% =========================================================================
% СЛУЖЕБНЫЙ МОДУЛЬ ПЕЧАТИ ТАБЛИЦ ТИС С ФИКСАЦИЕЙ ЗОН ПРИМЕНИМОСТИ МАТЕМАТИКИ
% Path: d:\workspace\libtr\matlabtests\service_print_atomic_report.m
% =========================================================================

names_map = {'ЦЕЛЬ ВНУТРИ БАЗОВОГО КВАДРАТА СДВИГ Z', ...
             'ЦЕЛЬ СНАРУЖИ В КВАДРАНТАХ ПО ДАЛЬНОСТИ', ...
             'ИЗМЕРИТЕЛЬНАЯ ДВОЙКА СТАНЦИЙ (М=2)', ...
             'ЭКСТРЕМАЛЬНАЯ ВЫСОТА ЦЕЛИ Z = 0', ...
             'МНОГОКРАТНЫЕ ТАКТЫ НАКОПЛЕНИЯ С ПОСТОВ'};
         
fprintf('Структура ТИС: %s\n', names_map{criteria_idx});
fprintf('%-15s | %-20s | %-18s | %-20s | %-10s\n', 'Дальность, км', sprintf('RMSE %s, метров', labelName), 'Репер CRLB, метров', 'Mock Delta, мм', 'Статус ТИС');

for r_idx = 1:8
    status_str = 'OK';
    if isnan(rmse_results(r_idx))
        status_str = 'CRASH_NaN';
    elseif rmse_results(r_idx) > 3 * crlb_results(r_idx) || crlb_results(r_idx) > 50000
        status_str = '*WARN*'; 
    end
    
    % Динамическое форматирование шага для циклической проверки квадрантов ТИС
    if criteria_idx == 2
        q_num = mod(r_idx - 1, 4) + 1;
        dist_str = sprintf('%.1f (Q%d)', range_steps(r_idx)/1000, q_num);
    else
        dist_str = sprintf('%.1f', range_steps(r_idx)/1000);
    end
    
    fprintf('%-15s | %-20.1f | %-18.1f | %-20.4e | %-10s\n', ...
        dist_str, rmse_results(r_idx), crlb_results(r_idx), mock_delta(r_idx), status_str);
end
fprintf('\n');
end
