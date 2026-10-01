function unit_test_ideal_relocation
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','function'),fullfile(root,'matlab','engine'));
clear service_ideal_mock_position;
assert(isempty(which('service_ideal_mock_position')));
addpath(fullfile(root,'matlab','tests','support'));
assert(strcmpi(which('service_ideal_mock_position'), ...
    fullfile(root,'matlab','tests','support','service_ideal_mock_position.m')));
assert(numel(which('service_ideal_mock_position','-all'))==1);
assert(~isfile(fullfile(root,'tools','matlab','service_ideal_mock_position.m')));
P=[-10 10 0 0;0 0 -10 10;0 0 0 0];
[s,x]=service_ideal_mock_position(P,2,3,4);
assert(s==0 && norm(x-[2;3;4])<1e-10);
[s,x]=service_ideal_mock_position(P(:,1),2,3,4);
assert(s==1 && isequal(size(x),[3 1]) && all(isnan(x)));
addpath(fullfile(root,'matlab','tests'));
unit_test_engine_isolation;
fprintf('Ideal adapter relocation and known geometry: PASS\n');
end