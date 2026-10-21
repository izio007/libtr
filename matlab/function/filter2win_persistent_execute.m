function [rc,ctx,debug]=filter2win_persistent_execute(c,ctx,s,step,debug)
% Schema 3 actions. Select one executor, then publish the completed local step.
rc=1;
t=step.time; x=step.measurement; missing=step.missing;
before=step.before; g=step.guards; p=g.proposal; event=g.event;
s.status=step.status; s.tact=s.tact+1;
r=struct('accepted',false,'switched',false,'output',NaN,'weight',NaN,'reason',event,'error','');
switch s.status
    case {1,3,4}
        [s,r]=action_accumulate(s,step,r);
    case {2,13}
        [s,r]=action_track(s,step,r);
    case 6
        [s,r]=action_switch(s,c,step,r);
    case 14
        [s,r]=action_blend(s,c,step,r);
    case {5,10,11}
        [s,r]=action_reject(s,step,r);
    case 7
        [s,r]=action_hold(s,step,r);
    case {0,8,12}
        [s,r]=action_unavailable(s,r);
    case 15
        [s,r]=action_wait(s,step,r);
    otherwise
        r.error='INVALID_DESTINATION';
end
if ~isempty(r.error), debug.reason=r.error; return; end
accepted=r.accepted; switched=r.switched; output=r.output; weight=r.weight; reason=r.reason;
if s.status~=14
    s.blend_duration=0; s.blend_elapsed=0; s.blend_from=NaN; s.blend_start=NaN;
end
after=[filter2win_window_view(s.main,c.main),filter2win_window_view(s.alt,c.alt)];
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
s.primary=filter2win_model(struct('time',[],'value',[]),'constant');
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
    'removed',removed,'evicted',evicted,'event',event, ...
    'blend_weight',weight,'guards',g);
ctx.FILTER_STATE=s; ctx.FILTER_STATUS=s.status; ctx.FILTER_VALID=isfinite(output);
ctx.X_FILTERED_OUTPUT=output; ctx.W_ALT_POWER_OUTPUT=s.alt.count;
ctx.ACCEPTED=accepted; ctx.REACQUIRED=switched; ctx.FILTER_DEBUG=debug;
if isfinite(output)
    if ~isfield(ctx,'X_MAIN_REF'), ctx.X_MAIN_REF=output; else, ctx.X_MAIN_REF(1)=output; end
end
rc=0;
end

function [s,r]=action_accumulate(s,step,r)
g=step.guards; p=g.proposal;
before=step.before; v=g.before; t=step.time; hold=step.hold;
s=commit(s,p,g.route); r.accepted=p.accepted;
r.output=held(before,v,t,hold); r.reason='COLLECTING_NOT_USED';
end

function [s,r]=action_track(s,step,r)
g=step.guards; p=g.proposal; t=step.time;
s=commit(s,p,g.route); r.accepted=p.accepted;
if ~p.accepted || ~p.stats.ready, r.error='STATE_REQUIRES_READY_PROPOSAL'; return; end
r.switched=s.active~=g.route; s.active=g.route;
s.last_accept(g.route)=t;
r.output=predict(p.stats.model,t); r.reason='WINDOW_ACCEPTED';
if s.status==13, r.reason='INITIAL_BASE_READY'; end
end

function [s,r]=action_switch(s,c,step,r)
g=step.guards; p=g.proposal; t=step.time; event=g.event; names={'main','alt'};
s=commit(s,p,g.route); r.accepted=p.accepted;
if strcmp(event,'SWITCH_READY')
    if ~p.accepted || ~p.stats.ready, r.error='STATE_REQUIRES_READY_PROPOSAL'; return; end
    r.switched=s.active~=g.route; s.active=g.route; s.last_accept(g.route)=t;
    r.reason='READY_WINDOW_SELECTED';
else
    r.reason='TRANSITION_COMPLETE';
    if r.accepted && g.route==s.active, s.last_accept(s.active)=t; end
end
if s.active==0, r.error='STATE_REQUIRES_ACTIVE_WINDOW'; return; end
active=filter2win_window_view(s.(names{s.active}),c.(names{s.active}));
if active.ready, r.output=predict(active.model,t); end
r.weight=1;
end

function [s,r]=action_blend(s,c,step,r)
g=step.guards; p=g.proposal; before=step.before; v=g.before;
t=step.time; missing=step.missing; hold=step.hold; event=g.event; names={'main','alt'};
if strcmp(event,'SWITCH_READY')
    if ~p.accepted || ~p.stats.ready || s.active==0, r.error='STATE_REQUIRES_TWO_WINDOWS'; return; end
    from=held(before,v,t,hold);
    if ~isfinite(from), from=before.last_output; end
    s.blend_from=from; s.blend_start=t; s.blend_elapsed=0;
    s.blend_duration=c.handover.duration_seconds;
    if g.route==1, s.blend_duration=c.handover.return_duration_seconds; end
    r.switched=s.active~=g.route; s.active=g.route; s.last_accept(g.route)=t;
else
    s.blend_elapsed=g.blend_elapsed;
end
s=commit(s,p,g.route); r.accepted=p.accepted;
if r.accepted && g.route==s.active && p.stats.ready, s.last_accept(s.active)=t; end
active=filter2win_window_view(s.(names{s.active}),c.(names{s.active}));
r.weight=min(1,max(0,s.blend_elapsed/s.blend_duration));
if strcmp(c.handover.curve,'smoothstep'), r.weight=r.weight*r.weight*(3-2*r.weight); end
r.output=(1-r.weight)*s.blend_from+r.weight*predict(active.model,t);
r.reason='TRANSITION_IN_PROGRESS';
if ~missing && ~p.accepted, r.reason=p.reason; end
end

function [s,r]=action_reject(s,step,r)
g=step.guards; p=g.proposal;
before=step.before; v=g.before; t=step.time; hold=step.hold;
r.output=held(before,v,t,hold);
if g.route>0, r.reason=p.reason; else, r.reason='OUTSIDE_BOTH_READY_WINDOWS'; end
end

function [s,r]=action_hold(s,step,r)
before=step.before; v=step.guards.before; t=step.time; hold=step.hold;
r.output=held(before,v,t,hold); r.reason='GAP_WITH_MEMORY_RETAINED';
end

function [s,r]=action_unavailable(s,r)
r.reason='OUTPUT_UNAVAILABLE_MEMORY_RETAINED';
end

function [s,r]=action_wait(s,step,r)
g=step.guards; p=g.proposal;
before=step.before; v=g.before; t=step.time; hold=step.hold;
% Timed waiting retains accepted candidate evidence.
s=commit(s,p,g.route); r.accepted=p.accepted;
r.output=held(before,v,t,hold); r.reason='WAITING_FOR_SWITCH';
if g.main_hold, r.reason='MAIN_PROLONGATION_ACTIVE'; end
end

function s=commit(s,p,route)
names={'main','alt'};
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
