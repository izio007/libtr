function unit_test_wlls_relocation
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','function'));
clear wlls_position wlls_covariance lls_position;
for name={'wlls_position','wlls_covariance','lls_position'}
    assert(strcmpi(which(name{1}),fullfile(root,'matlab','function',[name{1} '.m'])));
    assert(numel(which(name{1},'-all'))==1);
    assert(~isfile(fullfile(root,'matlab',[name{1} '.m'])));
end
P=[1 -1 0 0;0 0 1 -1;0 0 0 0];
a=[pi;0;-pi/2;pi/2]; b=zeros(4,1); v=ones(4,1);
[s,x]=wlls_position(P,a,b,v,v);
assert(s==0 && norm(x,inf)<1e-12);
[s,K]=wlls_covariance(P,a,b,v,v,zeros(3,1));
assert(s==0 && norm(K-diag([0.5 0.5 0.25]),'fro')<1e-12);
[s,x]=wlls_position(zeros(3,1),0,0,1,1);
assert(s==1 && isequal(size(x),[3 1]) && all(isnan(x)));
[s,K]=wlls_covariance(zeros(3,1),0,0,1,1,zeros(3,1));
assert(s==1 && isequal(size(K),[3 3]) && all(isnan(K(:))));
fprintf('WLLS isolated path, geometric oracle and refusals: PASS\n');
end