function [rc, out] = voi_joint_snapshot(cfg, t_current, bearings, Sigma)
%VOI_JOINT_SNAPSHOT Stateless complete-history VOI calculation for one epoch.
%   [rc,out]=voi_joint_snapshot(cfg,t_current,bearings,Sigma)
%   All BEARINGS are ACCEPTED observations, chronologically sorted (same
%   timestamp for different observers is allowed). Each entry: t_obs,a,b,
%   origin(3,1),C(3,3). Any missing/invalid observation must be kept OUT
%   of this accepted history; no dummy zero angles are invented.
%
%   Sigma=[] selects ordinary geometric projector LS (no statistical claim).
%   Sigma=FULL 2n-by-2n angle covariance selects nonlinear angular GLS.
%   When GLS refuses a snapshot, a GEOMETRIC result is not silently declared
%   statistical: the caller explicitly opts in via allow_geometric_fallback.
%   In all cases the first admissible observation produces a constant cubic
%   polynomial with hypothetical range R0; not a measured range.
%   Target assumed fixed for this snapshot. For curving target motion use an
%   explicitly different time-dependent model; do not fit history as static.
%
%   Out.coeff are 3-by-4 for a constant spatial point, clamped by construction.
%   Continuous C2 CORRECTION is a separate signal in voi_joint_step.

rc=1;
out=empty_result('INVALID_API');
if nargin~=4 || ~isstruct(cfg) || ~isscalar(cfg) || ...
        ~isa(t_current,'double') || ~isscalar(t_current) || ...
        ~isreal(t_current) || ~isfinite(t_current) || ...
        ~isstruct(bearings) || (~isempty(bearings) && ~isvector(bearings)) || ...
        ~isa(Sigma,'double') || ~isreal(Sigma)
    return;
end
required={'R0','Lmin','kappa_max','residual_max','time_start', ...
    'time_end','age_max','capacity','allow_geometric_fallback'};
if ~all(isfield(cfg,required)) || ...
        ~finite_positive(cfg.R0) || ...
        ~finite_nonnegative(cfg.Lmin) || ...
        ~finite_positive(cfg.kappa_max) || cfg.kappa_max<=1 || ...
        ~finite_signed(cfg.time_start) || ...
        ~finite_signed(cfg.time_end) || cfg.time_end<=cfg.time_start || ...
        ~isinf_or_nonnegative(cfg.age_max) || ...
        ~isinf_or_nonnegative(cfg.residual_max) || ...
        ~finite_positive(cfg.capacity) || fix(cfg.capacity)~=cfg.capacity || ...
        ~islogical(cfg.allow_geometric_fallback) || ...
        ~isscalar(cfg.allow_geometric_fallback)
    out.reason='INVALID_CONFIG'; return;
end
if t_current<cfg.time_start
    out.reason='TIME_BEFORE_START'; return;
end
n=numel(bearings);
out.count=n;
if n>cfg.capacity
    out.reason='CAPACITY_EXCEEDED'; return;
end
if n==0
    out.reason='NO_OBSERVATION';
    out.status='UNAVAILABLE';
    out.phase=1;
    out.last_observation_time=NaN;
    rc=0;
    return;
end
fields={'t_obs','a','b','origin','C'};
times=zeros(n,1);
a=zeros(n,1);b=zeros(n,1);O=zeros(3,n);C=zeros(3,3,n);
u=zeros(3,n);
for i=1:n
    f=bearings(i);
    if ~all(isfield(f,fields)) || ...
            ~finite_signed(f.t_obs) || ~finite_signed(f.a) || ...
            ~finite_signed(f.b) || ...
            ~isa(f.origin,'double') || ...
            ~isequal(size(f.origin),[3,1]) || ...
            ~isreal(f.origin) || any(~isfinite(f.origin)) || ...
            ~isa(f.C,'double') || ~isequal(size(f.C),[3,3]) || ...
            ~isreal(f.C) || any(~isfinite(f.C(:)))
        out.reason='INVALID_BEARING_FIELDS'; return;
    end
    times(i)=f.t_obs;
    a(i)=f.a;b(i)=f.b;
    O(:,i)=f.origin;
    C(:,:,i)=f.C;
    [code,direction,infod]=voi_direction(a(i),b(i),C(:,:,i));
    if code~=1
        out.reason=['INVALID_DIRECTION_' infod.reason]; return;
    end
    u(:,i)=direction;
end
if any(diff(times)<0) || any(times<cfg.time_start) || ...
        any(times>min(t_current,cfg.time_end))
    out.reason='INVALID_OBSERVATION_TIMES'; return;
end
out.last_observation_time=times(end);
out.support_time=times(1);
out.age=t_current-times(1);
out.fresh=out.age<=cfg.age_max;
prior=O(:,1)+cfg.R0*u(:,1);
if any(~isfinite(prior)) || u(:,1)'*(prior-O(:,1))<=0
    out.reason='UNREPRESENTABLE_PRIOR'; return;
end
out.point=prior;
out.coeff=[prior,zeros(3,3)];
out.available=true;
out.basis=1;
out.phase=2;
out.status='PRIOR';
out.reason='R0_NOT_MEASURED';
out.observed=false;
out.quality='HYPOTHESIS';

if n>=2
    [ok,x,geometric]=voi_position(O,u,cfg.Lmin,cfg.kappa_max,Inf);
    out.geometry=geometric;
    if ok==1
        if isempty(Sigma)
            out=accept_geometric(out,x,times(end),'GEOMETRIC_LS');
        else
            if ~isequal(size(Sigma),[2*n,2*n]) || ...
                    any(~isfinite(Sigma(:)))
                out.reason='INVALID_ANGLE_COVARIANCE';
                rc=1; return;
            end
            [accepted,p,weighted]=voi_joint_position(times,a,b,O,C,Sigma,cfg);
            out.weighted=weighted;
            if accepted==1
                out.point=p;
                out.coeff=[p,zeros(3,3)];
                out.available=true;
                out.observed=true;
                out.basis=2;
                out.phase=3;
                out.status='WEIGHTED_LS';
                out.quality='LOCAL_LINEARIZED_COVARIANCE';
                out.K_local=weighted.K_local;
                out.reason='OK';
                out.support_time=times(end);
                out.age=t_current-times(end);
                out.fresh=out.age<=cfg.age_max;
            elseif cfg.allow_geometric_fallback
                out=accept_geometric(out,x,times(end),'UNWEIGHTED_FALLBACK');
                out.reason=weighted.reason;
            else
                out.status='PRIOR_WEIGHTED_REFUSED';
                out.reason=weighted.reason;
            end
        end
    else
        out.status='PRIOR_GEOMETRY_INSUFFICIENT';
        out.reason=geometric.reason;
    end
end
if out.available
    out.age=t_current-out.support_time;
    out.fresh=out.age<=cfg.age_max;
end
if t_current>=cfg.time_end
    out.finalized=true;
    out.phase=4;
    if out.basis==2
        out.status='FINAL_STATIONARY_LS';
    else
        out.status='FINAL_APRIORI';
    end
end
rc=0;
end

function r=accept_geometric(r,p,t,status)
r.point=p;
r.coeff=[p,zeros(3,3)];
r.basis=2;
r.phase=3;
r.status=status;
r.quality='GEOMETRIC_NO_COVARIANCE';
r.reason='OK';
r.observed=true;
r.support_time=t;
r.age=NaN;
r.fresh=false; % Recomputed by caller with the current time.
end

function out=empty_result(reason)
out=struct('available',false,'observed',false,'basis',0,'phase',1, ...
    'point',NaN(3,1),'coeff',NaN(3,4),'K_local',NaN(3,3), ...
    'status','API_ERROR','reason',reason,'quality','NONE', ...
    'count',0,'support_time',NaN,'last_observation_time',NaN, ...
    'age',NaN,'fresh',false,'geometry',struct(), ...
    'weighted',struct(),'finalized',false);
end
function yes=finite_positive(x)
yes=finite_signed(x) && x>0;
end
function yes=finite_nonnegative(x)
yes=finite_signed(x) && x>=0;
end
function yes=finite_signed(x)
yes=isa(x,'double') && isreal(x) && isscalar(x) && isfinite(x);
end
function yes=isinf_or_nonnegative(x)
yes=isa(x,'double') && isreal(x) && isscalar(x) && ...
    ~isnan(x) && x>=0;
end
