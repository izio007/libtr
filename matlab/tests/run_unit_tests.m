function summary = run_unit_tests(folder,names)
% Shared unit executor for MATLAB Desktop and the optional TCP host.
% Unit figures are hidden and only newly created figures are cleaned up.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
path(existingPath(path));
if nargin<2
    files=dir(fullfile(root,'matlab','tests','unit_test_*.m'));
    names=cellfun(@(name) name(1:end-2),{files.name},'UniformOutput',false);
end
assert(~isempty(names),'libtr:tests:Empty','No unit tests selected');
results=cell(1,numel(names));
for k=1:numel(names)
    [result,output]=runOne(root,folder,names{k});
    results{k}=result;
    fid=fopen(fullfile(folder,[result.name '.log']),'w','n','UTF-8');
    assert(fid~=-1,'libtr:tests:IO','Cannot write test log');
    closer=onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n%s',output,result.error); clear closer;
    fprintf('[%s] %s (%.2f s)\n',upper(result.state),result.name,result.seconds);
    if strcmp(result.state,'failed'), fprintf(2,'%s\n',result.error); end
end
service_pipeline_write_json(fullfile(folder,'unit_results.json'),results);
items=[results{:}];
failures=sum(strcmp({items.state},'failed'));
state='passed'; if failures>0, state='failed'; end
summary=struct('state',state,'total',numel(items),'failures',failures,'results',items);
fprintf('Unit: %d passed, %d failed.\n',summary.total-failures,failures);
end

function [result,output]=runOne(root,folder,name)
previous=pwd; oldpath=existingPath(path); randomState=rng;
visibility=get(groot,'DefaultFigureVisible');
figuresBefore=findall(groot,'Type','figure');
cleanup=onCleanup(@() restore(previous,oldpath,randomState,visibility,figuresBefore));
path(oldpath);
set(groot,'DefaultFigureVisible','off');
addpath(fullfile(root,'matlab','tests'));
setup_test_paths;
cd(folder); rng(1729,'twister');
% Catch inside evalc so output printed before a failed assertion is retained.
output=evalc('result=executeTest(name);');
end

function result=executeTest(name)
result=struct('name',name,'state','passed','seconds',0,'error','');
clock=tic;
try
    feval(name);
catch exception
    result.state='failed';
    result.error=getReport(exception,'extended','hyperlinks','off');
end
result.seconds=toc(clock);
end

function restore(previous,oldpath,randomState,visibility,figuresBefore)
cd(previous); path(existingPath(oldpath)); rng(randomState);
set(groot,'DefaultFigureVisible',visibility);
figuresNow=findall(groot,'Type','figure');
for k=1:numel(figuresNow)
    if ~any(figuresNow(k)==figuresBefore), delete(figuresNow(k)); end
end
end

function value=existingPath(value)
folders=strsplit(value,pathsep);
value=strjoin(folders(cellfun(@isfolder,folders)),pathsep);
end
