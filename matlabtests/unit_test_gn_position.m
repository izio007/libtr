function unit_test_gn_position(fid)
% RADAR AUTOMATIC VERIFICATION: ATOMIC TEST WRAPPER FOR DECARTE GN
    if nargin < 1, fid = 1; end
    fprintf(fid, 'ЗАПУСК АТОМАРНОГО ЮНИТ-ТЕСТА ДЛЯ ФУНКЦИИ: gn_position\n');
    service_run_multi_criteria_bench(fid, @gn_position, @gn_covariance, 'GN_Cartesian');
    fprintf(fid, '<<< Успешно завершен: unit_test_gn_position\n\n');
end
