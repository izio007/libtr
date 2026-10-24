function [candidate, f] = voi_conditions(cfg, s, t, obs)
%VOI_CONDITIONS Build a local ray-history candidate and mathematical facts.
% Called after voi_step has validated the outer API, configuration and state.
% The input state is never committed here. Missing/invalid measurements do
% not append a synthetic ray and do not run a new position calculation.

candidate = s;
f = struct('data_state', -1, 'geometry_state', -1, ...
    'has_new_ray', false, 'has_prior_candidate', false, ...
    'prior_candidate', NaN(3,1), 'prior_time', NaN, ...
    'ls_candidate', NaN(3,1), 'input_reason', 'MISSING_MEASUREMENT', ...
    'prior_reason', 'NOT_COMPUTED', 'direction_info', struct(), ...
    'position_info', empty_position_info(s.count));

if s.finalized
    f.input_reason = 'ALREADY_FINALIZED';
    return;
end
if obs.m == 0
    return;
end

% Known malformed content is False; absence of navigation is Unknown.
f.data_state = 0;
if ~isfield(obs, 't_obs') || ~finite_scalar(obs.t_obs)
    f.input_reason = 'INVALID_OBSERVATION_TIME';
    return;
end
if obs.t_obs < cfg.time_start || obs.t_obs > min(t, cfg.time_end)
    f.input_reason = 'OBSERVATION_TIME_OUT_OF_RANGE';
    return;
end
if any(s.t_obs(1:s.count) == obs.t_obs)
    f.input_reason = 'DUPLICATE_OBSERVATION';
    return;
end
if ~isfield(obs, 'a') || ~isfield(obs, 'b') || ...
        ~finite_scalar(obs.a) || ~finite_scalar(obs.b)
    f.input_reason = 'INVALID_ANGLES';
    return;
end
if abs(obs.a) > pi/2 || abs(obs.b) > pi/2
    f.input_reason = 'INVALID_ANGLES';
    return;
end
if ~isfield(obs, 'nav_status')
    f.data_state = -1;
    f.input_reason = 'NAV_UNAVAILABLE';
    return;
end
if ~finite_scalar(obs.nav_status) || ...
        ~any(obs.nav_status == [-1, 0, 1])
    f.input_reason = 'INVALID_NAV_STATUS';
    return;
end
if obs.nav_status == -1
    f.data_state = -1;
    f.input_reason = 'NAV_UNAVAILABLE';
    return;
end
if obs.nav_status == 0
    f.input_reason = 'NAV_INVALID';
    return;
end
if ~isfield(obs, 'origin') || ~isfield(obs, 'C') || ...
        ~finite_array(obs.origin, [3, 1]) || ...
        ~finite_array(obs.C, [3, 3])
    f.input_reason = 'INVALID_NAVIGATION';
    return;
end

[direction_state, u, direction_info] = voi_direction(obs.a, obs.b, obs.C);
f.direction_info = direction_info;
if direction_state ~= 1
    f.data_state = direction_state;
    f.input_reason = direction_info.reason;
    return;
end

% Coordinates and rotation belong to t_obs, including delayed messages.
slot = s.next_slot;
candidate.origins(:, slot) = obs.origin;
candidate.directions(:, slot) = u;
candidate.t_obs(slot) = obs.t_obs;
candidate.count = min(s.count + 1, cfg.capacity);
candidate.next_slot = mod(slot, cfg.capacity) + 1;
if s.count == 0
    candidate.last_observation_time = obs.t_obs;
else
    candidate.last_observation_time = max(s.last_observation_time, obs.t_obs);
end
f.has_new_ray = true;
f.data_state = 1;
f.input_reason = 'OK';

% The prior is attached once to the first usable ray; it is not recomputed
% from each current pose while an existing prior or LS model is held.
if s.basis == 0
    f.prior_candidate = obs.origin + cfg.R0 * u;
    f.prior_time = obs.t_obs;
    if all(isfinite(f.prior_candidate))
        % A finite sum can still round to the origin under a large common
        % coordinate offset. Such a point has no positive directed range.
        delta = f.prior_candidate - obs.origin;
        rho = u' * delta;
        if all(isfinite(delta)) && isfinite(rho) && rho > 0
            f.has_prior_candidate = true;
            f.prior_reason = 'PRIOR_RANGE';
        else
            f.prior_reason = 'NUMERIC_FAILURE';
        end
    else
        f.prior_reason = 'NUMERIC_FAILURE';
    end
end

active = 1:candidate.count;
[f.geometry_state, f.ls_candidate, f.position_info] = voi_position( ...
    candidate.origins(:,active), candidate.directions(:,active), ...
    cfg.Lmin, cfg.kappa_max, cfg.residual_max);
end

function ok = finite_scalar(x)
ok = isa(x, 'double') && isreal(x) && isscalar(x) && isfinite(x);
end

function ok = finite_array(x, dimensions)
ok = isa(x, 'double') && isreal(x) && isequal(size(x), dimensions) ...
    && all(isfinite(x(:)));
end

function info = empty_position_info(count)
info = struct('reason', 'NOT_COMPUTED', 'L', NaN, ...
    'condition_A', NaN, 'lambda_min', NaN, 'lambda_max', NaN, ...
    'rms_residual', NaN, 'min_range', NaN, 'count', count);
end
