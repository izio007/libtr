function [status, ctx] = filter2win(cfg, ctx, current_time, X_meas_tick, is_nan_tick)
% FILTER2WIN Scalar autonomous two-window filter. docs/filter2win_theory.md.
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
    [~,main]=fifo_double('init',struct(),p(1),NaN);
    [~,alt]=fifo_double('init',struct(),p(2),NaN);
    s=struct('parameters',p,'epoch',current_time,'last_tick',-Inf, ...
        'last_accepted',current_time,'last_alt',-Inf,'anchor',ctx.X_MAIN_REF(1), ...
        'main',main,'alt',alt);
end
% Sections 3-5: residual coordinates and independent expiry clocks.
offset=p(7)*(current_time-s.epoch); prediction=s.anchor+offset;
if ~isfinite(offset) || ~isfinite(prediction), return; end
if current_time-s.last_alt>p(6), [~,s.alt]=fifo_double('clear',s.alt,NaN,NaN); end
if current_time-s.last_accepted>p(6), [~,s.main]=fifo_double('clear',s.main,NaN,NaN); end
accepted=false; reacquired=false;
if ~missing
    q=X_meas_tick-offset;
    if ~isfinite(q), return; end
    if abs(X_meas_tick-prediction)<=p(3)
        [~,s.main]=fifo_double('push',s.main,q,current_time);
        s.anchor=ring_mean(s.main);
        [~,s.alt]=fifo_double('clear',s.alt,NaN,NaN); accepted=true;
    else
        [~,s.alt]=fifo_double('push',s.alt,q,current_time);
        center=ring_mean(s.alt);
        if ~isfinite(center), return; end
        compact=true;
        for j=1:s.alt.count
            [~,~,candidate]=fifo_double('get',s.alt,j,NaN);
            if abs(candidate-center)>p(4), compact=false; break; end
        end
        if ~compact
            [~,s.alt]=fifo_double('clear',s.alt,NaN,NaN);
            [~,s.alt]=fifo_double('push',s.alt,q,current_time);
        end
        s.last_alt=current_time;
        if s.alt.count==p(2)
            [~,s.main]=fifo_double('clear',s.main,NaN,NaN);
            for j=max(1,s.alt.count-p(1)+1):s.alt.count
                [~,~,candidate,candidate_time]=fifo_double('get',s.alt,j,NaN);
                [~,s.main]=fifo_double('push',s.main,candidate,candidate_time);
            end
            s.anchor=ring_mean(s.main);
            [~,s.alt]=fifo_double('clear',s.alt,NaN,NaN);
            accepted=true; reacquired=true;
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
ctx.W_ALT_POWER_OUTPUT=s.alt.count;
ctx.ACCEPTED=accepted;
ctx.REACQUIRED=reacquired;
status=0;
end

function center=ring_mean(window)
center=0;
for j=1:window.count
    [~,~,value]=fifo_double('get',window,j,NaN);
    center=center+value/window.count;
end
end