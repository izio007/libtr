function unit_test_test_paths
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','tests'));
clear setup_test_paths;
setup_test_paths;
assert(~any(strcmpi(strsplit(path,pathsep),fullfile(root,'matlab'))));
first=path; setup_test_paths; assert(strcmp(first,path));
folders={fullfile(root,'matlab','function'),fullfile(root,'matlab','engine'), ...
    fullfile(root,'matlab','tests','support')};
for k=1:numel(folders)
    files=dir(fullfile(folders{k},'*.m'));
    assert(~isempty(files));
    for j=1:numel(files)
        [~,name]=fileparts(files(j).name);
        assert(strcmpi(which(name),fullfile(folders{k},files(j).name)));
        assert(numel(which(name,'-all'))==1);
    end
end
unit_test_engine_isolation;
unit_test_integration_independence;
unit_test_ensemble_metrics;
unit_test_graphical_experiments;
fprintf('Clean test composition and four consumer regressions: PASS\n');
end