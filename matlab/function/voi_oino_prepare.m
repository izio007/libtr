function [rc, out] = voi_oino_prepare(raw, windows, kappa_max, allow_extrapolation)
%VOI_OINO_PREPARE Join OINO angle functionals without discarding correlation.
% This is a value-and-covariance preparation step, NOT position estimation.
%
% RAW: sample_id, t_obs, y (n-by-1 numeric angle observations in radians),
%      Sigma (FULL n-by-n covariance of centred raw observation errors).
% Each WINDOWS(i) defines one prepared a,b pair:
%  t_target, origin(3,1), C(3,3) for the SAME target epoch;
%  a and b are structs with idx (indices in raw rows, may OVERLAP across
%  windows), F, G, L of a scalar OINO functional L'*theta at t_target.
% Construct F/G at the ACTUAL raw.t_obs(idx) independently for each channel.
% idx may share original rows between outputs. All cross-covariances are
% preserved by using one global raw covariance matrix and global weights.
%
% OUTPUT: accepted chronological bearings; covariance matrix with order
% [a1;b1;a2;b2;...], raw weights, and original sample IDs.
% The caller must not substitute a block-diagonal covariance afterward.
% By default, evaluation outside the corresponding observation window is
% refused; optional extrapolation is an EXPLICIT modelling assumption.

rc=1;
out=struct('available',false,'reason','INVALID_API','bearings',struct([]), ...
    'Sigma',NaN,'weights',NaN,'raw_sample_id',NaN,'count',0);
if nargin~=4 || ~isstruct(raw) || ~isscalar(raw) || ...
        ~isstruct(windows) || ~isvector(windows) || ...
        ~isa(kappa_max,'double') || ~isscalar(kappa_max) || ...
        ~isfinite(kappa_max) || kappa_max<=1 || ...
        ~islogical(allow_extrapolation) || ~isscalar(allow_extrapolation)
    return;
end
required={'sample_id','t_obs','y','Sigma'};
if ~all(isfield(raw,required))
    out.reason='RAW_FIELDS'; return;
end
ids=raw.sample_id;
times=raw.t_obs;
y=raw.y;
S=raw.Sigma;
n=numel(y);
if n<1 || ~realmat(ids) || ~realmat(times) || ~realmat(y) || ...
        ~iscolumn(ids) || ~iscolumn(times) || ~iscolumn(y) || ...
        numel(ids)~=n || numel(times)~=n || any(ids<=0) || ...
        any(ids~=fix(ids)) || numel(unique(ids))~=n || ...
        any(diff(times)<0) || ...
        ~realmat(S) || ~isequal(size(S),[n,n]) || ...
        norm(S-S','fro') > 64*n*eps(norm(S,'fro'))
    out.reason='INVALID_RAW_DATA'; return;
end
try
    [~,cholflag]=chol((S+S')/2);
catch
    out.reason='INVALID_RAW_COVARIANCE'; return;
end
if cholflag~=0
    out.reason='INVALID_RAW_COVARIANCE'; return;
end
m=numel(windows);
if m<1
    out.reason='EMPTY_WINDOWS'; return;
end
bears=repmat(struct('m',1,'t_obs',NaN,'a',NaN,'b',NaN, ...
    'origin',NaN(3,1),'C',NaN(3,3),'nav_status',1),1,m);
W=zeros(n,2*m);
for i=1:m
    w=windows(i);
    if ~isfield(w,'t_target') || ~isfield(w,'origin') || ...
            ~isfield(w,'C') || ~isfield(w,'a') || ~isfield(w,'b') || ...
            ~num(w.t_target) || ~realmat(w.origin) || ...
            ~isequal(size(w.origin),[3,1]) || ...
            ~realmat(w.C) || ~isequal(size(w.C),[3,3]) || ...
            ~isstruct(w.a) || ~isscalar(w.a) || ...
            ~isstruct(w.b) || ~isscalar(w.b) || ...
            (i>1 && w.t_target<bears(i-1).t_obs)
        out.reason='INVALID_WINDOW_POSE_OR_TIME'; return;
    end
    [ok,wa,reason]=one_channel(raw,w.a,w.t_target, ...
        kappa_max,allow_extrapolation);
    if ~ok
        out.reason=['A_' reason]; return;
    end
    [ok,wb,reason]=one_channel(raw,w.b,w.t_target, ...
        kappa_max,allow_extrapolation);
    if ~ok
        out.reason=['B_' reason]; return;
    end
    W(:,2*i-1)=wa;
    W(:,2*i)=wb;
    vals=W(:,2*i-1:2*i)'*y;
    [status,~,geo]=voi_direction(vals(1),vals(2),w.C);
    if status~=1
        out.reason=['PREPARED_GEOMETRY_' geo.reason]; return;
    end
    bears(i).t_obs=w.t_target;
    bears(i).a=vals(1);
    bears(i).b=vals(2);
    bears(i).origin=w.origin;
    bears(i).C=w.C;
end
Sp=W'*S*W;
Sp=(Sp+Sp')/2;
if any(~isfinite(Sp(:)))
    out.reason='NONFINITE_OUTPUT_COVARIANCE'; return;
end
% Identical outputs may be linearly dependent. Do not regularize a
% covariance singularity and then claim more independent information.
try
    [~,flag]=chol(Sp);
catch
    out.reason='PREPARED_COVARIANCE_NOT_SPD'; return;
end
if flag~=0
    out.reason='PREPARED_COVARIANCE_NOT_SPD'; return;
end
out.available=true;
out.reason='OK';
out.bearings=bears;
out.Sigma=Sp;
out.weights=W;
out.raw_sample_id=ids;
out.count=m;
rc=0;
end

function [ok,w,reason]=one_channel(raw,channel,t_target,kappa,extrap)
ok=false;
w=zeros(numel(raw.y),1);
reason='INVALID_CHANNEL';
fields={'idx','F','G','L'};
if ~all(isfield(channel,fields)) || ...
        ~realmat(channel.idx) || ~isvector(channel.idx) || ...
        isempty(channel.idx) || any(channel.idx~=fix(channel.idx)) || ...
        any(channel.idx<1) || any(channel.idx>numel(raw.y)) || ...
        numel(unique(channel.idx))~=numel(channel.idx)
    return;
end
idx=channel.idx(:);
t=raw.t_obs(idx);
if any(diff(t)<0)
    reason='UNSORTED_WINDOW'; return;
end
if ~extrap && (t_target<t(1) || t_target>t(end))
    reason='EXTRAPOLATION_NOT_ALLOWED'; return;
end
[code,estimate]=voi_oino_linear(t,raw.y(idx),channel.F, ...
    channel.G,raw.Sigma(idx,idx),channel.L,kappa);
if code~=0 || ~estimate.available
    reason=['OINO_' estimate.reason]; return;
end
if ~isscalar(estimate.estimate) || size(estimate.weights,2)~=1
    reason='EXPECTED_SCALAR_FUNCTIONAL'; return;
end
w(idx)=estimate.weights;
ok=true;
reason='OK';
end

function ok=realmat(v)
ok=isa(v,'double') && isreal(v) && ~issparse(v) && ...
    all(isfinite(v(:)));
end
function ok=num(v)
ok=isa(v,'double') && isreal(v) && isscalar(v) && isfinite(v);
end
