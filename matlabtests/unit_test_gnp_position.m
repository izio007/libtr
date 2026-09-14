function unit_test_gnp_position(fid)
% RADAR AUTOMATIC VERIFICATION: ATOMIC TEST WRAPPER FOR POLAR INVARIANT GNP
    if nargin < 1, fid = 1; end
    fprintf(fid, 'ЗАПУСК АТОМАРНОГО ЮНИТ-ТЕСТА ДЛЯ ФУНКЦИИ: gnp_position\n');
    service_run_multi_criteria_bench(fid, @gnp_position, @gnp_covariance, 'GN_Polar');
    fprintf(fid, '<<< Успешно завершен: unit_test_gnp_position\n\n');
end
