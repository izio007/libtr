function unit_test_metrics_relocation
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','function'),fullfile(root,'matlab','engine'));
clear service_ensemble_metrics service_cumulative_rmse;
assert(isempty(which('service_ensemble_metrics')) && isempty(which('service_cumulative_rmse')));
addpath(fullfile(root,'matlab','tests','support'));
for name={'service_ensemble_metrics','service_cumulative_rmse'}
    assert(strcmpi(which(name{1}),fullfile(root,'matlab','tests','support',[name{1} '.m'])));
    assert(numel(which(name{1},'-all'))==1);
    assert(~isfile(fullfile(root,'tools','matlab',[name{1} '.m'])));
end
m=service_ensemble_metrics([zeros(3,1) [3;4;0] NaN(3,1)],[0 0 2],zeros(3,1));
assert(isequal(m.bias,[1.5;2;0]) && abs(m.rmse-sqrt(12.5))<1e-14);
assert(isequal(m.covariance,[4.5 6 0;6 8 0;0 0 0]));
assert(m.successful==2 && abs(m.failure_fraction-1/3)<1e-15);
r=service_cumulative_rmse([NaN(3,1) [3;4;0] NaN(3,1) zeros(3,1)], ...
    [2 0 2 0],zeros(3,1));
assert(isequal(r.successful,[0 1 1 2]));
assert(isnan(r.rmse(1)) && r.rmse(2)==5 && r.rmse(3)==5);
assert(abs(r.rmse(4)-sqrt(12.5))<1e-14 && isnan(r.plot_rmse(3)));
addpath(fullfile(root,'matlab','tests')); setup_test_paths;
unit_test_ensemble_metrics;
unit_test_graphical_experiments;
unit_test_integration_independence;
fprintf('Metrics relocation, independent moments and three regressions: PASS\n');
end