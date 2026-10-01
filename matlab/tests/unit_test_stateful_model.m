function unit_test_stateful_model
setup_test_paths;
clear test_model_step test_model_result test_stateful_init test_state_validate;
time=[0 0.2 0.7 1 2 3]; P=zeros(3,2); a=zeros(2,6); v=ones(2,1);
m=test_stateful_init(@step,struct('count',0),time,P,a,a,v,v,zeros(3,6));
other=m;
expected=[1 2 2 2 2 3];
for j=1:6
    m=test_model_step(m);
    assert(m.algorithm_state.count==expected(j) && m.current_time==time(j));
    assert(other.cursor==0 && other.algorithm_state.count==0);
    if j==2, checkpoint=m; end
end
for j=3:6, checkpoint=test_model_step(checkpoint); end
r=test_model_result(m); q=test_model_result(checkpoint);
assert(isequaln(r.samples,q.samples) && isequaln(r.statuses,q.statuses));
assert(isequal(m.algorithm_state,checkpoint.algorithm_state));
assert(isequal(r.contract_violations,[false false true true true false]));
assert(r.statuses(2)==2 && all(isnan(r.samples(:,2))));
assert(~isempty(r.errors{3}) && ~isempty(r.errors{5}));
try
    test_stateful_init(@step,struct('nested',{{@sin}}),time,P,a,a,v,v,zeros(3,6));
    error('libtr:test:MissingError','Invalid state accepted');
catch e
    assert(strcmp(e.identifier,'libtr:testmodel:State'));
end
unit_test_trajectory_model;
fprintf('Stateful execution, commit rules and previous lifecycles: PASS\n');
end
function [status,x,next]=step(state,frame)
assert(~isfield(frame,'truth') && isequal(frame.P,zeros(3,2)));
assert(isequal(size(frame.alpha),[2 1]));
times=[0 0.2 0.7 1 2 3]; assert(frame.time==times(frame.index));
next=state; next.count=next.count+1; status=0; x=ones(3,1)*next.count;
switch frame.index
    case 2, status=2; x=NaN(3,1);
    case 3, error('libtr:test:Injected','Intentional exception');
    case 4, x=NaN(3,1);
    case 5, next=@sin;
end
end