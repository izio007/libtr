function unit_test_lls_relocation
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','function'));
clear lls_position lls_covariance;
for name={'lls_position','lls_covariance'}
    assert(strcmpi(which(name{1}),fullfile(root,'matlab','function',[name{1} '.m'])));
    assert(numel(which(name{1},'-all'))==1);
    assert(~isfile(fullfile(root,'matlab',[name{1} '.m'])));
end
[s,x]=lls_position(zeros(3,1),0,0);
assert(s==1 && isequal(size(x),[3 1]) && all(isnan(x)));
[s,x]=lls_position(zeros(3,1),0,0,1,1);
assert(s==1 && all(isnan(x)));
[s,K]=lls_covariance(zeros(3,1),0,0,1,1,zeros(3,1));
assert(s==1 && isequal(size(K),[3 3]) && all(isnan(K(:))));
fprintf('LLS isolated resolution and short-network contracts: PASS\n');
end