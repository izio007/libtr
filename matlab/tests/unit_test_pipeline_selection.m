function unit_test_pipeline_selection()
setup_test_paths;
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
request=struct('action','unit','test','unit_test_matmul3');
assert(strcmp(service_pipeline_select_test(request,root),request.test));
assert(isempty(service_pipeline_select_test(struct('action','unit'),root)));
for name={'../unit_test_matmul3','unit_test_absent_987654321','unit_test_matmul3.m',''}
    request.test=name{1};
    rejected=false;
    try
        service_pipeline_select_test(request,root);
    catch exception
        assert(strcmp(exception.identifier,'libtr:pipeline:Test'));
        rejected=true;
    end
    assert(rejected);
end
request=struct('action','environment','test','unit_test_matmul3');
rejected=false;
try
    service_pipeline_select_test(request,root);
catch exception
    assert(strcmp(exception.identifier,'libtr:pipeline:Test'));
    rejected=true;
end
assert(rejected);
folder=tempname(fullfile(root,'runtime')); mkdir(folder);
cleanup=onCleanup(@() rmdir(folder,'s'));
request=struct('id','selection_fixture','action','unit','test','unit_test_matmul3');
report=service_pipeline_run(request,folder);
assert(strcmp(report.state,'passed') && numel(report.stages)==1);
results=jsondecode(fileread(fullfile(folder,'unit_results.json')));
assert(isscalar(results) && strcmp(results.name,request.test));
assert(~isfile(fullfile(folder,'environment.log')));
fprintf('Targeted unit selection: PASS\n');
end