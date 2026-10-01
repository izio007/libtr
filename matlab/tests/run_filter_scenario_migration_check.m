function run_filter_scenario_migration_check
setup_test_paths;
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
state=rng; cleanup=onCleanup(@() rng(state));
data=load(fullfile(root,'runtime','filter_scenario_baseline_20260930','filter2win_doc_data.mat'));
rng(1729,'twister');
[t,truth,measured,filtered,power]=filter2win_scenario;
assert(isequaln({t,truth,measured,filtered,power}, ...
    {data.t,data.truth,data.measured,data.filtered,data.power}));
unit_test_filter_scenario;
unit_test_filter_plot_path;
fprintf('Five arrays equal pre-refactor snapshot: PASS\n');
end