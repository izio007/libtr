function [s, out, debug] = voi_execute(cfg, s, candidate, f, decision, t)
%VOI_EXECUTE Adopt selected data and publish one consistent state/output.
% A real accepted ray may extend history even if it gives no LS solution.
% The point/coefficient arrays are assigned only by INIT and UPDATE.

phase_before = s.phase;
model_updated = false;
accepted = false;
if ~strcmp(decision.action, 'FROZEN')
    if f.has_new_ray
        s.origins = candidate.origins;
        s.directions = candidate.directions;
        s.t_obs = candidate.t_obs;
        s.count = candidate.count;
        s.next_slot = candidate.next_slot;
        s.last_observation_time = candidate.last_observation_time;
        accepted = true;
    end

    switch decision.action
        case 'INIT'
            s.point = f.prior_candidate;
            s.coeff = [s.point, zeros(3,3)];
            s.support_time = f.prior_time;
            s.basis = 1;
            s.phase = 2;
            s.status = 'APRIORI_SPLINE';
            model_updated = true;
        case 'UPDATE'
            s.point = f.ls_candidate;
            s.coeff = [s.point, zeros(3,3)];
            s.support_time = max(s.t_obs(1:s.count));
            s.basis = 2;
            s.phase = 3;
            s.status = 'TRACK_DYNAMIC';
            model_updated = true;
        case 'HOLD'
            if s.basis == 2
                s.status = 'HOLD_LS';
            elseif s.basis == 1
                s.status = 'HOLD_APRIORI';
            else
                s.status = 'UNAVAILABLE';
            end
        otherwise
            error('voi_execute:InvalidAction', 'Unknown VOI action.');
    end

    s.reason = decision.reason;
    s.last_tick = t;
    if decision.finalize
        s.phase = 4;
        s.finalized = true;
        s.finalized_at = t;
        if s.basis == 2
            s.status = 'FINAL_C2_SPLINE';
        elseif s.basis == 1
            s.status = 'FINAL_APRIORI';
        else
            s.status = 'FINAL_UNAVAILABLE';
        end
    end
end

if s.basis == 0
    age = NaN;
    fresh = false;
else
    age = t - s.support_time;
    fresh = age <= cfg.age_max;
end
out = struct('available', s.basis ~= 0, 'observed', s.basis == 2, ...
    'phase', s.phase, 'basis', s.basis, 'point', s.point, ...
    'coeff', s.coeff, 'time_origin', s.time_origin, ...
    'interval', [cfg.time_start, cfg.time_end], ...
    'status', s.status, 'reason', s.reason, ...
    'support_time', s.support_time, ...
    'last_observation_time', s.last_observation_time, ...
    'age', age, 'fresh', fresh, ...
    'finalized', s.finalized, 'finalized_at', s.finalized_at);
debug = struct('action', decision.action, 'data_state', f.data_state, ...
    'geometry_state', f.geometry_state, 'accepted', accepted, ...
    'model_updated', model_updated, 'phase_before', phase_before, ...
    'phase_after', s.phase, 'reason', decision.reason, ...
    'position_info', f.position_info, 'direction_info', f.direction_info);
end
