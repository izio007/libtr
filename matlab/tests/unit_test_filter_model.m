function unit_test_filter_model
setup_test_paths;
clear test_model_step test_model_result test_filter_init test_filter_step;
[spec,cfg]=filter2win_observation_config;
saved=rng; cleanup=onCleanup(@() rng(saved)); rng(spec.seed,spec.rng_algorithm);
[t,truth,z,y,p]=filter2win_scenario;
ctx=struct('X_MAIN_REF',spec.initial_reference);
m=test_filter_init(cfg,ctx,t,z,isnan(z),truth);
other=m;
for j=1:numel(t)
    [s,ctx]=filter2win(cfg,ctx,t(j),z(j),isnan(z(j)));
    assert(s==0);
    m=test_model_step(m);
    assert(isequaln(m.algorithm_state.ctx,ctx));
    assert(isequaln(m.result.samples(j),y(j)) && ctx.W_ALT_POWER_OUTPUT==p(j));
    assert(other.cursor==0);
end
r=test_model_result(m);
assert(~any(r.contract_violations) && any(r.statuses==2));
valid=isfinite(y); errors=y(valid).'-truth(valid);
assert(abs(r.metrics.rmse-sqrt(mean(errors.^2)))<spec.rmse_tolerance);
bad=cfg; bad.main.capacity=spec.invalid_capacity;
m=test_filter_init(bad,struct('X_MAIN_REF',spec.initial_reference), ...
    spec.start_time,spec.truth_level,false,spec.truth_level);
before=m.algorithm_state; m=test_model_step(m);
assert(m.result.contract_violations && isequaln(before,m.algorithm_state));
assert(contains(m.result.errors{1},'filter2win refused'));
fprintf('Scalar filter adapter, %d direct-state references and atomic refusal: PASS\n',numel(t));
end
