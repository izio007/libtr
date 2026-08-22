function run_all_unit_tests()
% =========================================================================
% МАСТЕР-РАННЕР С АВТОМАТИЧЕСКОЙ ЗАПИСЬЮ ВСЕГО ВЫВОДА ТИС В ЛОГ-ФАЙЛ
% Responsibility: Чистый диспетчер перебора с фиксацией отчета на диске
% Path: d:\workspace\libtr\matlabtests\run_all_unit_tests.m
% =========================================================================

clc; close all;

% 1. Определение директорий и инжекция путей
tests_dir = fileparts(mfilename('fullpath'));
if isempty(tests_dir), tests_dir = pwd; end
[project_root, ~] = fileparts(tests_dir);
matlab_core_dir = fullfile(project_root, 'matlab');

addpath(matlab_core_dir);
addpath(tests_dir);

% 2. Конфигурация и запуск файла записи отчета
log_file_path = fullfile(tests_dir, 'unit_tests_report.txt');
if exist(log_file_path, 'file')
    delete(log_file_path); % Удаляем старый лог перед новым прогоном
end

diary(log_file_path); % Включаем сквозную запись вывода в файл

fprintf('СТАРТ ГЛОБАЛЬНОЙ ВЕРИФИКАЦИИ МАТЕМАТИЧЕСКИХ ЯДЕР ТИС\n');

search_pattern = fullfile(tests_dir, 'unit_test_*.m');
test_files = dir(search_pattern);

if isempty(test_files)
    fprintf('⚠️ Ошибка: Юнит-тесты unit_test_*.m не обнаружены.\n');
    diary off; % Выключаем запись перед выходом
    return;
end

total_tests = length(test_files);
success_count = 0;
failed_tests = cell(0, 1);

for idx = 1:total_tests
    current_file_name = test_files(idx).name;
    [~, func_name, ~] = fileparts(current_file_name);
    
    fprintf('>>> Исполняется: %s\n', current_file_name);
    
    try
        test_func_handle = str2func(func_name);
        test_func_handle(); 
        
        success_count = success_count + 1;
        fprintf('<<< Успешно завершен: %s\n', func_name);
    catch ME
        failed_tests{end+1, 1} = current_file_name; %#ok<AGROW>
        fprintf('❌ КРИТИЧЕСКИЙ СБОЙ при выполнении %s!\n', current_file_name);
        fprintf('Сообщение: %s\n', ME.message);
    end
end

fprintf('\nИТОГОВЫЙ ОТЧЕТ ВЕРИФИКАЦИИ\n');
fprintf('Всего запущено тестов:  %d\n', total_tests);
fprintf('Успешно выполнено:     %d\n', success_count);
fprintf('Завершилось аварийно:  %d\n', total_tests - success_count);

diary off; % Выключаем запись и закрываем дескриптор файла на диске
fprintf('Вывод верификации ТИС успешно сохранен в файл: %s\n', log_file_path);
end
