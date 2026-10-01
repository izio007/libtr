function unit_test_filter_model
setup_test_paths;
clear test_model_step test_model_result test_filter_init test_filter_step;
saved=rng; cleanup=onCleanup(@() rng(saved)); rng(1729,'twister');
[t,truth,z,y,p]=filter2win_scenario;
cfg=struct('N',20,'S',6,'R_MAX',5,'R_ALT_MAX',6, ...
    'T_PROLONGATION_MAX',15,'T_TIMEOUT_CLEAR',70,'V',0);
ctx=struct('X_MAIN_REF',10);
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
assert(abs(r.metrics.rmse-sqrt(mean(errors.^2)))<1e-14);
bad=cfg; bad.N=0;
m=test_filter_init(bad,struct('X_MAIN_REF',10),0,10,false,10);
before=m.algorithm_state; m=test_model_step(m);
assert(m.result.contract_violations && isequaln(before,m.algorithm_state));
assert(contains(m.result.errors{1},'filter2win refused'));
unit_test_stateful_model;
fprintf('Scalar filter adapter, 101 direct-state references and all lifecycles: PASS\n');
end