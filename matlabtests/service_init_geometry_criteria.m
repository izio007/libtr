function DataContext = service_init_geometry_criteria(contextFileName)
% CORE ENGINE: UNIFIED DATA CONTEXT DISPATCHER (LEGACY UNIT TESTS ALIGNMENT)
% PATH: f:\sy\workspace\libtr\matlab\service_init_geometry_criteria.m

    if nargin < 1
        contextFileName = 'context_unit_geometry.mat';
    end

    % Нативно маршрутизируем вызов в зависимости от затребованного юнит-тестами MAT-файла
    if contains(contextFileName, '30km')
        DataContext = service_init_geometry_30km(contextFileName);
    elseif contains(contextFileName, '450km')
        DataContext = service_init_geometry_450km(contextFileName);
    else
        % Дефолтный бесшумный верификационный полигон 5 структур для unit-тестов
        DataContext = service_init_geometry_unit(contextFileName);
    end
end
