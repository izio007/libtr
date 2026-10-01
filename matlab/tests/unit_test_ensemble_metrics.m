function unit_test_ensemble_metrics
setup_test_paths;
% Independent exact moments, failure accounting, and exception injection.
X=[1 3 5;2 2 2;0 0 0]; truth=[1;2;0];
bad={{single(X),[0 0 0],truth}, {reshape(zeros(12,1),3,2,2),zeros(1,4),truth}, ...
    {complex(X,ones(size(X))),[0 0 0],truth}, {X,[0 Inf 0],truth}, ...
    {X,[0 0.5 0],truth}, {X,[0 0 0],single(truth)}, ...
    {X,[0 0 0],complex(truth,ones(3,1))}, {zeros(3,4),zeros(2),truth}, ...
    {zeros(3,0),[],truth}};
for k=1:numel(bad)
    args=bad{k}; caught=false;
    try
        service_ensemble_metrics(args{:});
    catch e
        caught=strcmp(e.identifier,'libtr:metrics:EnsembleInput');
    end
    assert(caught);
end
row=service_ensemble_metrics(X,[0 NaN 0],truth);
column=service_ensemble_metrics(X,[0;NaN;0],truth);
assert(isequaln(row,column) && row.successful==2);
assert(isequal(row.bias,[2;0;0]) && abs(row.rmse-sqrt(8))<1e-14);
m=service_ensemble_metrics(X,[0 0 0],truth);
assert(isequal(m.bias,[2;0;0]));
assert(abs(m.rmse^2-20/3)<1e-13);
assert(isequal(m.covariance,diag([4 0 0])));
m=service_ensemble_metrics([X NaN(3,1)],[0 0 0 2],truth);
assert(m.failure_fraction==0.25 && m.successful==3);
m=service_ensemble_metrics(NaN(3,2),[2 2],truth);
assert(m.failure_fraction==1 && isnan(m.rmse));
% Six symmetric offsets: analytic second moments, no production oracle.
center=[4;5;6]; target=[1;1;1];
cloud=center+[diag([1 2 3]) -diag([1 2 3])];
q=service_ensemble_metrics(cloud,zeros(1,6),target);
K=diag([2 8 18])/5;
assert(isequal(q.mean,center) && isequal(q.bias,[3;4;5]));
assert(norm(q.covariance-K,'fro')<1e-12);
assert(abs(q.rmse^2-(50+28/6))<1e-12);
assert(abs(q.rmse^2-(sum(q.bias.^2)+5/6*trace(q.covariance)))<1e-12);
assert(norm(q.axes*diag(q.eigenvalues)*q.axes.'-K,'fro')<1e-12);
assert(norm(q.axes.'*q.axes-eye(3),'fro')<1e-12);
assert(norm(sort(q.semiaxes)-sqrt(diag(K)))<1e-12);
permuted=service_ensemble_metrics(cloud(:,[6 2 4 1 5 3]),zeros(1,6),target);
excluded=service_ensemble_metrics([cloud [1e9;1e9;1e9] NaN(3,1)], ...
    [zeros(1,6) NaN 0],target);
for candidate={permuted,excluded}
    z=candidate{1};
    assert(isequal(z.mean,q.mean) && isequal(z.bias,q.bias));
    assert(norm(z.covariance-K,'fro')<1e-12 && abs(z.rmse-q.rmse)<1e-12);
end
assert(excluded.successful==6 && excluded.failure_fraction==0.25);
one=service_ensemble_metrics([center NaN(3,1)],[0 2],target);
none=service_ensemble_metrics([center NaN(3,1)],[NaN 2],target);
assert(one.successful==1 && one.failure_fraction==0.5);
assert(isequal(one.mean,center) && isequal(one.bias,[3;4;5]));
assert(abs(one.rmse-sqrt(50))<1e-12);
assert(none.successful==0 && none.failure_fraction==1 && isnan(none.rmse));
assert(all(isnan(none.mean)) && all(isnan(none.bias)));
for field={'covariance','axes','eigenvalues','semiaxes','psi','theta'}
    assert(all(isnan(one.(field{1})(:))) && all(isnan(none.(field{1})(:))));
end
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