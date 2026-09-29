function unit_test_production_isolation
% Production dependency closure must not include development infrastructure.
root=fileparts(fileparts(mfilename('fullpath')));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab'),fullfile(root,'matlab','engine'));
files=dir(fullfile(root,'matlab','engine','*.m'));
assert(~isempty(files));
for k=1:numel(files)
    file=fullfile(files(k).folder,files(k).name);
    text=fileread(file);
    assert(isempty(regexpi(text, ...
        'matlabtests|\b(addpath|rmpath|eval|evalin|feval|str2func|fopen|fprintf|save|load|figure|randn|rng|global)\b','once')), ...
        'libtr:isolation:Source','Forbidden dependency or side effect: %s',file);
    dependencies=matlab.codetools.requiredFilesAndProducts(file);
    for j=1:numel(dependencies)
        dependency=dependencies{j};
        if startsWith(dependency,[root filesep])
            assert(startsWith(dependency,fullfile(root,'matlab','engine')) || ...
                strcmp(fileparts(dependency),fullfile(root,'matlab')), ...
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
fprintf('Production dependency closure and deterministic expansion: PASS\n');
end