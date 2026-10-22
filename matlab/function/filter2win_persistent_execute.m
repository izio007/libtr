function [rc,ctx,debug]=filter2win_persistent_execute(c,ctx,s,step,decision,debug)
% Execute the selected action and publish one coherent result/status.
rc=1;
t=step.time; x=step.measurement; missing=step.missing;
before=step.before; g=step.guards; p=g.proposal; event=decision.event;
g.event=event; step.guards=g;
s.tact=s.tact+1;
r=struct('accepted',false,'switched',false,'output',NaN,'weight',NaN,'reason',event,'error','');
switch decision.action
    case 'accumulate'
        [s,r]=action_accumulate(s,step,r);
    case 'track'
        [s,r]=action_track(s,step,r);
    case 'switch'
        [s,r]=action_switch(s,step,r);
    case 'blend'
        [s,r]=action_blend(s,c,step,r);
    case 'reject'
        [s,r]=action_reject(s,step,r);
    case 'hold'
        [s,r]=action_hold(s,step,r);
    case 'unavailable'
        [s,r]=action_unavailable(s,r);
    case 'wait'
        [s,r]=action_wait(s,step,r);
    otherwise
        r.error='INVALID_ACTION';
end
if ~isempty(r.error), debug.reason=r.error; return; end
accepted=r.accepted; switched=r.switched; output=r.output;
% Actions can only commit the observed proposal. Its cached view describes
% the exact same samples; unchanged windows keep their original view.
after=g.before;
if accepted, after(g.route)=p.stats; end
lost_window=0;
if s.active>0 && ~after(s.active).ready
    lost_window=s.active; s.active=0; output=NaN;
end
% NaN is intentional only when this action cannot provide an active result.
% A required prediction that becomes NaN is a numerical refusal, like Inf.
output_required=s.active>0 && ~strcmp(decision.action,'unavailable') && ...
    (step.hold || (accepted && g.route==s.active));
if ~isfinite(output) && (output_required || ~isnan(output))
    debug.reason='NUMERIC_OUTPUT_OVERFLOW'; return;
end
[status,reason]=final_status(decision,r.reason,lost_window);
if isempty(status), debug.reason='INVALID_EVENT'; return; end
% A waiting candidate pauses a blend without ending its lifetime. Only this
% publication stage clears it after completion, cancellation or loss of base.
keep_blend=strcmp(decision.action,'blend') || ...
    (strcmp(decision.action,'wait') && before.blend_duration>0 && step.hold);
if ~keep_blend || lost_window>0, s=clear_blend(s); end
s.status=status;
s.last_supported=accepted && s.active==g.route && s.active>0 && after(s.active).ready;
if ~missing, s.last_input=t; end
s.last_tick=t; s.last_output=output;
if s.status~=before.status, s.status_since=t; end
if s.active>0
    s.primary=after(s.active).model;
else
    s.primary=filter2win_model(struct('time',[],'value',[]),'constant');
end
removed=struct('time',[],'value',[]); evicted=removed;
if accepted, removed=p.removed; evicted=p.evicted; end
debug=struct('api_status',0,'schema_version',3,'reason',reason,'tact',s.tact,'time',t, ...
    'measurement',x,'missing',missing,'previous_status',before.status, ...
    'status',s.status,'status_name',filter2win_status_name(s.status,3), ...
    'phase_before',phase(before),'phase',phase(s),'action',decision.action, ...
    'active_before',before.active,'active_window',s.active,'route',g.route, ...
    'accepted',accepted,'reacquired',switched,'valid',isfinite(output),'output',output, ...
    'main_before',before.main.count,'main_count',s.main.count, ...
    'alt_before',before.alt.count,'alt_count',s.alt.count,'windows',after, ...
    'removed',removed,'evicted',evicted,'event',event, ...
    'blend_weight',r.weight,'guards',g);
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
s=commit(s,p,g.route); r.accepted=p.accepted;
r.output=held(step.before,g.before,step.time,step.hold);
r.reason='COLLECTING_NOT_USED';
end

function [s,r]=action_track(s,step,r)
g=step.guards; p=g.proposal; t=step.time;
if ~p.accepted || ~p.stats.ready, r.error='STATE_REQUIRES_READY_PROPOSAL'; return; end
s=commit(s,p,g.route); r.accepted=true;
r.switched=s.active~=g.route; s.active=g.route;
s.last_accept(g.route)=t;
r.output=predict(p.stats.model,t); r.reason='WINDOW_ACCEPTED';
if strcmp(g.event,'INITIAL_READY'), r.reason='INITIAL_BASE_READY'; end
end

function [s,r]=action_switch(s,step,r)
g=step.guards; p=g.proposal; t=step.time;
if strcmp(g.event,'SWITCH_READY')
    if ~p.accepted || ~p.stats.ready, r.error='STATE_REQUIRES_READY_PROPOSAL'; return; end
    r.switched=s.active~=g.route; s.active=g.route; s.last_accept(g.route)=t;
    r.reason='READY_WINDOW_SELECTED';
else
    r.reason='TRANSITION_COMPLETE';
    if p.accepted && p.stats.ready && g.route==s.active, s.last_accept(s.active)=t; end
end
if s.active==0, r.error='STATE_REQUIRES_ACTIVE_WINDOW'; return; end
s=commit(s,p,g.route); r.accepted=p.accepted;
active=window_after(step,s.active);
if active.ready, r.output=predict(active.model,t); end
r.weight=1;
end

function [s,r]=action_blend(s,c,step,r)
g=step.guards; p=g.proposal; before=step.before;
t=step.time; missing=step.missing;
if strcmp(g.event,'SWITCH_READY')
    if ~p.accepted || ~p.stats.ready || s.active==0, r.error='STATE_REQUIRES_TWO_WINDOWS'; return; end
    from=held(before,g.before,t,step.hold);
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
active=window_after(step,s.active);
r.weight=min(1,max(0,s.blend_elapsed/s.blend_duration));
if strcmp(c.handover.curve,'smoothstep'), r.weight=r.weight*r.weight*(3-2*r.weight); end
r.output=(1-r.weight)*s.blend_from+r.weight*predict(active.model,t);
r.reason='TRANSITION_IN_PROGRESS';
if ~missing && ~p.accepted
    r.reason=p.reason;
    if g.route==0, r.reason='OUTSIDE_BOTH_READY_WINDOWS'; end
end
end

function [s,r]=action_reject(s,step,r)
g=step.guards; p=g.proposal;
r.output=held(step.before,g.before,step.time,step.hold);
if g.route>0, r.reason=p.reason; else, r.reason='OUTSIDE_BOTH_READY_WINDOWS'; end
end

function [s,r]=action_hold(s,step,r)
r.output=held(step.before,step.guards.before,step.time,step.hold);
r.reason='GAP_WITH_MEMORY_RETAINED';
end

function [s,r]=action_unavailable(s,r)
r.reason='OUTPUT_UNAVAILABLE_MEMORY_RETAINED';
end

function [s,r]=action_wait(s,step,r)
g=step.guards; p=g.proposal;
s=commit(s,p,g.route); r.accepted=p.accepted;
r.output=held(step.before,g.before,step.time,step.hold);
r.reason='WAITING_FOR_SWITCH';
if g.main_hold, r.reason='MAIN_PROLONGATION_ACTIVE'; end
end

function s=commit(s,p,route)
names={'main','alt'};
if p.accepted && route>0
    s.(names{route})=p.queue;
end
end

function v=window_after(step,index)
g=step.guards; v=g.before(index);
if g.proposal.accepted && g.route==index, v=g.proposal.stats; end
end

function x=predict(m,t)
x=m.level+m.velocity*(t-m.last);
end

function output=held(s,v,t,allowed)
output=NaN;
if ~allowed || s.active==0, return; end
if s.blend_duration>0
    output=s.last_output;
else
    output=predict(v(s.active).model,t);
end
end

function s=clear_blend(s)
s.blend_duration=0; s.blend_elapsed=0; s.blend_from=NaN; s.blend_start=NaN;
end

function name=phase(s)
name='ACCUMULATING';
if s.blend_duration>0, name='BLENDING'; elseif s.active>0, name='TRACKING'; end
end

function [status,reason]=final_status(decision,reason,lost_window)
% One final status, including the actual not-ready outcome of a committed FIFO.
status=[];
switch decision.event
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
    case {'SWITCH_READY','BLEND_ACTIVE'}
        status=14; if strcmp(decision.action,'switch'), status=6; end
    case 'OUTLIER_HOLD', status=3;
    case 'WARMUP_REJECTED', status=11;
    case 'SWITCH_WAIT', status=15;
    otherwise
        return; % Unknown events are internal failures, never a successful wait.
end
if lost_window>0
    status=1; if lost_window==2, status=4; end
    reason='BASE_NO_LONGER_READY_AFTER_REMOVAL';
end
end
