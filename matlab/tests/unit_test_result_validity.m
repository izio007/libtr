function unit_test_result_validity
setup_test_paths;
clear test_model_result;
P=zeros(3,2); a=zeros(2,2); v=ones(2,1);
models={test_model_init(@position,P,a,a,v,v,zeros(3,1)), ...
    test_trajectory_init(@position,[0 1],P,a,a,v,v,zeros(3,2)), ...
    test_filter_init(struct(),struct(),[0 1],[0 0],[false false],[0 0])};
for k=1:numel(models)
    m=models{k}; m.cursor=2;
    rows=size(m.result.samples,1);
    m.result.samples=[ones(rows,1) 100*ones(rows,1)];
    m.result.statuses=[0 0];
    m.result.contract_violations=[false true];
    m.result.errors{2}='Injected diagnostic';
    raw=m.result;
    r=test_model_result(m);
    assert(isequal(r.valid,[true false]) && r.metrics.successful==1);
    assert(r.metrics.failure_fraction==0.5 && abs(r.metrics.rmse-sqrt(rows))<1e-14);
    assert(isequaln(r.samples,raw.samples) && isequaln(r.statuses,raw.statuses));
    assert(isequal(r.errors,raw.errors));
    m.result.contract_violations=[true true];
    r=test_model_result(m);
    assert(~any(r.valid) && r.metrics.successful==0 && isnan(r.metrics.rmse));
    assert(r.metrics.failure_fraction==1);
end
% Normal execution, not only injected result records.
m=models{1}; m=test_model_step(m); m=test_model_step(m);
r=test_model_result(m); assert(all(r.valid) && r.metrics.successful==2);
unit_test_path_model;
fprintf('Explicit validity mask, raw evidence preservation and lifecycle regressions PASS\n');
end
function [s,x]=position(varargin)
s=0; x=ones(3,1);
end