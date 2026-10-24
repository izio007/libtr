function [rc, next, result] = voi_joint_step(cfg, context, t_current, bearings, Sigma)
%VOI_JOINT_STEP Atomic snapshot estimation + C2 coordinate correction.
%   Full accepted bearing history is supplied each tick (no hidden FIFO).
%   First call: context=struct(). The later calls must have increasing t.
%   Missing measurement: call with UNCHANGED bearings and Sigma; the
%   historical estimate is recomputed but no synthetic measurement is added.
%   Expensive regression can be scheduled less often by the caller; this
%   function is a mathematical bridge, not an implicit real-time scheduler.
%
%   Tracking model out.coeff is a constant cubic for a STATIONARY target.
%   out.correction is a distinct C2 transition of published coordinates.
%   Once t >= time_end, the model is frozen; the transition may continue
%   to time_end+H to honor continuity after a last-moment new estimate.
%   rc=1 leaves the entire caller context unchanged.

rc=1;
next=struct();
if nargin>=2
    next=context;
end
result=struct('available',false,'reason','INVALID_API');
if nargin~=5 || ~isstruct(context) || ~isscalar(context) || ...
        ~isstruct(cfg) || ~isscalar(cfg) || ~isfield(cfg,'H') || ...
        ~isa(cfg.H,'double') || ~isreal(cfg.H) || ~isscalar(cfg.H) || ...
        ~isfinite(cfg.H) || cfg.H<=0 || ...
        ~isa(t_current,'double') || ~isreal(t_current) || ...
        ~isscalar(t_current) || ~isfinite(t_current)
    return;
end
if isempty(fieldnames(context))
    state=struct('version',1,'cfg',cfg,'last_tick',-Inf, ...
        'frozen',false,'correction',struct(), ...
        'accepted',struct('available',false,'basis',0, ...
            'point',NaN(3,1),'status','UNAVAILABLE', ...
            'quality','NONE','K_local',NaN(3,3), ...
            'support_time',NaN,'last_observation_time',NaN), ...
        'last_snapshot',struct());
else
    required={'version','cfg','last_tick','frozen', ...
        'correction','accepted','last_snapshot'};
    acc_required={'available','basis','point','status','quality', ...
        'K_local','support_time','last_observation_time'};
    if ~all(isfield(context,required)) || ...
            ~isequaln(context.cfg,cfg) || context.version~=1 || ...
            ~islogical(context.frozen) || ~isscalar(context.frozen) || ...
            ~isa(context.last_tick,'double') || ...
            ~isscalar(context.last_tick) || ...
            ~isfinite(context.last_tick) || ...
            ~isstruct(context.accepted) || ...
            ~isscalar(context.accepted) || ...
            ~all(isfield(context.accepted,acc_required)) || ...
            ~isstruct(context.correction) || ...
            ~isscalar(context.correction)
        result.reason='INVALID_CONTEXT'; return;
    end
    state=context;
end
if t_current<=state.last_tick
    result.reason='NONINCREASING_TIME'; return;
end

% Calculate on local candidates; state remains immutable until the last line.
if state.frozen
    snap=state.last_snapshot;
else
    [ok,snap]=voi_joint_snapshot(cfg,t_current,bearings,Sigma);
    if ok~=0
        result.reason=['SNAPSHOT_' snap.reason]; return;
    end
end
old=state.accepted;
update=false;
if ~state.frozen && snap.available
    % Avoid downgrading an established, identifiable coordinate estimate to
    % a guessed R0 when a later statistical/geometry calculation refuses.
    if snap.basis==2 || ~old.available
        update=~old.available || ~isequal(old.point,snap.point) || ...
            old.basis~=snap.basis;
        state.accepted=struct('available',snap.available, ...
            'basis',snap.basis,'point',snap.point,'status',snap.status, ...
            'quality',snap.quality,'K_local',snap.K_local, ...
            'support_time',snap.support_time, ...
            'last_observation_time',snap.last_observation_time);
    end
end
if ~state.frozen && t_current>=cfg.time_end
    state.frozen=true;
end
state.last_snapshot=snap;
state.last_tick=t_current;
target=[];
if update
    target=state.accepted.point;
end
[code,correction_next,correction]=voi_correction_step( ...
    cfg.H,state.correction,t_current,target);
if code~=0
    result.reason=['CORRECTION_' correction.reason]; return;
end
state.correction=correction_next;
acc=state.accepted;
held=old.available && snap.available && snap.basis==1 && old.basis==2;
publication_status=acc.status;
if held
    publication_status='HOLD_LAST_OBSERVED';
end
result=struct('available',acc.available,'basis',acc.basis, ...
    'point',acc.point,'coeff',[acc.point,zeros(3,3)], ...
    'quality',acc.quality,'K_local',acc.K_local, ...
    'support_time',acc.support_time, ...
    'last_observation_time',acc.last_observation_time, ...
    'age',t_current-acc.support_time, ...
    'fresh',acc.available && t_current-acc.support_time<=cfg.age_max, ...
    'observed',acc.basis==2, ...
    'status',publication_status,'reason',snap.reason, ...
    'finalized',state.frozen, ...
    'phase',phase_of(state), ...
    'correction',correction,'snapshot',snap);
if ~acc.available
    result.age=NaN;
end
next=state;
rc=0;
end
function p=phase_of(s)
if s.frozen
    p=4;
elseif s.accepted.basis==2
    p=3;
elseif s.accepted.basis==1
    p=2;
else
    p=1;
end
end
