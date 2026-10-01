function unit_test_production_isolation
% Production dependency closure must not include development infrastructure.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','function'),fullfile(root,'matlab','engine'));
assert(isempty(which('mock_position')) && isempty(which('mock_covariance')));
assert(isempty(which('setup_test_paths')));
files=[dir(fullfile(root,'matlab','engine','*.m')); ...
    dir(fullfile(root,'matlab','function','*.m'))];
assert(~isempty(files));
for k=1:numel(files)
    file=fullfile(files(k).folder,files(k).name);
    [~,name]=fileparts(file);
    assert(strcmpi(which(name),file) && numel(which(name,'-all'))==1, ...
        'libtr:isolation:Resolution','Ambiguous production function: %s',file);
    text=fileread(file);
    assert(isempty(regexpi(text, ...
        'matlabtests|matlab[/\\]tests|\b(addpath|rmpath|eval|evalin|feval|str2func|fopen|fprintf|save|load|figure|global)\b','once')), ...
        'libtr:isolation:Source','Forbidden dependency or side effect: %s',file);
    if strcmp(files(k).folder,fullfile(root,'matlab','function'))
        assert(isempty(regexp(text,'\b(randn|rng)\b','once')));
    end
    dependencies=matlab.codetools.requiredFilesAndProducts(file);
    for j=1:numel(dependencies)
        dependency=dependencies{j};
        if startsWith(dependency,[root filesep])
            assert(strcmp(fileparts(dependency),fullfile(root,'matlab','engine')) || ...
                strcmp(fileparts(dependency),fullfile(root,'matlab','function')), ...
                'libtr:isolation:Dependency','Forbidden dependency: %s',dependency);
        end
    end
end
P=[1 2;3 4;5 6]; a=[7;8]; b=[9;10];
state=rng;
[actual,va,vb]=service_expand_tact_matrix(P,a,b,5);
assert(isequal(actual,P(:,[1 2 1 2 1])));
assert(isequal(va,a([1 2 1 2 1])) && isequal(vb,b([1 2 1 2 1])));
assert(isequal(rng,state));
[again,aa,bb]=service_expand_tact_matrix(P,a,b,5);
assert(isequal(actual,again) && isequal(va,aa) && isequal(vb,bb));
fprintf('Production dependency closure (%d files) and deterministic expansion: PASS\n',numel(files));
end