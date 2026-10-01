function unit_test_mock_relocation
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab'),fullfile(root,'matlab','function'),fullfile(root,'matlab','engine'));
clear mock_position mock_covariance;
assert(isempty(which('mock_position')) && isempty(which('mock_covariance')));
addpath(fullfile(root,'matlab','tests','support'));
for name={'mock_position','mock_covariance'}
    assert(strcmpi(which(name{1}),fullfile(root,'matlab','tests','support',[name{1} '.m'])));
    assert(numel(which(name{1},'-all'))==1);
    assert(~isfile(fullfile(root,'matlab',[name{1} '.m'])));
end
P=[1 -1 0 0;0 0 1 -1;0 0 0 0];
a=[pi;0;-pi/2;pi/2]; b=zeros(4,1); v=ones(4,1);
[s,x]=mock_position(P,a,b,v,v);
assert(s==0 && norm(x,inf)<1e-12);
[s,K,V,S]=mock_covariance(P,a,b,v,v,zeros(3,1));
assert(s==0 && norm(K-diag([0.5 0.5 0.25]),'fro')<1e-12);
assert(norm(V*S*V.'-K,'fro')<1e-12 && norm(V.'*V-eye(3),'fro')<1e-12);
fprintf('Mock test-only resolution and independent diagonal oracle: PASS\n');
end