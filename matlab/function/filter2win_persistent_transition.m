function decision=filter2win_persistent_transition(f)
% Pure fixed policy over observed facts; no FIFO, model, clock or writes.
% A decision selects an action. The final diagnostic status follows its result.
if f.missing
    if ~f.has_active
        event='WARMUP_MISSING';
        if f.no_samples, event='EMPTY_MISSING'; end
        action='unavailable';
    elseif ~f.can_hold || (f.blend_active && f.cancel_on_missing)
        event='GAP_EXPIRED'; action='unavailable';
    elseif f.blend_active
        event='BLEND_ACTIVE'; action='blend';
    else
        event='GAP_HOLD'; action='hold';
    end
elseif f.accepted && f.ready_after
    if ~f.has_active
        event='INITIAL_READY'; action='track';
    elseif ~f.route_is_active
        if f.wait_done && ~f.main_hold
            event='SWITCH_READY'; action='blend';
            if f.instant_switch, action='switch'; end
        else
            event='SWITCH_WAIT'; action='wait';
        end
    elseif f.blend_active
        event='BLEND_ACTIVE'; action='blend';
    else
        event='ACTIVE_ACCEPT'; action='track';
    end
elseif f.blend_active && f.can_hold
    event='BLEND_ACTIVE'; action='blend';
elseif f.accepted
    event='ALT_ACCUMULATE'; action='accumulate';
    if f.has_active && f.window_was_empty, event='OUTLIER_HOLD'; end
    if f.route_is_main && ~f.has_active, event='MAIN_ACCUMULATE'; end
elseif f.has_route
    event='QUALITY_REJECT'; action='reject';
    if ~f.has_active, event='WARMUP_REJECTED'; end
else
    event='OUTSIDE_BOTH'; action='reject';
end
if strcmp(event,'BLEND_ACTIVE') && f.blend_done
    action='switch';
end
decision=struct('event',event,'action',action);
end
