function unit_test_model_lifecycle
setup_test_paths;
P=[-10 10 0 0;0 0 -10 10;0 0 0 0]; truth=[2;3;4];
d=truth-P; a=atan2(d(2,:),d(1,:)).'; b=atan2(d(3,:),hypot(d(1,:),d(2,:))).';
a=repmat(a,1,3); b=repmat(b,1,3); v=ones(4,1)*1e-6;
for solver={@lls_position,@wlls_position,@gn_position,@gnp_position}
    m=test_model_init(solver{1},P,a,b,v,v,truth);
    other=m;
    expectError(@() test_model_result(m),'libtr:testmodel:Incomplete');
    m=test_model_step(m); checkpoint=m;
    assert(other.cursor==0 && all(isnan(other.result.samples(:))));
    m=test_model_step(m); m=test_model_step(m);
    checkpoint=test_model_step(checkpoint); checkpoint=test_model_step(checkpoint);
    r=test_model_result(m);
    assert(isequaln(r,test_model_result(checkpoint)));
    assert(isequaln(r,service_run_ensemble(solver{1},P,a,b,v,v,truth)));
    for j=1:3
        [s,x]=solver{1}(P,a(:,j),b(:,j),v,v);
        assert(r.statuses(j)==s && isequaln(r.samples(:,j),x));
    end
    expectError(@() test_model_step(m),'libtr:testmodel:Complete');
end
% Exception at first observation must not stop subsequent execution.
a(1,:)=[-1 0 1];
m=test_model_init(@injected,P,a,b,v,v,truth);
for j=1:3, m=test_model_step(m); end
r=test_model_result(m);
assert(r.contract_violations(1) && ~isempty(r.errors{1}));
assert(isequal(r.statuses(2:3),[2 0]) && ~any(r.contract_violations(2:3)));
assert(r.metrics.successful==1);
try
    test_model_init(@injected,P,a,b,ones(3,1),v,truth);
    error('libtr:test:MissingValidation','Expected invalid dimensions');
catch e
    assert(~strcmp(e.identifier,'libtr:test:MissingValidation'));
end
unit_test_ensemble_metrics;
unit_test_integration_independence;
fprintf('Explicit test model lifecycle, four solvers and regressions: PASS\n');
end
function [s,x]=injected(~,a,varargin)
if a(1)<0, error('libtr:test:Injected','Intentional failure'); end
if a(1)==0, s=2; x=NaN(3,1); else, s=0; x=[2;3;4]; end
end
function expectError(action,id)
try
    action();
catch e
    assert(strcmp(e.identifier,id)); return;
end
error('libtr:test:MissingError','Expected %s',id);
end