function unit_test_mock_runner_path
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','tests'));
clear setup_test_paths run_mock_traceability;
before=path;
folder=tempname(fullfile(root,'runtime'));
report=run_mock_traceability(folder);
assert(report.passed && numel(report.tests)==2);
assert(strcmp(before,path));
file=fullfile(folder,'report.json'); text=fileread(file);
assert(isfile(fullfile(folder,'mock_spectrum.png')));
rejected=false;
try
    run_mock_traceability(folder);
catch exception
    rejected=strcmp(exception.identifier,'libtr:trace:Exists');
end
assert(rejected && strcmp(before,path) && strcmp(text,fileread(file)));
fprintf('Mock runner path restoration and output protection: PASS; %s\n',folder);
end