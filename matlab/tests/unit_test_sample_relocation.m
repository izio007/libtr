function unit_test_sample_relocation
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; state=rng; cleanup=onCleanup(@() restore(old,state));
restoredefaultpath;
addpath(fullfile(root,'matlab','function'),fullfile(root,'matlab','engine'));
clear service_sample_bearings;
assert(~isempty(which('service_sample_bearings')));
addpath(fullfile(root,'matlab','engine'));
assert(strcmpi(which('service_sample_bearings'),fullfile(root,'matlab','engine','service_sample_bearings.m')));
assert(numel(which('service_sample_bearings','-all'))==1);
assert(~isfile(fullfile(root,'matlab','tests','support','service_sample_bearings.m')));
rng(812,'twister'); na=randn(4,5); nb=randn(4,5);
rng(812,'twister');
[P,a,b,v]=service_sample_bearings([-1 0;0 -1;0 0],zeros(3,1),0.1,2,5,engine_rng_init(812));
assert(isequal(P,[-1 0 -1 0;0 -1 0 -1;0 0 0 0]));
assert(isequal(a,[0;pi/2;0;pi/2]+0.1*na) && isequal(b,0.1*nb));
assert(isequal(v,repmat(0.1^2,4,1)));
addpath(fullfile(root,'matlab','tests'));
setup_test_paths;
unit_test_graphical_experiments;
file=[tempname(fullfile(root,'runtime')) '.mat'];
record=tis_experiment_cell([-5000 5000 0 0;0 0 -5000 5000;0 0 0 0], ...
    [1000;30000;3000],0.001,1,8,file);
data=load(file);
assert(isequal(size(data.alpha),[4 8]) && numel(data.results)==4);
assert(all(record.violations==0));
fprintf('Sampling relocation, geometric inputs and scenario smoke: PASS; %s\n',file);
end

function restore(old,state)
path(old); rng(state);
end