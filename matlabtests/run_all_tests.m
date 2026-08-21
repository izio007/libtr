% =========================================================================
% АВТОМАТИЗАЦИЯ ВЕРИФИКАЦИОННОГО СТЕНДА: ИЗОЛИРОВАННЫЙ РАННЕР (V5)
% Responsibility: Запуск сценариев в изолированном пространстве 'base'
% Path: d:\workspace\libtr\matlabtests\run_all_tests.m
% =========================================================================

clear; clc; close all;

matlab_dir = 'd:\workspace\libtr\matlab';
tests_dir  = 'd:\workspace\libtr\matlabtests';

addpath(matlab_dir);
addpath(tests_dir);

fprintf('=========================================================================\n');
fprintf('   ГЛОБАЛЬНЫЙ АВТОМАТИЗИРОВАННЫЙ ДИСПЕТЧЕР ТЕСТИРОВАНИЯ ПРОЕКТА [libtr]   \n');
fprintf('=========================================================================\n\n');

tasks = {'test_system_verification.m', 'test_spline_30km.m', 'test_trajectory_200km.m'};
success_count = 0;
failed_list = {};

for k_loop = 1:length(tasks)
    current_task = tasks{k_loop};
    current_path = fullfile(tests_dir, current_task);
    
    fprintf(' ЗАПУСК СЦЕНАРИЯ [%d/%d]: %s\n', k_loop, length(tasks), current_task);
    fprintf('-------------------------------------------------------------------------\n');
    
    % Защищаем контекст раннера: сбрасываем конфигурацию на диск
    save('runner_state_tmp.mat', 'tasks', 'k_loop', 'success_count', 'failed_list', 'tests_dir');
    
    try
        % Печатаем маркер начала для отделения вывода в консоли
        fprintf('--- НАЧАЛО ВЫВОДА СЦЕНАРИЯ %s ---\n', current_task);
        
        % Выполняем запуск в базовом пространстве
        evalin('base', sprintf('run(''%s'')', current_path));
        
        load('runner_state_tmp.mat');
        fprintf('--- КОНЕЦ ВЫВОДА СЦЕНАРИЯ %s ---\n', current_task);
        fprintf('\n УСПЕШНО ЗАВЕРШЕНО: %s\n', current_task);
        success_count = success_count + 1;
        
    catch error_info
        % Восстанавливаем контекст раннера в случае падения скрипта
        load('runner_state_tmp.mat');
        
        fprintf('\n КРИТИЧЕСКИЙ СБОЙ ПРИ ВЫПОЛНЕНИИ: %s\n', current_task);
        fprintf(' Текст сообщения: %s\n', error_info.message);
        fprintf('=========================================================================\n\n');
        failed_list{end+1} = current_task; %#ok<AGROW>
    end
end

% Удаляем временный файл конфигурации
if exist('runner_state_tmp.mat', 'file'), delete('runner_state_tmp.mat'); end

% Глобальное резюме
fprintf('=========================================================================\n');
fprintf('                    СВОДНЫЙ ОТЧЕТ АВТОМАТИЗАЦИИ ТЕСТОВ                   \n');
fprintf('=========================================================================\n');
fprintf(' Всего сценариев запущено : %d\n', length(tasks));
fprintf(' Успешно верифицировано   : %d\n', success_count);
fprintf(' Обнаружено отказов       : %d\n', length(failed_list));
fprintf('-------------------------------------------------------------------------\n');

if success_count == length(tasks)
    fprintf(' СТАТУС ВЕРИФИКАЦИИ: SUCCESS\n');
else
    fprintf(' СТАТУС ВЕРИФИКАЦИИ: FAILURE\n');
end
fprintf('=========================================================================\n');
