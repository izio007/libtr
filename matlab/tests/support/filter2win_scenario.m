function [t_axes, X_true, X_meas, X_filtered_history, W_alt_power_history] = filter2win_scenario
% Scenario orchestration; caller owns RNG and test composition paths.
% Parameters belong to the scalar filter, truth is only a test reference.
[cfg,ctx,t_axes,X_true,X_meas,drop_mask]=filter2win_observations;
n_ticks=numel(t_axes);
model=test_filter_init(cfg,ctx,t_axes,X_meas,drop_mask,X_true);

X_filtered_history = zeros(n_ticks, 1);
W_alt_power_history = zeros(n_ticks, 1);

% 4. ВЫЧИСЛИТЕЛЬНЫЙ ТАКТOВЫЙ КОНВЕЙЕР
for tick = 1:n_ticks
    model=test_model_step(model);
    assert(~model.result.contract_violations(tick), ...
        'libtr:testmodel:ScenarioFailure','Filter scenario failed at tick %d',tick);
    X_filtered_history(tick)=model.result.samples(tick);
    W_alt_power_history(tick)=model.algorithm_state.ctx.W_ALT_POWER_OUTPUT;
end
test_model_result(model);
end
