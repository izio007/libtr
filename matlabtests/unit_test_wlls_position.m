function unit_test_wlls_position(fid)
% RADAR AUTOMATIC VERIFICATION: ATOMIC TEST WRAPPER FOR WEIGHTED LLS
    if nargin < 1, fid = 1; end
    fprintf(fid, 'ЗАПУСК АТОМАРНОГО ЮНИТ-ТЕСТА ДЛЯ ФУНКЦИИ: wlls_position\n');
    assert_position_contract(@wlls_position);
    fprintf(fid, '<<< Успешно завершен: unit_test_wlls_position\n\n');
end
