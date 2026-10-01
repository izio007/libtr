function unit_test_cov2std_reporting
% @CRITERION COV-REPORT-001: report states actual tolerance, not bit equality.
setup_test_paths;
clear unit_test_cov2std unit_test_cov2std_3d;
for name={'unit_test_cov2std','unit_test_cov2std_3d'}
    text=evalc('feval(name{1});');
    assert(contains(text,'|q - 1| <= 1.0e-10'));
    assert(~contains(lower(text),'побитов'));
end
fprintf('Covariance geometry reporting and both numerical checks: PASS\n');
end