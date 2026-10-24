function [accepted, point, info] = voi_joint_position(t_obs, a, b, origins, rotations, Sigma, cfg)
%VOI_JOINT_POSITION Nonlinear GLS of a STATIONARY point from signed plane angles.
% Independent time stamps; curving sensor path is allowed. No time averaging.
% a_i = asin(v_i(2)); b_i = asin(v_i(3));
% v_i = C_i' * (X-o_i)/norm(X-o_i), C_i local-to-common rotation.
% Sigma is the FULL 2n-by-2n covariance of [a1;b1;...;an;bn], in rad^2.
% Off-diagonal cross-time and cross-channel terms must be preserved.
% This is not the geometric projector criterion of voi_position: nonlinear
% generalized least squares is minimized by damped GN, starting from the
% existing geometric estimator. Covariance below is LOCAL, first order.
% No normal distribution is assumed; no Gaussian confidence is claimed.
%
% cfg: Lmin[m], kappa_max for normal matrix, residual_max[rad],
%      max_iters, max_backtracks, step_tol[m], cost_rel_tol.
% accepted=1 only after all geometric/numerical criteria pass.

accepted = 0;
point = NaN(3,1);
info = struct('reason','INVALID_API','count',0,'L',NaN, ...
    'condition',NaN,'rms_angle',NaN,'max_angle',NaN, ...
    'whitened_cost',NaN,'iterations',0,'K_local',NaN(3,3), ...
    'geometry_reason','NOT_COMPUTED','residual',NaN);
if nargin ~= 7 || ~isstruct(cfg) || ~isscalar(cfg)
    return;
end
required = {'Lmin','kappa_max','residual_max','max_iters', ...
    'max_backtracks','step_tol','cost_rel_tol'};
if ~all(isfield(cfg,required))
    info.reason='INVALID_CONFIG'; return;
end
if ~num(cfg.Lmin) || cfg.Lmin < 0 || ~num(cfg.kappa_max) || ...
        cfg.kappa_max <= 1 || ~num(cfg.max_iters) || ...
        cfg.max_iters < 1 || fix(cfg.max_iters) ~= cfg.max_iters || ...
        ~num(cfg.max_backtracks) || cfg.max_backtracks < 0 || ...
        fix(cfg.max_backtracks) ~= cfg.max_backtracks || ...
        ~num(cfg.step_tol) || cfg.step_tol <= 0 || ...
        ~num(cfg.cost_rel_tol) || cfg.cost_rel_tol <= 0 || ...
        cfg.cost_rel_tol >= 1 || ...
        ~isa(cfg.residual_max,'double') || ~isscalar(cfg.residual_max) || ...
        ~isreal(cfg.residual_max) || isnan(cfg.residual_max) || ...
        cfg.residual_max <= 0
    info.reason='INVALID_CONFIG'; return;
end
if ~isa(t_obs,'double') || ~isreal(t_obs) || ~iscolumn(t_obs) || ...
        ~all(isfinite(t_obs)) || ~isa(a,'double') || ...
        ~isa(b,'double') || ~iscolumn(a) || ~iscolumn(b) || ...
        ~isreal(a) || ~isreal(b) || ~all(isfinite(a)) || ...
        ~all(isfinite(b)) || any(diff(t_obs)<0) || ...
        ~isa(origins,'double') || ~isreal(origins) || ...
        ~all(isfinite(origins(:))) || ...
        ~isa(rotations,'double') || ~isreal(rotations) || ...
        ~all(isfinite(rotations(:))) || ...
        ~isa(Sigma,'double') || ~isreal(Sigma) || ...
        ~all(isfinite(Sigma(:))) || issparse(Sigma)
    info.reason='INVALID_OBSERVATIONS'; return;
end
n=numel(t_obs);
info.count=n;
if n<2 || numel(a)~=n || numel(b)~=n || ...
        ~isequal(size(origins),[3,n]) || ...
        ~isequal(size(rotations),[3,3,n]) || ...
        ~isequal(size(Sigma),[2*n,2*n]) || ...
        any(abs(a)>pi/2) || any(abs(b)>pi/2)
    info.reason='INVALID_DIMENSIONS'; return;
end

% Use the same representation validation and hemisphere convention as VOI.
u=zeros(3,n);
for i=1:n
    [ok,ray,direction_info] = voi_direction(a(i),b(i),rotations(:,:,i));
    if ok~=1
        info.reason=direction_info.reason; return;
    end
    u(:,i)=ray;
end

% The geometric seed checks parallax, baseline, positive ranges and rank.
[have_seed,x0,geometry]=voi_position(origins,u,cfg.Lmin,cfg.kappa_max,Inf);
info.L=geometry.L;
info.geometry_reason=geometry.reason;
if have_seed~=1
    info.reason=['GEOMETRY_' geometry.reason]; return;
end

% Standard Cholesky whitening: Sigma=R'*R; r_white=R'\r.
s=norm(Sigma,'fro');
if ~isfinite(s) || s<=0 || norm(Sigma-Sigma','fro') > ...
        64*max(1,2*n)*eps(s)
    info.reason='INVALID_COVARIANCE'; return;
end
Sigma=(Sigma+Sigma')/2;
try
    [Rcov,flag]=chol(Sigma);
catch
    info.reason='INVALID_COVARIANCE'; return;
end
if flag~=0 || any(~isfinite(Rcov(:)))
    info.reason='COVARIANCE_NOT_SPD'; return;
end

anchor=origins(:,1);
local_origins=bsxfun(@minus,origins,anchor);
x=x0-anchor;
if any(~isfinite(x)) || any(~isfinite(local_origins(:)))
    info.reason='COORDINATE_OVERFLOW'; return;
end
converged=false;
for k=1:cfg.max_iters
    [valid,res,J]=model(x,a,b,local_origins,rotations);
    if ~valid
        info.reason='PREDICTION_DOMAIN'; return;
    end
    rw=Rcov'\res;
    Jw=Rcov'\J;
    [rank_ok,condition]=condition_check(Jw,cfg.kappa_max);
    info.condition=condition;
    if ~rank_ok
        info.reason='NONIDENTIFIABLE_OR_ILL_CONDITIONED'; return;
    end
    try
        [Q,R]=qr(Jw,0);
        dx=-(R\(Q'*rw));
    catch
        info.reason='QR_FAILURE'; return;
    end
    if any(~isfinite(dx))
        info.reason='NUMERIC_FAILURE'; return;
    end
    info.iterations=k;
    if norm(dx)<=cfg.step_tol
        converged=true;
        break;
    end
    cost=0.5*(rw'*rw);
    descent=(Jw'*rw)'*dx;
    improved=false;
    % Backtracking rejects non-forward directions and non-decreasing cost.
    for j=0:cfg.max_backtracks
        fraction=2^(-j);
        xt=x+fraction*dx;
        [trial_ok,rt,~]=model(xt,a,b,local_origins,rotations);
        if ~trial_ok
            continue;
        end
        zt=Rcov'\rt;
        new_cost=0.5*(zt'*zt);
        if isfinite(new_cost) && new_cost < cost && ...
                new_cost <= cost + 1e-4*fraction*descent
            x=xt;
            improved=true;
            if fraction*norm(dx)<=cfg.step_tol || ...
                    (cost-new_cost)<=cfg.cost_rel_tol*max(1,cost)
                converged=true;
            end
            break;
        end
    end
    if ~improved
        info.reason='NO_ACCEPTED_DESCENT'; return;
    end
    if converged
        break;
    end
end
if ~converged
    info.reason='ITERATION_LIMIT'; return;
end

[valid,res,J]=model(x,a,b,local_origins,rotations);
if ~valid
    info.reason='PREDICTION_DOMAIN'; return;
end
Jw=Rcov'\J;
[rank_ok,condition]=condition_check(Jw,cfg.kappa_max);
info.condition=condition;
if ~rank_ok
    info.reason='NONIDENTIFIABLE_OR_ILL_CONDITIONED'; return;
end
info.rms_angle=norm(res/sqrt(2*n));
info.max_angle=max(abs(res));
z=Rcov'\res;
info.whitened_cost=0.5*(z'*z);
info.residual=res;
if any(~isfinite(res)) || ~isfinite(info.whitened_cost)
    info.reason='NUMERIC_FAILURE'; return;
end
if info.max_angle>cfg.residual_max
    info.reason='ANGLE_RESIDUAL_LIMIT'; return;
end
try
    [~,R]=qr(Jw,0);
    D=R\eye(3);
    K=D*D';
catch
    info.reason='NUMERIC_FAILURE'; return;
end
X=anchor+x;
if any(~isfinite(X)) || any(~isfinite(K(:)))
    info.reason='COORDINATE_OVERFLOW'; return;
end
point=X;
info.K_local=(K+K')/2;
info.reason='OK';
accepted=1;
end

function [ok,r,J]=model(x,a,b,O,C)
n=numel(a);
r=NaN(2*n,1);
J=NaN(2*n,3);
ok=false;
I=eye(3);
for i=1:n
    delta=x-O(:,i);
    rho=hypot(hypot(delta(1),delta(2)),delta(3));
    if ~isfinite(rho) || rho<=0
        return;
    end
    u=delta/rho;
    v=C(:,:,i)'*u;
    % Strict receiver forward-hemisphere. Reject the boundary strip
    % where the inverse signed-plane-angle Jacobian is ill-conditioned.
    if any(~isfinite(v)) || v(1)<=sqrt(32*eps)
        return;
    end
    va=max(-1,min(1,v(2)));
    vb=max(-1,min(1,v(3)));
    dena=sqrt(1-va*va);
    denb=sqrt(1-vb*vb);
    if dena<=sqrt(32*eps) || denb<=sqrt(32*eps)
        return;
    end
    rows=2*i-1:2*i;
    r(rows)=[asin(va)-a(i); asin(vb)-b(i)];
    P=I-u*u';
    J(rows,:)=[(C(:,2,i)'*P)/(rho*dena); ...
               (C(:,3,i)'*P)/(rho*denb)];
end
ok=all(isfinite(r)) && all(isfinite(J(:)));
end

function [ok,kappa_A]=condition_check(B,max_kappa)
ok=false;
kappa_A=Inf;
s=svd(B,0);
if numel(s)~=3 || any(~isfinite(s)) || s(1)<=0 || ...
        s(end)<=max(size(B))*eps(s(1))
    return;
end
ratio=s(1)/s(end);
kappa_A=ratio*ratio;
ok=isfinite(kappa_A) && kappa_A<max_kappa;
end

function ok=num(v)
ok=isa(v,'double') && isreal(v) && isscalar(v) && isfinite(v);
end
