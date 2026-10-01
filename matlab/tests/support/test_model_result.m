function result = test_model_result(model)
% Final reduction; partial execution is never published as a complete result.
assert(model.cursor==numel(model.result.statuses), ...
    'libtr:testmodel:Incomplete','Model is not complete');
result=model.result;
id='libtr:testmodel:ResultShape';
rows=3;
if isfield(model,'mode') && strcmp(model.mode,'scalar'), rows=1; end
N=numel(result.statuses);
assert(isa(result.samples,'double') && isreal(result.samples) && ...
    isequal(size(result.samples),[rows N]) && N>0,id,'Invalid sample shape or type');
assert(isa(result.statuses,'double') && isreal(result.statuses) && ...
    isequal(size(result.statuses),[1 N]) && ...
    all(isnan(result.statuses) | ismember(result.statuses,[0 1 2])), ...
    id,'Invalid status row');
assert(islogical(result.contract_violations) && ...
    isequal(size(result.contract_violations),[1 N]),id,'Invalid violation mask');
assert(iscell(result.errors) && isequal(size(result.errors),[1 N]), ...
    id,'Invalid diagnostic row');
result.valid=result.statuses==0 & all(isfinite(result.samples),1) ...
    & ~result.contract_violations;
metricStatuses=result.statuses;
metricStatuses(~result.valid)=NaN;
if isfield(model,'mode') && strcmp(model.mode,'scalar')
    result.time=model.time; result.truth=model.truth;
    valid=result.valid;
    e=result.samples(valid)-model.truth(valid);
    result.metrics=struct('total',numel(valid),'successful',sum(valid), ...
        'failure_fraction',1-sum(valid)/numel(valid),'bias',NaN,'rmse',NaN, ...
        'conditional_on_success',true,'scope','conditional_scalar_error');
    if any(valid)
        result.metrics.bias=mean(e); result.metrics.rmse=sqrt(mean(e.^2));
    end
    return;
end
if isfield(model,'mode') && strcmp(model.mode,'trajectory')
    if isfield(model,'time')
        result.time=model.time;
    else
        result.parameter=model.parameter;
    end
    result.truth=model.truth;
    result.metrics=service_ensemble_metrics(result.samples-model.truth, ...
        metricStatuses,zeros(3,1));
    result.metrics.scope='conditional_trajectory_error';
    return;
end
result.metrics=service_ensemble_metrics(result.samples,metricStatuses,model.truth);
end