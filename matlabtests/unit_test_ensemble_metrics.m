function unit_test_ensemble_metrics
% Independent exact moments, failure accounting, and exception injection.
X=[1 3 5;2 2 2;0 0 0]; truth=[1;2;0];
m=service_ensemble_metrics(X,[0 0 0],truth);
assert(isequal(m.bias,[2;0;0]));
assert(abs(m.rmse^2-20/3)<1e-13);
assert(isequal(m.covariance,diag([4 0 0])));
m=service_ensemble_metrics([X NaN(3,1)],[0 0 0 2],truth);
assert(m.failure_fraction==0.25 && m.successful==3);
m=service_ensemble_metrics(NaN(3,2),[2 2],truth);
assert(m.failure_fraction==1 && isnan(m.rmse));
P=zeros(3,2); a=zeros(2,3); v=ones(2,1);
r=service_run_ensemble(@expectedFailure,P,a,a,v,v,zeros(3,1));
assert(all(r.statuses==2) && ~any(r.contract_violations));
r=service_run_ensemble(@falseSuccess,P,a,a,v,v,zeros(3,1));
assert(all(r.contract_violations) && r.metrics.failure_fraction==1);
r=service_run_ensemble(@throws,P,a,a,v,v,zeros(3,1));
assert(all(r.contract_violations) && all(~cellfun(@isempty,r.errors)));
try
    service_run_multi_criteria_bench(1,@lls_position,@lls_covariance,'LLS');
    error('libtr:test:FalsePass','Legacy benchmark must not pass');
catch exception
    assert(strcmp(exception.identifier,'libtr:validation:LegacyBench'));
end
end
function [s,x]=expectedFailure(varargin)
s=2; x=NaN(3,1);
end
function [s,x]=falseSuccess(varargin)
s=0; x=NaN(3,1);
end
function [s,x]=throws(varargin)
error('libtr:test:Injected','Intentional test exception');
end