function service_pipeline_reset(root)
% Dedicated test process: transport lives in function workspaces, not base.
evalin('base','clearvars');
clear global;
close all force;
clear functions;
restoredefaultpath;
addpath(fullfile(root,'tools','pipeline'),fullfile(root,'matlab','tests'));
rehash path;
setup_test_paths;
rng(1729,'twister');
end