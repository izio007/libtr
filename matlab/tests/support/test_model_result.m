function result = test_model_result(model)
% Final reduction; partial execution is never published as a complete result.
id='libtr:testmodel:Context';
assert(isstruct(model) && isscalar(model) && ...
    all(isfield(model,{'cursor','result'})),id,'Invalid result context');
assert(isstruct(model.result) && isscalar(model.result) && ...
    all(isfield(model.result,{'samples','statuses','contract_violations','errors'})), ...
    id,'Missing result fields');
assert(isnumeric(model.cursor) && isreal(model.cursor) && isscalar(model.cursor) && ...
    isfinite(model.cursor) && model.cursor>=0 && model.cursor==fix(model.cursor), ...
    id,'Invalid completion cursor');
assert(model.cursor==numel(model.result.statuses), ...
    'libtr:testmodel:Incomplete','Model is not complete');
result=model.result;
id='libtr:testmodel:Context';
mode='ensemble';
if isfield(model,'mode')
    assert(ischar(model.mode) && isrow(model.mode) && ...
        any(strcmp(model.mode,{'trajectory','scalar'})),id,'Unknown result mode');
    mode=model.mode;
end
N=numel(result.statuses);
truthSize=[3 1];
if strcmp(mode,'trajectory'), truthSize=[3 N]; end
if strcmp(mode,'scalar'), truthSize=[1 N]; end
assert(isfield(model,'truth') && isa(model.truth,'double') && isreal(model.truth) && ...
    isequal(size(model.truth),truthSize) && all(isfinite(model.truth(:))), ...
    id,'Invalid truth for result mode');
if ~strcmp(mode,'ensemble')
    hasTime=isfield(model,'time'); hasParameter=isfield(model,'parameter');
    assert(xor(hasTime,hasParameter) && ...
        (~strcmp(mode,'scalar') || hasTime),id,'Ambiguous or missing result scale');
    if hasTime, scale=model.time; else, scale=model.parameter; end
    assert(isa(scale,'double') && isreal(scale) && isequal(size(scale),[1 N]) && ...
        all(isfinite(scale)) && all(diff(scale)>0),id,'Invalid result scale');
else
    assert(~isfield(model,'time') && ~isfield(model,'parameter'),id,'Unexpected ensemble scale');
end
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
assert(all(cellfun(@(text) (ischar(text) && ...
    (isrow(text) || isequal(size(text),[0 0]))) || ...
    (isa(text,'double') && isequal(size(text),[0 0])),result.errors)), ...
    id,'Invalid diagnostic text');
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