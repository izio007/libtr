function unit_test_lls_position(fid)
% RADAR AUTOMATIC VERIFICATION: ATOMIC TEST WRAPPER FOR LINEAR LLS
    if nargin < 1, fid = 1; end
    fprintf(fid, 'ЗАПУСК АТОМАРНОГО ЮНИТ-ТЕСТА ДЛЯ ФУНКЦИИ: lls_position\n');
    service_run_multi_criteria_bench(fid, @lls_position, @lls_covariance, 'LLS');
    fprintf(fid, '<<< Успешно завершен: unit_test_lls_position\n\n');
end
