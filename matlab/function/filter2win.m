function [rc,ctx,debug]=filter2win(cfg,ctx,current_time,X_meas_tick,is_nan_tick)
% FILTER2WIN Two-window scalar state machine with fixed transitions.
% rc=0: step executed, possibly NaN output. rc=1: ctx unchanged.
% ctx.FILTER_STATE.status and ctx.FILTER_STATUS: schema-specific step outcome.
% Schema 3 keeps ongoing blending in blend_duration, not in a status code.
% Only real measurements enter either FIFO. No synthetic window padding.
% Initialize ctx=struct() when changing schema or parameters.
% All elapsed-time guards use input timestamps.
% Optional third output also explains refused steps without mutating ctx.
% Schema 3 is the default persistent-window implementation.
% Schema 2 remains available only with its explicit legacy configuration.
if isstruct(cfg) && isscalar(cfg) && isfield(cfg,'schema_version') && isequal(cfg.schema_version,3)
    [rc,ctx,debug]=filter2win_persistent(cfg,ctx,current_time,X_meas_tick,is_nan_tick);
    return;
end
rc=1;
[ok,s,missing,debug]=filter2win_prepare(cfg,ctx,current_time,X_meas_tick,is_nan_tick);
if ~ok, return; end
[ok,s,step]=filter2win_transition(cfg,s,current_time,X_meas_tick,missing);
if ~ok, debug.reason=step.reason; return; end
[rc,ctx,debug]=filter2win_execute(cfg,ctx,s,step,debug);
end
