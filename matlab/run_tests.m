function status = run_tests
% RUN_TESTS Run unit checks in this MATLAB session, then open filter plots.
% From the repository root: addpath('matlab'); status = run_tests;
% status.unit.results contains every unit result; status.state is the total.
root=fileparts(fileparts(mfilename('fullpath')));
previous=pwd; oldpath=path; randomState=rng;
cleanup=onCleanup(@() restore(previous,oldpath,randomState));
addpath(fullfile(root,'matlab','tests'));
setup_test_paths;
outputRoot=fullfile(root,'runtime','matlab_tests');
if ~isfolder(outputRoot), mkdir(outputRoot); end
folder=tempname(outputRoot); mkdir(folder);
cd(folder);
fprintf('libtr tests: %s\n',folder);
status=struct('state','running','output_dir',folder,'unit',struct(), ...
    'plots',struct('name',{},'state',{},'seconds',{},'error',{}));
status.unit=run_unit_tests(folder);

% Short, existing examples only. Monte Carlo studies are separate runs.
demos={@demo_filter2win,@generate_filter2win_doc_images};
for k=1:numel(demos)
    name=func2str(demos{k});
    plotFolder=fullfile(folder,name); mkdir(plotFolder);
    item=struct('name',name,'state','passed','seconds',0,'error','');
    clock=tic;
    try
        feval(demos{k},plotFolder,true);
    catch exception
        item.state='failed';
        item.error=getReport(exception,'extended','hyperlinks','off');
        fprintf(2,'%s\n',item.error);
    end
    item.seconds=toc(clock);
    status.plots(k)=item;
    fprintf('[%s] %s (%.2f s)\n',upper(item.state),name,item.seconds);
end
if status.unit.failures==0 && all(strcmp({status.plots.state},'passed'))
    status.state='passed';
else
    status.state='failed';
end
service_pipeline_write_json(fullfile(folder,'report.json'),status);
fprintf('Overall: %s. Unit: %d passed, %d failed.\n', ...
    upper(status.state),status.unit.total-status.unit.failures,status.unit.failures);
fprintf('Results and logs: %s\n',folder);
end

function restore(previous,oldpath,randomState)
cd(previous); path(oldpath); rng(randomState);
end
