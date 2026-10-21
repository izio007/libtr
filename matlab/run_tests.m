function status = run_tests(mode,selection)
% RUN_TESTS Unit tests, or selected integrations with visible figures.
% run_tests                          unit tests only
% run_tests('integration')           choose integrations; no unit tests
% run_tests('all')                   choose integrations, then run units too
% run_tests('all',{'filter2win'})     explicit selection without a dialog
% Integration IDs: filter2win, context30, context450, tis.
if nargin<1, mode='unit'; end
if isstring(mode) && isscalar(mode), mode=char(mode); end
assert(ischar(mode) && isrow(mode) && any(strcmp(mode,{'unit','integration','all'})), ...
    'libtr:tests:Mode','Mode must be unit, integration or all');
assert(~strcmp(mode,'unit') || nargin<2, ...
    'libtr:tests:Selection','Unit mode does not take an integration selection');
root=fileparts(fileparts(mfilename('fullpath')));
previous=pwd; oldpath=existingPath(path); randomState=rng;
cleanup=onCleanup(@() restore(previous,oldpath,randomState));
path(oldpath);
addpath(fullfile(root,'matlab','tests'));
setup_test_paths;
unitResults=struct('name',{},'state',{},'seconds',{},'error',{});
integrationResults=struct('name',{},'state',{},'seconds',{},'error',{},'metrics',{});
status=struct('state','not_run','output_dir','', ...
    'unit',struct('state','not_run','total',0,'failures',0,'results',unitResults), ...
    'integration',struct('state','not_run','total',0,'failures',0,'results',integrationResults));

selected={};
if ~strcmp(mode,'unit')
    names={'filter2win','context30','context450','tis'};
    if nargin<2
        labels={'filter2win: full trajectory', ...
            'TIS 30 km: 4 solvers (configured ensemble)', ...
            'TIS 450 km: 4 solvers (configured ensemble)', ...
            'TIS: 5 geometries, ensemble 64'};
        [indices,accepted]=listdlg('ListString',labels,'SelectionMode','multiple', ...
            'InitialValue',1,'Name','libtr integrations', ...
            'PromptString','Select integrations to run and display:', ...
            'ListSize',[380 120]);
        if accepted, selected=names(indices); end
    else
        if ischar(selection) || isstring(selection), selection=cellstr(selection); end
        assert(iscellstr(selection),'libtr:tests:Selection', ...
            'Integration selection must contain names');
        selected=unique(reshape(selection,1,[]),'stable');
        assert(all(ismember(selected,names)),'libtr:tests:Selection', ...
            'Integration names: filter2win, context30, context450, tis');
    end
    if isempty(selected)
        status.state='cancelled'; status.integration.state='cancelled';
        fprintf('Selection cancelled; no tests were run.\n');
        return;
    end
end

% Resolve the selection before creating files or executing any unit test.
outputRoot=fullfile(root,'runtime','matlab_tests');
if ~isfolder(outputRoot), mkdir(outputRoot); end
folder=tempname(outputRoot); mkdir(folder);
status.output_dir=folder; status.state='running';
cd(folder);
fprintf('libtr tests: %s\n',folder);
if strcmp(mode,'unit') || strcmp(mode,'all')
    status.unit=run_unit_tests(folder);
end
if ~strcmp(mode,'unit')
    for k=1:numel(selected)
        name=selected{k}; caseFolder=fullfile(folder,name); mkdir(caseFolder);
        fprintf('Integration %s...\n',name);
        % Capture output even when a calculation fails, for the case log.
        output=evalc('item=executeIntegration(name,caseFolder);');
        fid=fopen(fullfile(caseFolder,'run.log'),'w','n','UTF-8');
        assert(fid~=-1,'libtr:tests:IO','Cannot write integration log');
        closer=onCleanup(@() fclose(fid));
        fprintf(fid,'%s\n%s',output,item.error); clear closer;
        integrationResults(k)=item;
        fprintf('[%s] %s (%.2f s)\n',upper(item.state),name,item.seconds);
        if strcmp(item.state,'failed'), fprintf(2,'%s\n',item.error); end
    end
    failures=sum(strcmp({integrationResults.state},'failed'));
    state='passed'; if failures>0, state='failed'; end
    status.integration=struct('state',state,'total',numel(selected), ...
        'failures',failures,'results',integrationResults);
    service_pipeline_write_json(fullfile(folder,'integration_results.json'),integrationResults);
end
status.state='passed';
if status.unit.failures>0 || status.integration.failures>0, status.state='failed'; end
service_pipeline_write_json(fullfile(folder,'report.json'),status);
fprintf('Overall: %s. Unit: %s; integration: %s.\n', ...
    upper(status.state),status.unit.state,status.integration.state);
fprintf('Results and logs: %s\n',folder);
end

function item=executeIntegration(name,folder)
previous=pwd; oldpath=existingPath(path); randomState=rng;
cleanup=onCleanup(@() restore(previous,oldpath,randomState));
path(oldpath); cd(folder); rng(1729,'twister');
item=struct('name',name,'state','passed','seconds',0,'error','','metrics',struct());
clock=tic;
try
    switch name
        case 'filter2win'
            item.metrics=integration_filter2win(folder,true);
        case 'context30'
            item.metrics=integration_context(folder,true,1);
        case 'context450'
            item.metrics=integration_context(folder,true,2);
        case 'tis'
            item.metrics=integration_tis(folder,true);
    end
    assert(isstruct(item.metrics) && isscalar(item.metrics) && isfield(item.metrics,'failures'), ...
        'libtr:tests:IntegrationResult','Integration must return a failures count');
    validateattributes(item.metrics.failures,{'numeric'}, ...
        {'scalar','real','finite','nonnegative','integer'});
    if item.metrics.failures>0
        item.state='failed';
        item.error=sprintf('%d integration checks failed; see saved results.',item.metrics.failures);
    end
catch exception
    item.state='failed';
    item.error=getReport(exception,'extended','hyperlinks','off');
end
item.seconds=toc(clock);
end

function restore(previous,oldpath,randomState)
cd(previous); path(existingPath(oldpath)); rng(randomState);
end

function value=existingPath(value)
folders=strsplit(value,pathsep);
value=strjoin(folders(cellfun(@isfolder,folders)),pathsep);
end
