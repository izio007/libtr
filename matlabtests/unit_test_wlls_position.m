function unit_test_wlls_position(fid)
% RADAR AUTOMATIC VERIFICATION: ATOMIC TEST WRAPPER FOR WEIGHTED LLS
    if nargin < 1, fid = 1; end
    fprintf(fid, 'ЗАПУСК АТОМАРНОГО ЮНИТ-ТЕСТА ДЛЯ ФУНКЦИИ: wlls_position\n');
    service_run_multi_criteria_bench(fid, @wlls_position, @wlls_covariance, 'WLLS');
    fprintf(fid, '<<< Успешно завершен: unit_test_wlls_position\n\n');
end
