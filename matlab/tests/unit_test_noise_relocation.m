function unit_test_noise_relocation
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','function'),fullfile(root,'matlab','engine'));
clear service_add_noise_ox;
assert(~isempty(which('service_add_noise_ox')));
addpath(fullfile(root,'matlab','engine'),fullfile(root,'matlab','tests'));
assert(strcmpi(which('service_add_noise_ox'),fullfile(root,'matlab','engine','service_add_noise_ox.m')));
assert(numel(which('service_add_noise_ox','-all'))==1);
assert(~isfile(fullfile(root,'matlab','tests','support','service_add_noise_ox.m')));
unit_test_noise_contract;
fprintf('Noise relocation and independent axis checks: PASS\n');
end