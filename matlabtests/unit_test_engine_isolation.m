function unit_test_engine_isolation
setup_test_paths;
% Common adapter works without scenario functions on the search path.
root=fileparts(fileparts(mfilename('fullpath')));
old=path; cleanup=onCleanup(@() path(old));
rmpath(fullfile(root,'matlabtests'));
P=[-20000 20000 0 0;0 0 -20000 20000;200 200 200 200];
targets=[0 0 -20000+1e-4;160000 450000 0;10000 10000 1200];
for k=1:size(targets,2)
    x=targets(:,k); d=x-P;
    a=atan2(d(2,:),d(1,:)).'; b=atan2(d(3,:),hypot(d(1,:),d(2,:))).';
    [s,reference]=mock_position(P,a,b,ones(4,1),ones(4,1));
    [actual,result]=service_ideal_mock_position(P,x(1),x(2),x(3));
    assert(actual==s && isequaln(reference,result));
    assert(actual==0 && norm(result-x)<1e-3);
end
[s,x]=service_ideal_mock_position(P(:,1),0,1000,1000);
assert(s==1 && all(isnan(x)));
[s,x]=service_ideal_mock_position(zeros(3,4),1000,1000,1000);
assert(s==2 && all(isnan(x)));
fprintf('Engine isolation and unclipped ideal adapter: PASS\n');
end