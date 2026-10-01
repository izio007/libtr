function [status, ctx] = filter2win(cfg, ctx, current_time, X_meas_tick, is_nan_tick)
% FILTER2WIN Scalar autonomous two-window filter. docs/filter2win_theory.txt.
% status=1 leaves state unchanged; status=0 may produce an unavailable NaN.
status=1;
names={'N','S','R_MAX','R_ALT_MAX','T_PROLONGATION_MAX','T_TIMEOUT_CLEAR'};
if ~isstruct(cfg) || ~isscalar(cfg) || ~all(isfield(cfg,names)) || ...
        ~isstruct(ctx) || ~isscalar(ctx) || ~isfield(ctx,'X_MAIN_REF'), return; end
p=zeros(1,7);
for k=1:6
    v=cfg.(names{k});
    if ~isa(v,'double') || ~isreal(v) || ~isscalar(v) || ~isfinite(v) || v<=0, return; end
    p(k)=v;
end
if isfield(cfg,'V')
    if ~isa(cfg.V,'double') || ~isreal(cfg.V) || ~isscalar(cfg.V) || ~isfinite(cfg.V), return; end
    p(7)=cfg.V;
end
if p(1)~=fix(p(1)) || p(2)~=fix(p(2)) || p(2)<2, return; end
if ~isa(current_time,'double') || ~isreal(current_time) || ...
        ~isscalar(current_time) || ~isfinite(current_time), return; end
if ~isa(X_meas_tick,'double') || ~isreal(X_meas_tick) || ~isscalar(X_meas_tick), return; end
if ~(islogical(is_nan_tick) || isa(is_nan_tick,'double')) || ...
        ~isreal(is_nan_tick) || ~isscalar(is_nan_tick) || ...
        ~ismember(is_nan_tick,[0 1])
    return;
end
missing=logical(is_nan_tick) || isnan(X_meas_tick);
if ~missing && ~isfinite(X_meas_tick), return; end
if ~isa(ctx.X_MAIN_REF,'double') || ~isreal(ctx.X_MAIN_REF) || ...
        ~(isscalar(ctx.X_MAIN_REF) || isequal(size(ctx.X_MAIN_REF),[3 1])) || ...
        ~all(isfinite(ctx.X_MAIN_REF))
    return;
end
if isfield(ctx,'FILTER_STATE')
    s=ctx.FILTER_STATE;
    if ~isequal(s.parameters,p) || current_time<=s.last_tick, return; end
else
    s=struct('parameters',p,'epoch',current_time,'last_tick',-Inf, ...
        'last_accepted',current_time,'last_alt',-Inf,'anchor',ctx.X_MAIN_REF(1), ...
        'main',zeros(1,p(1)),'main_count',0,'alt',zeros(1,p(2)),'alt_count',0);
end
% Sections 3-5: residual coordinates and independent expiry clocks.
offset=p(7)*(current_time-s.epoch); prediction=s.anchor+offset;
if ~isfinite(offset) || ~isfinite(prediction), return; end
if current_time-s.last_alt>p(6), s.alt_count=0; end
if current_time-s.last_accepted>p(6), s.main_count=0; end
accepted=false; reacquired=false;
if ~missing
    q=X_meas_tick-offset;
    if ~isfinite(q), return; end
    if abs(X_meas_tick-prediction)<=p(3)
        if s.main_count==p(1)
            s.main(1:end-1)=s.main(2:end);
        else
            s.main_count=s.main_count+1;
        end
        s.main(s.main_count)=q;
        s.anchor=sum(s.main(1:s.main_count)/s.main_count);
        s.alt_count=0; accepted=true;
    else
        n=s.alt_count+1; s.alt(n)=q;
        center=sum(s.alt(1:n)/n);
        if max(abs(s.alt(1:n)-center))>p(4)
            s.alt(1)=q; n=1;
        end
        s.alt_count=n; s.last_alt=current_time;
        if n==p(2)
            s.main_count=min(p(1),n);
            s.main(1:s.main_count)=s.alt(n-s.main_count+1:n);
            s.anchor=sum(s.main(1:s.main_count)/s.main_count);
            s.alt_count=0; accepted=true; reacquired=true;
        end
    end
end
if ~isfinite(s.anchor) || ~isfinite(s.anchor+offset), return; end
if accepted, s.last_accepted=current_time; end
output=NaN;
if current_time-s.last_accepted<=p(5), output=s.anchor+offset; end
s.last_tick=current_time;
ctx.FILTER_STATE=s;
ctx.X_MAIN_REF(1)=s.anchor+offset;
ctx.X_FILTERED_OUTPUT=output;
ctx.W_ALT_POWER_OUTPUT=s.alt_count;
ctx.ACCEPTED=accepted;
ctx.REACQUIRED=reacquired;
status=0;
end