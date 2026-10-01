function unit_test_gn_relocation
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','function'));
clear gn_position gn_covariance gnp_position gnp_covariance lls_position;
for name={'gn_position','gn_covariance','gnp_position','gnp_covariance','lls_position'}
    assert(strcmpi(which(name{1}),fullfile(root,'matlab','function',[name{1} '.m'])));
    assert(numel(which(name{1},'-all'))==1);
    assert(~isfile(fullfile(root,'matlab',[name{1} '.m'])));
end
P=[1 -1 0 0;0 0 1 -1;0 0 0 0]; truth=[2;3;1]; d=truth-P;
a=atan2(d(2,:),d(1,:)).';
b=atan2(d(3,:),hypot(d(1,:),d(2,:))).'; v=ones(4,1);
for solver={@gn_position,@gnp_position}
    [s,x]=solver{1}(P,a,b,v,v);
    assert(s==0 && norm(x-truth,inf)<1e-8);
    [s,x]=solver{1}(zeros(3,1),0,0,1,1);
    assert(s==1 && isequal(size(x),[3 1]) && all(isnan(x)));
end
for solver={@gn_covariance,@gnp_covariance}
    [s,K]=solver{1}(zeros(3,1),0,0,1,1,zeros(3,1));
    assert(s==1 && isequal(size(K),[3 3]) && all(isnan(K(:))));
end
fprintf('GN/GNP isolated path, noiseless truth and refusals: PASS\n');
end