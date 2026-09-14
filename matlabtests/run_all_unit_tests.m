clear; clc; close all;
service_generate_static_context;
test_list = {'unit_test_cov2std', 'unit_test_cov2std_3d', 'unit_test_lls_position', 'unit_test_wlls_position', 'unit_test_gn_position', 'unit_test_gnp_position'};
report_file = 'unit_tests_report.txt';
fid = fopen(report_file, 'w');
if fid == -1
    error('Критический сбой ОЗУ: Невозможно создать файл отчета unit_tests_report.txt.');
end
total_tests = length(test_list);
success_count = 0;
fprintf(fid, 'СТАРТ ГЛОБАЛЬНОЙ ВЕРИФИКАЦИИ МАТЕМАТИЧЕСКИХ ЯДЕР ТИС\n');
for i = 1:total_tests
    test_name = test_list{i};
    try
        captured_output = evalc(sprintf('%s()', test_name));
        fprintf(fid, '>>> Исполняется: %s.m\n%s<<< Успешно завершен: %s\n', test_name, captured_output, test_name);
        fprintf('Исполняется: %s.m... SUCCESS\n', test_name);
        success_count = success_count + 1;
    catch ME
        fprintf(fid, '>>> Исполняется: %s.m\n❌ КРИТИЧЕСКИЙ СБОЙ В ТЕСТЕ: %s\nИсключение: %s\n', test_name, test_name, ME.message);
        fprintf('Исполняется: %s.m... ❌ FAILED\n', test_name);
        fprintf('  Предупреждение: %s\n', ME.message);
    end
end
fprintf(fid, '\nИТОГОВЫЙ ОТЧЕТ ВЕРИФИКАЦИИ\nВсего запущено тестов:  %d\nУСПЕШНО ВЫПОЛНЕНО:     %d\nЗАВЕРШИЛОСЬ АВАРИЙНО:  %d\n', total_tests, success_count, total_tests - success_count);
fclose(fid);
