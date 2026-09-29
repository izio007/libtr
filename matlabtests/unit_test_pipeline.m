function unit_test_pipeline()
setup_test_paths;
% Direct dispatcher regression without a second TCP server or recursion.
root=fileparts(fileparts(mfilename('fullpath')));
folder=tempname(fullfile(root,'runtime'));
mkdir(folder);
cleanup=onCleanup(@() rmdir(folder,'s'));
request=struct('id','regression','action','environment');
previous=pwd; state=rng;
report=service_pipeline_run(request,folder);
assert(strcmp(report.state,'passed'));
assert(strcmp(pwd,previous) && isequal(rng,state));
assert(isfile(fullfile(folder,'engine_context.mat')));
fid=fopen(fullfile(folder,'cancel'),'w'); fclose(fid);
report=service_pipeline_run(request,folder);
assert(strcmp(report.state,'cancelled'));
delete(fullfile(folder,'cancel'));
request.action='invalid';
report=service_pipeline_run(request,folder);
assert(strcmp(report.state,'failed'));
assert(contains(report.stages{1}.error,'Unknown stage'));
fprintf('Pipeline dispatcher regression: SUCCESS\n');
end