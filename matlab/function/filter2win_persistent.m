function [rc,ctx,debug]=filter2win_persistent(c,ctx,t,x,missing)
% Schema 3. A=main and B=alt retain identity; active only selects output.
% This entry is called by filter2win; all writes are local until publication.
rc=1; debug=struct('api_status',1,'reason','INVALID_INPUT','time',t);
[ok,why]=filter2win_validate_persistent(c);
if ~ok, debug.reason=why; return; end
if ~isstruct(ctx) || ~isscalar(ctx) || ~finite(t) || ...
        ~isa(x,'double') || ~isreal(x) || ~isscalar(x) || ...
        ~(islogical(missing) || isa(missing,'double')) || ...
        ~isreal(missing) || ~isscalar(missing) || ~ismember(missing,[0 1]), return; end
missing=logical(missing) || isnan(x);
if ~missing && ~isfinite(x), return; end
if isfield(ctx,'X_MAIN_REF') && (~isa(ctx.X_MAIN_REF,'double') || ~isreal(ctx.X_MAIN_REF) || ...
        ~(isscalar(ctx.X_MAIN_REF) || isequal(size(ctx.X_MAIN_REF),[3 1])) || ...
        ~all(isfinite(ctx.X_MAIN_REF))), return; end
if isfield(ctx,'FILTER_STATE')
    s=ctx.FILTER_STATE;
    if ~valid_state(s,c), debug.reason='INVALID_STATE_OR_RECONFIGURATION'; return; end
    if t<=s.last_tick, debug.reason='NONINCREASING_TIME'; return; end
    if ~isfinite(t-s.last_tick), debug.reason='TIME_ARITHMETIC_OVERFLOW'; return; end
else
    s=initial(c,t);
end
before=s; names={'main','alt'};
v=[view(s.main,c.main),view(s.alt,c.alt)];
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
[s,status,rule,blocked,checks]=select(s,c,g,t,missing);
if status==14 && strcmp(event,'SWITCH_READY')
    duration=c.handover.duration_seconds;
    if g.route==1, duration=c.handover.return_duration_seconds; end
    if duration==0 || (~hold && ~isfinite(before.last_output)), status=6; end
end
if status==14 && s.status==14 && ~strcmp(event,'SWITCH_READY') && g.blend_elapsed>=s.blend_duration
    status=6;
end
s.status=status; s.tact=s.tact+1;
accepted=false; switched=false; output=NaN; weight=NaN;
reason=event;
% s.status selects the only numerical action. Guards above are read-only
% trial calculations; no failed proposal can evict or delete real history.
switch s.status
    case {1,3,4} % Initial/candidate accumulation, no output from unready base.
        s=commit(s,p,g.route,names); accepted=p.accepted;
        output=held(before,v,t,hold); reason='COLLECTING_NOT_USED';
    case {2,13} % Current window or first ready model.
        s=commit(s,p,g.route,names); accepted=p.accepted;
        if ~p.accepted || ~p.stats.ready, debug.reason='POLICY_REQUIRES_READY_PROPOSAL'; return; end
        switched=s.active~=g.route; s.active=g.route;
        s.last_accept(g.route)=t;
        output=predict(p.stats.model,t); reason='WINDOW_ACCEPTED';
        if s.status==13, reason='INITIAL_BASE_READY'; end
    case 6 % Selection or end of a smooth transition. Never copy A into B.
        s=commit(s,p,g.route,names); accepted=p.accepted;
        if strcmp(event,'SWITCH_READY')
            if ~p.accepted || ~p.stats.ready, debug.reason='POLICY_REQUIRES_READY_PROPOSAL'; return; end
            switched=s.active~=g.route; s.active=g.route; s.last_accept(g.route)=t;
            reason='READY_WINDOW_SELECTED';
        else
            reason='TRANSITION_COMPLETE';
            if accepted && g.route==s.active, s.last_accept(s.active)=t; end
        end
        if s.active==0, debug.reason='POLICY_REQUIRES_ACTIVE_WINDOW'; return; end
        active=view(s.(names{s.active}),c.(names{s.active}));
        if active.ready, output=predict(active.model,t); end
        weight=1;
    case 14 % Interpolation is presentation only, never FIFO input.
        if strcmp(event,'SWITCH_READY')
            if ~p.accepted || ~p.stats.ready || s.active==0, debug.reason='POLICY_REQUIRES_TWO_WINDOWS'; return; end
            from=held(before,v,t,hold);
            if ~isfinite(from), from=before.last_output; end
            s.blend_from=from; s.blend_start=t; s.blend_elapsed=0;
            s.blend_duration=c.handover.duration_seconds;
            if g.route==1, s.blend_duration=c.handover.return_duration_seconds; end
            switched=s.active~=g.route; s.active=g.route; s.last_accept(g.route)=t;
        else
            s.blend_elapsed=g.blend_elapsed;
        end
        s=commit(s,p,g.route,names); accepted=p.accepted;
        if accepted && g.route==s.active && p.stats.ready, s.last_accept(s.active)=t; end
        active=view(s.(names{s.active}),c.(names{s.active}));
        weight=min(1,max(0,s.blend_elapsed/s.blend_duration));
        if strcmp(c.handover.curve,'smoothstep'), weight=weight*weight*(3-2*weight); end
        output=(1-weight)*s.blend_from+weight*predict(active.model,t);
        reason='TRANSITION_IN_PROGRESS';
        if ~missing && ~p.accepted, reason=p.reason; end
    case {5,10,11}
        output=held(before,v,t,hold);
        if g.route>0, reason=p.reason; else, reason='OUTSIDE_BOTH_READY_WINDOWS'; end
    case 7
        output=held(before,v,t,hold); reason='GAP_WITH_MEMORY_RETAINED';
    case {0,8,12}
        reason='OUTPUT_UNAVAILABLE_MEMORY_RETAINED';
    case 15
        % A policy may postpone selection, not discard accepted evidence.
        s=commit(s,p,g.route,names); accepted=p.accepted;
        output=held(before,v,t,hold); reason='TRANSITION_POLICY_PENDING';
        if g.main_hold, reason='MAIN_PROLONGATION_ACTIVE'; end
    otherwise
        debug.reason='INVALID_DESTINATION'; return;
end
if s.status~=14
    s.blend_duration=0; s.blend_elapsed=0; s.blend_from=NaN; s.blend_start=NaN;
end
after=[view(s.main,c.main),view(s.alt,c.alt)];
if s.active>0 && ~after(s.active).ready
    s.active=0; output=NaN;
    if ismember(s.status,[2 6 13 14])
        s.status=1; if g.route==2, s.status=4; end
        s.blend_duration=0; s.blend_elapsed=0; s.blend_from=NaN; s.blend_start=NaN;
        reason='BASE_NO_LONGER_READY_AFTER_REMOVAL';
    end
end
if ~isnan(output) && ~isfinite(output), debug.reason='NUMERIC_OUTPUT_OVERFLOW'; return; end
s.last_supported=accepted && s.active==g.route && s.active>0 && after(s.active).ready;
if ~missing, s.last_input=t; end
s.last_tick=t; s.last_output=output;
if s.status~=before.status, s.status_since=t; end
s.primary=empty_model;
if s.active>0, s.primary=after(s.active).model; end
removed=struct('time',[],'value',[]); evicted=removed;
if accepted, removed=p.removed; evicted=p.evicted; end
debug=struct('api_status',0,'schema_version',3,'reason',reason,'tact',s.tact,'time',t, ...
    'measurement',x,'missing',missing,'previous_status',before.status, ...
    'status',s.status,'status_name',filter2win_status_name(s.status,3), ...
    'active_before',before.active,'active_window',s.active,'route',g.route, ...
    'accepted',accepted,'reacquired',switched,'valid',isfinite(output),'output',output, ...
    'main_before',before.main.count,'main_count',s.main.count, ...
    'alt_before',before.alt.count,'alt_count',s.alt.count,'windows',after, ...
    'removed',removed,'evicted',evicted,'rule',rule,'event',event, ...
    'blocked_rules',{blocked},'rule_checks',checks,'blend_weight',weight,'guards',g);
ctx.FILTER_STATE=s; ctx.FILTER_STATUS=s.status; ctx.FILTER_VALID=isfinite(output);
ctx.X_FILTERED_OUTPUT=output; ctx.W_ALT_POWER_OUTPUT=s.alt.count;
ctx.ACCEPTED=accepted; ctx.REACQUIRED=switched; ctx.FILTER_DEBUG=debug;
if isfinite(output)
    if ~isfield(ctx,'X_MAIN_REF'), ctx.X_MAIN_REF=output; else, ctx.X_MAIN_REF(1)=output; end
end
rc=0;
end

function s=initial(c,t)
[~,a]=fifo_double('init',[],c.main.capacity); [~,b]=fifo_double('init',[],c.alt.capacity);
s=struct('schema_version',3,'parameters',c,'main',a,'alt',b,'active',0, ...
    'primary',empty_model,'status',0,'status_since',t,'tact',0,'last_tick',-Inf, ...
    'last_input',-Inf,'last_accept',[-Inf -Inf],'last_supported',false,'last_output',NaN, ...
    'pending_window',0,'pending_since',NaN,'blend_from',NaN,'blend_start',NaN, ...
    'blend_duration',0,'blend_elapsed',0, ...
    'rule_since',NaN(1,numel(c.rules)),'rule_hits',zeros(1,numel(c.rules)));
end
function m=empty_model
m=filter2win_model(struct('time',[],'value',[]),'constant');
end
function v=view(q,w)
[~,~,d]=fifo_double('read',q); m=filter2win_model(d,w);
span=0; if q.count>1, span=d.time(end)-d.time(1); end
range=m.max_residual-m.min_residual;
quality=isfinite(m.level) && isfinite(m.velocity) && isfinite(m.mad) && ...
    isfinite(range) && m.mad<=w.band.max_mad && range<=w.band.max_range && ...
    abs(m.velocity)<=w.band.max_abs_velocity;
v=struct('count',q.count,'span',span,'range',range,'quality',quality, ...
    'ready',quality && q.count>=w.min_samples && span>=w.min_span_seconds,'model',m);
end
function p=empty_proposal
p=struct('accepted',false,'reason','NO_PROPOSAL','queue',[], ...
    'removed',struct('time',[],'value',[]),'evicted',struct('time',[],'value',[]), ...
    'threshold',NaN,'new_residual',NaN,'stats',struct('count',0,'span',0, ...
    'range',NaN,'quality',false,'ready',false,'model',empty_model));
end
function p=propose(q,w,t,x,was_ready)
p=empty_proposal;
[code,trial]=fifo_double('push',q,t,x);
if code~=0, p.reason='FIFO_REFUSED'; return; end
[~,~,d]=fifo_double('read',trial); p.stats=view(trial,w); raw=p.stats.model;
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
p.stats=view(trial,w);
if was_ready && ~p.stats.quality, p.reason='PROPOSED_SPREAD_REJECTED'; return; end
p.queue=trial; p.accepted=true; p.reason='PROPOSAL_ACCEPTED';
end
function s=commit(s,p,route,names)
if p.accepted && route>0
    s.(names{route})=p.queue;
end
end
function x=predict(m,t)
x=m.level+m.velocity*(t-m.last);
end
function output=held(s,v,t,allowed)
output=NaN;
if ~allowed || s.active==0, return; end
if s.status==14
    output=s.last_output; % A paused/rejected step never advances the blend.
else
    output=predict(v(s.active).model,t);
end
end
function [s,status,name,blocked,checks]=select(s,c,g,t,missing)
status=15; name='NO_ELIGIBLE_RULE'; blocked={};
checks=struct('metric',{},'actual',{},'operator',{},'threshold',{},'passed',{});
priority=-Inf;
for k=1:numel(c.rules)
    r=c.rules(k); matches=r.enabled && (isempty(r.from) || ismember(s.status,r.from)) && ...
        (strcmp(r.event,g.event) || strcmp(r.event,'FALLBACK'));
    [passed,detail]=filter2win_rule_checks(r,g.metrics);
    matches=matches && passed;
    if matches
        if isnan(s.rule_since(k)), s.rule_since(k)=t; end
        s.rule_hits(k)=s.rule_hits(k)+1;
        eligible=s.rule_hits(k)>=r.confirm_ticks && t-s.rule_since(k)>=r.confirm_seconds && ...
            t-s.status_since>=r.min_dwell_seconds;
        if eligible && r.priority>priority
            status=r.to; name=r.name; priority=r.priority; checks=detail;
        elseif ~eligible
            blocked{end+1}=struct('name',r.name,'hits',s.rule_hits(k), ...
                'required_hits',r.confirm_ticks,'seconds',t-s.rule_since(k), ...
                'required_seconds',r.confirm_seconds,'dwell',t-s.status_since, ...
                'required_dwell',r.min_dwell_seconds,'checks',detail); %#ok<AGROW>
        end
    elseif ~missing
        s.rule_since(k)=NaN; s.rule_hits(k)=0;
    end
end
end
function ok=valid_state(s,c)
fields={'schema_version','parameters','main','alt','active','status','status_since','tact', ...
    'last_tick','last_input','last_accept','last_supported','last_output','pending_window', ...
    'pending_since','blend_from','blend_start','blend_duration','blend_elapsed','rule_since','rule_hits'};
ok=isstruct(s) && isscalar(s) && all(isfield(s,fields));
if ~ok, return; end
ok=isequal(s.schema_version,3) && isequaln(s.parameters,c) && integer(s.active,0,2) && ...
    integer(s.pending_window,0,2) && integer(s.status,0,15) && s.status~=9 && ...
    integer(s.tact,0,flintmax) && finite(s.last_tick) && finite(s.status_since) && ...
    s.status_since<=s.last_tick && finite(s.blend_duration) && s.blend_duration>=0 && ...
    finite(s.blend_elapsed) && s.blend_elapsed>=0 && ...
    islogical(s.last_supported) && isscalar(s.last_supported);
if ~ok, return; end
for f={'last_input','last_output','pending_since','blend_from','blend_start'}
    a=s.(f{1});
    if ~isa(a,'double') || ~isreal(a) || ~isscalar(a), ok=false; return; end
end
if ~(isfinite(s.last_input) || s.last_input==-Inf) || s.last_input>s.last_tick || ...
        ~(isfinite(s.last_output) || isnan(s.last_output)), ok=false; return; end
if ~isa(s.last_accept,'double') || ~isreal(s.last_accept) || ...
        ~isequal(size(s.last_accept),[1 2]) || any(isnan(s.last_accept) | s.last_accept>s.last_tick), ok=false; return; end
if s.pending_window>0 && (~isfinite(s.pending_since) || s.pending_since>s.last_tick), ok=false; return; end
if s.status==14 && (s.active==0 || ~finite(s.blend_from) || ...
        ~finite(s.blend_start) || s.blend_start>s.last_tick || s.blend_duration<=0), ok=false; return; end
if ~isa(s.rule_hits,'double') || ~isreal(s.rule_hits) || ...
        ~isequal(size(s.rule_hits),[1 numel(c.rules)]) || ...
        any(~isfinite(s.rule_hits) | s.rule_hits<0 | s.rule_hits~=fix(s.rule_hits)) || ...
        ~isa(s.rule_since,'double') || ~isreal(s.rule_since) || ...
        ~isequal(size(s.rule_since),[1 numel(c.rules)]) || ...
        any(~isnan(s.rule_since) & (~isfinite(s.rule_since) | s.rule_since>s.last_tick)), ok=false; return; end
[a,~,~]=fifo_double('read',s.main); [b,~,~]=fifo_double('read',s.alt);
ok=a==0 && b==0;
if ~ok, return; end
ok=s.main.capacity==c.main.capacity && s.alt.capacity==c.alt.capacity && ...
    s.main.last_time<=s.last_tick && s.alt.last_time<=s.last_tick;
end
function ok=finite(x)
ok=isa(x,'double') && isreal(x) && isscalar(x) && isfinite(x);
end
function ok=integer(x,lo,hi)
ok=finite(x) && x>=lo && x<=hi && x==fix(x);
end
