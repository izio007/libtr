function unit_test_pipeline_selection()
setup_test_paths;
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
request=struct('action','unit','test','unit_test_matmul3');
assert(strcmp(service_pipeline_select_test(request,root),request.test));
assert(isempty(service_pipeline_select_test(struct('action','unit'),root)));
integration=struct('action','integration','test','integration_filter2win');
assert(strcmp(service_pipeline_select_test(integration,root),integration.test));
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
% A direct dispatcher call must preserve an interactive MATLAB session.
fig=figure('Visible','off');
figureCleanup=onCleanup(@() closeOwnedFigure(fig));
ax=axes('Parent',fig); line=plot(ax,[1 2],[3 4]);
beforePath=path; beforeFolder=pwd; beforeRng=rng;
report=service_pipeline_run(request,folder);
assert(strcmp(beforePath,path) && strcmp(beforeFolder,pwd) && isequal(beforeRng,rng));
assert(isgraphics(fig) && isgraphics(line));
assert(isequal(line.XData,[1 2]) && isequal(line.YData,[3 4]));
assert(strcmp(report.state,'passed') && numel(report.stages)==1);
results=jsondecode(fileread(fullfile(folder,'unit_results.json')));
assert(isscalar(results) && strcmp(results.name,request.test));
assert(~isfile(fullfile(folder,'environment.log')));
fprintf('Targeted unit selection: PASS\n');
end

function closeOwnedFigure(fig)
if isgraphics(fig), close(fig); end
end
