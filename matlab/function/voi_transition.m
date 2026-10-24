function decision = voi_transition(s, f, t, cfg)
%VOI_TRANSITION Select one action from facts, without solving or mutating.
% LS update has priority only when both data and the complete geometry
% predicate are True. False and Unknown retain the last accepted model.

decision = struct('action', 'HOLD', 'finalize', false, ...
    'reason', f.input_reason);
if s.finalized
    decision.action = 'FROZEN';
    decision.reason = 'ALREADY_FINALIZED';
    return;
end

decision.finalize = t >= cfg.time_end;
if f.data_state == 1 && f.geometry_state == 1
    decision.action = 'UPDATE';
    decision.reason = 'OK';
elseif s.basis == 0 && f.has_prior_candidate
    decision.action = 'INIT';
    decision.reason = 'PRIOR_RANGE';
elseif f.data_state == 1
    if s.basis == 0 && strcmp(f.prior_reason, 'NUMERIC_FAILURE')
        decision.reason = f.prior_reason;
    else
        decision.reason = f.position_info.reason;
    end
end
end
