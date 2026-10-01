function unit_test_relocation_suite
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','tests'));
clear setup_test_paths run_service_relocation_checks;
before=path; directory=pwd;
folder=tempname(fullfile(root,'runtime'));
report=run_service_relocation_checks(folder);
assert(report.passed && numel(report.tests)==9);
assert(strcmp(before,path) && strcmp(directory,pwd));
names=cellfun(@(item)item.name,report.tests,'UniformOutput',false);
assert(numel(unique(names))==9);
for k=1:numel(names)
    assert(isfile(fullfile(folder,[names{k} '.log'])));
end
file=fullfile(folder,'report.json'); text=fileread(file);
saved=jsondecode(text);
assert(saved.passed && numel(saved.tests)==9 && all([saved.tests.passed]));
rejected=false;
try
    run_service_relocation_checks(folder);
catch
    rejected=true;
end
assert(rejected && strcmp(text,fileread(file)) && strcmp(before,path));
fprintf('Relocation suite: 9/9, report and path checks PASS; %s\n',folder);
end