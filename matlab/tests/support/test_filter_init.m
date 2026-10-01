function model = test_filter_init(cfg,ctx,time,measurement,missing,truth)
N=numel(time);
assert(isa(time,'double') && isreal(time) && isequal(size(time),[1 N]) ...
    && N>0 && all(isfinite(time)) && all(diff(time)>0));
assert(isa(measurement,'double') && isreal(measurement) && isequal(size(measurement),[1 N]));
assert(isequal(size(missing),[1 N]) && all(ismember(missing,[0 1])));
assert(isa(truth,'double') && isreal(truth) && isequal(size(truth),[1 N]) && all(isfinite(truth)));
model.mode='scalar'; model.stateful=true;
model.algorithm=@test_filter_step;
model.algorithm_state=struct('cfg',cfg,'ctx',ctx);
test_state_validate(model.algorithm_state);
model.observations=struct('measurement',measurement,'missing',logical(missing));
model.time=time; model.current_time=NaN; model.truth=truth; model.cursor=0;
model.result=struct('samples',NaN(1,N),'statuses',NaN(1,N), ...
    'errors',{cell(1,N)},'contract_violations',false(1,N));
end