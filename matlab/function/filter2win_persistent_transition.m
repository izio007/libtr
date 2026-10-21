function [s,step]=filter2win_persistent_transition(c,s,t,x,missing)
% Schema 3 routing, trial proposal, time guards, and fixed transition choice.
% Pending clocks change only in local state; real FIFO changes are actions.
before=s; names={'main','alt'};
v=[filter2win_window_view(s.main,c.main),filter2win_window_view(s.alt,c.alt)];
g=struct('route',0,'distance',[Inf Inf],'prediction',[NaN NaN], ...
    'lower',[NaN NaN],'upper',[NaN NaN],'before',v, ...
    'wait_elapsed',0,'blend_elapsed',s.blend_elapsed,'age',Inf,'window_config',struct());
p=empty_proposal;
if ~missing
    for k=1:2
        if v(k).ready
            w=c.(names{k}); m=v(k).model;
            g.prediction(k)=predict(m,t);
            residual=x-g.prediction(k);
            adaptive=min(w.band.max_adaptive_radius,w.band.mad_multiplier*max(w.band.mad_floor,m.mad));
            growth=w.band.growth_per_second*(t-m.last);
            g.lower(k)=max(w.band.lower_margin,adaptive)+growth;
            g.upper(k)=max(w.band.upper_margin,adaptive)+growth;
            radius=g.upper(k); if residual<0, radius=g.lower(k); end
            if residual==0
                g.distance(k)=0;
            elseif isfinite(residual) && isfinite(radius) && radius>0
                g.distance(k)=abs(residual)/radius;
            end
        end
    end
    eligible=find(g.distance<=1);
    if numel(eligible)==1
        g.route=eligible;
    elseif numel(eligible)==2
        if g.distance(1)==g.distance(2) && s.active>0
            g.route=s.active;
        else
            [~,g.route]=min(g.distance);
        end
    else
        % An unready hypothesis is not anchored by its first bad sample.
        g.route=find(~[v.ready],1);
        if isempty(g.route), g.route=0; end
    end
    if g.route>0
        g.window_config=c.(names{g.route});
        p=propose(s.(names{g.route}),c.(names{g.route}),t,x,v(g.route).ready);
        if p.accepted && g.route~=s.active
            if s.pending_window~=g.route
                s.pending_window=g.route; s.pending_since=t;
            end
            g.wait_elapsed=t-s.pending_since;
        elseif p.accepted && g.route==s.active
            s.pending_window=0; s.pending_since=NaN;
        end
    end
end
if s.active>0
    g.age=t-s.last_accept(s.active);
end
limit=c.flow.outlier_hold_seconds;
if missing, limit=c.flow.gap_hold_seconds; end
g.hold_limit=limit;
hold=s.active>0 && v(s.active).ready && g.age<=limit;
g.main_hold=s.active==1 && g.route==2 && hold;
if s.status==14
    advance=missing && strcmp(c.handover.on_missing,'continue');
    if p.accepted && g.route==s.active
        advance=strcmp(c.handover.on_missing,'continue') || s.last_supported;
    end
    if advance, g.blend_elapsed=s.blend_elapsed+t-s.last_tick; end
end
g.proposal=p;
g.metrics=struct('count',p.stats.count,'span',p.stats.span,'mad',p.stats.model.mad, ...
    'range',p.stats.range,'abs_velocity',abs(p.stats.model.velocity), ...
    'residual_abs',NaN,'age',g.age,'wait_elapsed',g.wait_elapsed,'blend_elapsed',g.blend_elapsed);
if g.route>0, g.metrics.residual_abs=abs(x-g.prediction(g.route)); end
if missing
    if s.active==0
        event='WARMUP_MISSING';
        if s.main.count+s.alt.count==0, event='EMPTY_MISSING'; end
    elseif ~hold || (s.status==14 && strcmp(c.handover.on_missing,'cancel'))
        event='GAP_EXPIRED';
    elseif s.status==14
        event='BLEND_ACTIVE';
    else
        event='GAP_HOLD';
    end
elseif p.accepted && p.stats.ready
    if s.active==0
        event='INITIAL_READY';
    elseif g.route~=s.active
        wait=c.handover.wait_seconds;
        if g.route==1, wait=c.handover.return_wait_seconds; end
        if g.wait_elapsed>=wait && ~g.main_hold, event='SWITCH_READY'; else, event='SWITCH_WAIT'; end
    elseif s.status==14
        event='BLEND_ACTIVE';
    else
        event='ACTIVE_ACCEPT';
    end
elseif s.status==14 && hold
    event='BLEND_ACTIVE';
elseif p.accepted
    event='ALT_ACCUMULATE';
    if s.active>0 && v(g.route).count==0, event='OUTLIER_HOLD'; end
    if g.route==1 && s.active==0, event='MAIN_ACCUMULATE'; end
elseif g.route>0
    event='QUALITY_REJECT';
    if s.active==0, event='WARMUP_REJECTED'; end
else
    event='OUTSIDE_BOTH';
end
g.event=event;
status=status_for_event(event);
if status==14 && strcmp(event,'SWITCH_READY')
    duration=c.handover.duration_seconds;
    if g.route==1, duration=c.handover.return_duration_seconds; end
    if duration==0 || (~hold && ~isfinite(before.last_output)), status=6; end
end
if status==14 && s.status==14 && ~strcmp(event,'SWITCH_READY') && g.blend_elapsed>=s.blend_duration
    status=6;
end
step=struct('time',t,'measurement',x,'missing',missing,'before',before, ...
    'status',status,'guards',g,'hold',hold);
end

function p=empty_proposal
p=struct('accepted',false,'reason','NO_PROPOSAL','queue',[], ...
    'removed',struct('time',[],'value',[]),'evicted',struct('time',[],'value',[]), ...
    'threshold',NaN,'new_residual',NaN,'stats',struct('count',0,'span',0, ...
    'range',NaN,'quality',false,'ready',false,'model',filter2win_model(struct('time',[],'value',[]),'constant')));
end

function p=propose(q,w,t,x,was_ready)
p=empty_proposal;
[code,trial]=fifo_double('push',q,t,x);
if code~=0, p.reason='FIFO_REFUSED'; return; end
[~,~,d]=fifo_double('read',trial); p.stats=filter2win_window_view(trial,w); raw=p.stats.model;
if q.count==q.capacity, [~,~,p.evicted]=fifo_double('peek',q); end
keep=true(1,trial.count);
if trial.count>=w.trim.min_samples && isfinite(raw.level)
    residual=d.value-(raw.level+raw.velocity*(d.time-raw.last));
    p.threshold=w.trim.k*max(w.trim.scale_floor,w.trim.mad_scale*raw.mad);
    if ~isfinite(p.threshold) || any(~isfinite(residual)), p.reason='NUMERIC_PROPOSAL_REJECTED'; return; end
    p.new_residual=residual(end);
    keep=abs(residual)<=p.threshold;
    if ~keep(end), p.reason='NEW_POINT_OUTLIER'; return; end
    p.removed=struct('time',d.time(~keep),'value',d.value(~keep));
    [code,trial]=fifo_double('retain',trial,keep);
    if code~=0, p.reason='FIFO_RETAIN_REFUSED'; return; end
end
p.stats=filter2win_window_view(trial,w);
if was_ready && ~p.stats.quality, p.reason='PROPOSED_SPREAD_REJECTED'; return; end
p.queue=trial; p.accepted=true; p.reason='PROPOSAL_ACCEPTED';
end

function x=predict(m,t)
x=m.level+m.velocity*(t-m.last);
end

function status=status_for_event(event)
% Fixed transition policy; hold/handover timing is evaluated above.
switch event
    case 'EMPTY_MISSING', status=0;
    case 'WARMUP_MISSING', status=12;
    case 'GAP_HOLD', status=7;
    case 'GAP_EXPIRED', status=8;
    case 'QUALITY_REJECT', status=5;
    case 'OUTSIDE_BOTH', status=10;
    case 'MAIN_ACCUMULATE', status=1;
    case 'ALT_ACCUMULATE', status=4;
    case 'INITIAL_READY', status=13;
    case 'ACTIVE_ACCEPT', status=2;
    case {'SWITCH_READY','BLEND_ACTIVE'}, status=14;
    case 'OUTLIER_HOLD', status=3;
    case 'WARMUP_REJECTED', status=11;
    otherwise, status=15; % SWITCH_WAIT or no actionable event.
end
end
