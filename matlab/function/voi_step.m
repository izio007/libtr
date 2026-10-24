function [rc, ctx, out, debug] = voi_step(cfg, ctx, current_time, obs)
%VOI_STEP One synchronous tick of the stationary-target VOI pipeline.
% [rc,ctx,out,debug] = voi_step(cfg,ctx,current_time,obs)
% Start a stream with ctx=struct(). Time/positions/angles use seconds, metres
% and radians. The observation pose belongs to obs.t_obs, not current_time.
% rc=0: completed tick (including a rejected observation or held result).
% rc=1: invalid outer API/configuration/context/time; ctx is unchanged.
% A final context is immutable and may be read at any time >= last_tick.
%
% The output is a versioned stationary polynomial [point,0,0,0]. Changing a
% point between ticks does not establish C2 continuity between versions.

rc = 1;
if nargin < 2
    ctx = struct();
end
[out, debug] = api_failure('INVALID_ARGUMENT_COUNT');
if nargin ~= 4
    return;
end

[config_ok, normalized, reason] = normalize_config(cfg);
if ~config_ok
    [out, debug] = api_failure(reason);
    return;
end
if ~isstruct(ctx) || ~isscalar(ctx)
    [out, debug] = api_failure('INVALID_CONTEXT');
    return;
end
if ~finite_scalar(current_time) || current_time < normalized.time_start || ...
        ~isfinite(current_time - normalized.time_start)
    [out, debug] = api_failure('INVALID_CURRENT_TIME');
    return;
end
if ~isstruct(obs) || ~isscalar(obs) || ~isfield(obs, 'm') || ...
        ~(isa(obs.m, 'double') || islogical(obs.m)) || ...
        ~isreal(obs.m) || ~isscalar(obs.m) || ...
        ~(obs.m == 0 || obs.m == 1)
    [out, debug] = api_failure('INVALID_OBSERVATION_API');
    return;
end

if isempty(fieldnames(ctx))
    % Capacity is a caller-selected resource budget. Do not impose an
    % arbitrary numerical cap, but report allocation failure atomically.
    % This catch encloses allocation only, never the numerical algorithm.
    try
        s = initial_state(normalized);
    catch
        [out, debug] = api_failure('CONTEXT_ALLOCATION_FAILURE');
        return;
    end
else
    [context_ok, reason] = validate_context(ctx, normalized);
    if ~context_ok
        [out, debug] = api_failure(reason);
        return;
    end
    s = ctx;
    if s.finalized
        time_ok = current_time >= s.last_tick;
    else
        time_ok = current_time > s.last_tick;
    end
    if ~time_ok
        [out, debug] = api_failure('NONINCREASING_TIME');
        return;
    end
end

% Conditions are computed on a local candidate, the selector is pure, and
% only the executor adopts data. ctx is assigned exactly once on success.
[candidate, facts] = voi_conditions(normalized, s, current_time, obs);
decision = voi_transition(s, facts, current_time, normalized);
[next, out, debug] = voi_execute(normalized, s, candidate, facts, ...
    decision, current_time);
ctx = next;
rc = 0;
end

function [ok, c, reason] = normalize_config(cfg)
ok = false;
c = struct();
reason = 'INVALID_CONFIG';
if ~isstruct(cfg) || ~isscalar(cfg)
    return;
end
required = {'R0','Lmin','kappa_max','capacity','time_start','time_end'};
allowed = [required, {'age_max','residual_max'}];
names = fieldnames(cfg);
if any(~ismember(names, allowed))
    return;
end
for i = 1:numel(required)
    name = required{i};
    if ~isfield(cfg, name) || ~finite_scalar(cfg.(name))
        return;
    end
end
if cfg.R0 <= 0 || cfg.Lmin < 0 || cfg.kappa_max <= 1 || ...
        cfg.capacity < 2 || cfg.capacity ~= fix(cfg.capacity) || ...
        cfg.capacity > flintmax || cfg.time_end <= cfg.time_start || ...
        ~isfinite(cfg.time_end - cfg.time_start)
    return;
end
c = struct('R0', cfg.R0, 'Lmin', cfg.Lmin, ...
    'kappa_max', cfg.kappa_max, 'capacity', cfg.capacity, ...
    'time_start', cfg.time_start, 'time_end', cfg.time_end, ...
    'age_max', Inf, 'residual_max', Inf);
optional = {'age_max','residual_max'};
for i = 1:numel(optional)
    name = optional{i};
    if isfield(cfg, name)
        x = cfg.(name);
        if ~isa(x, 'double') || ~isreal(x) || ~isscalar(x) || ...
                isnan(x) || x < 0
            return;
        end
        c.(name) = x;
    end
end
ok = true;
reason = 'OK';
end

function s = initial_state(cfg)
s = struct('schema_version', 1, 'cfg', cfg, 'phase', 1, 'basis', 0, ...
    'point', NaN(3,1), 'coeff', NaN(3,4), ...
    'time_origin', cfg.time_start, ...
    'origins', zeros(3,cfg.capacity), ...
    'directions', zeros(3,cfg.capacity), ...
    't_obs', NaN(1,cfg.capacity), 'count', 0, 'next_slot', 1, ...
    'last_tick', -Inf, 'last_observation_time', NaN, ...
    'support_time', NaN, 'finalized', false, 'finalized_at', NaN, ...
    'status', 'UNAVAILABLE', 'reason', 'NO_OBSERVATION');
end

function [ok, reason] = validate_context(s, cfg)
ok = false;
reason = 'INVALID_CONTEXT';
required = {'schema_version','cfg','phase','basis','point','coeff', ...
    'time_origin','origins','directions','t_obs','count','next_slot', ...
    'last_tick','last_observation_time','support_time','finalized', ...
    'finalized_at','status','reason'};
names = fieldnames(s);
if numel(names) ~= numel(required) || any(~ismember(required, names))
    return;
end
if ~isstruct(s.cfg) || ~isscalar(s.cfg)
    return;
end
if ~isequaln(s.cfg, cfg)
    reason = 'CONFIG_CHANGED';
    return;
end
if ~integer_in(s.schema_version, 1, 1) || ...
        ~integer_in(s.phase, 1, 4) || ~integer_in(s.basis, 0, 2) || ...
        ~integer_in(s.count, 0, cfg.capacity) || ...
        ~integer_in(s.next_slot, 1, cfg.capacity) || ...
        ~finite_scalar(s.time_origin) || s.time_origin ~= cfg.time_start || ...
        ~finite_scalar(s.last_tick) || s.last_tick < cfg.time_start || ...
        ~islogical(s.finalized) || ~isscalar(s.finalized) || ...
        ~text_scalar(s.status) || ~text_scalar(s.reason)
    return;
end
if ~finite_array(s.origins, [3,cfg.capacity]) || ...
        ~finite_array(s.directions, [3,cfg.capacity]) || ...
        ~isa(s.t_obs, 'double') || ~isreal(s.t_obs) || ...
        ~isequal(size(s.t_obs), [1,cfg.capacity]) || ...
        ~isa(s.point, 'double') || ~isreal(s.point) || ...
        ~isequal(size(s.point), [3,1]) || ...
        ~isa(s.coeff, 'double') || ~isreal(s.coeff) || ...
        ~isequal(size(s.coeff), [3,4])
    return;
end
if s.count < cfg.capacity && s.next_slot ~= s.count + 1
    return;
end
if s.count == 0
    if ~nan_scalar(s.last_observation_time) || s.basis ~= 0
        return;
    end
else
    active = 1:s.count;
    dates = s.t_obs(active);
    if any(~isfinite(dates)) || any(dates < cfg.time_start) || ...
            any(dates > min(s.last_tick, cfg.time_end)) || ...
            numel(unique(dates)) ~= s.count || ...
            ~finite_scalar(s.last_observation_time) || ...
            s.last_observation_time < max(dates) || ...
            s.last_observation_time > min(s.last_tick, cfg.time_end)
        return;
    end
    norms = sqrt(sum(s.directions(:,active).^2, 1));
    if any(abs(norms - 1) > 1e-10)
        return;
    end
end
if s.count < cfg.capacity && any(~isnan(s.t_obs(s.count+1:end)))
    return;
end
if s.basis == 0
    if ~all(isnan(s.point)) || ~all(isnan(s.coeff(:))) || ...
            ~nan_scalar(s.support_time)
        return;
    end
else
    if any(~isfinite(s.point)) || any(~isfinite(s.coeff(:))) || ...
            ~isequal(s.coeff(:,1), s.point) || ...
            any(any(s.coeff(:,2:4) ~= 0)) || ...
            ~finite_scalar(s.support_time) || ...
            s.support_time < cfg.time_start || ...
            s.support_time > s.last_observation_time
        return;
    end
end
if s.finalized
    expected = {'FINAL_UNAVAILABLE','FINAL_APRIORI','FINAL_C2_SPLINE'};
    if s.phase ~= 4 || ~finite_scalar(s.finalized_at) || ...
            s.finalized_at ~= s.last_tick || s.last_tick < cfg.time_end || ...
            ~strcmp(s.status, expected{s.basis+1})
        return;
    end
else
    if s.phase ~= s.basis + 1 || ~nan_scalar(s.finalized_at) || ...
            s.last_tick >= cfg.time_end
        return;
    end
    expected = {{'UNAVAILABLE'}, {'APRIORI_SPLINE','HOLD_APRIORI'}, ...
        {'TRACK_DYNAMIC','HOLD_LS'}};
    if ~any(strcmp(s.status, expected{s.basis+1}))
        return;
    end
end
ok = true;
reason = 'OK';
end

function [out, debug] = api_failure(reason)
out = struct('available', false, 'observed', false, 'phase', NaN, ...
    'basis', NaN, 'point', NaN(3,1), 'coeff', NaN(3,4), ...
    'time_origin', NaN, 'interval', [NaN,NaN], 'status', 'API_ERROR', ...
    'reason', reason, 'support_time', NaN, 'last_observation_time', NaN, ...
    'age', NaN, 'fresh', false, ...
    'finalized', false, 'finalized_at', NaN);
debug = struct('action', 'REJECT_API', 'data_state', -1, ...
    'geometry_state', -1, 'accepted', false, 'model_updated', false, ...
    'phase_before', NaN, 'phase_after', NaN, 'reason', reason, ...
    'position_info', struct(), 'direction_info', struct());
end

function ok = finite_scalar(x)
ok = isa(x, 'double') && isreal(x) && isscalar(x) && isfinite(x);
end

function ok = integer_in(x, lo, hi)
ok = finite_scalar(x) && x == fix(x) && x >= lo && x <= hi;
end

function ok = nan_scalar(x)
ok = isa(x, 'double') && isreal(x) && isscalar(x) && isnan(x);
end

function ok = finite_array(x, dimensions)
ok = isa(x, 'double') && isreal(x) && isequal(size(x), dimensions) ...
    && all(isfinite(x(:)));
end

function ok = text_scalar(x)
ok = ischar(x) && isrow(x) && ~isempty(x);
end
