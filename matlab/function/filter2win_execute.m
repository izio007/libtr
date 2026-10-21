function [rc,ctx,debug]=filter2win_execute(cfg,ctx,s,step,debug)
% Schema 2 actions. The switch selects an ordinary, named numerical function.
% All writes remain local until the completed step is published below.
rc=1;
t=step.time; x=step.measurement; missing=step.missing;
old_status=step.previous_status; old_main=step.main_before; old_alt=step.alt_before;
g=step.guards; event=step.event;
s.status=step.status;
if step.start_deviation, s.deviation_since=t; end
r=struct('accepted',false,'reacquired',false,'output',NaN,'weight',NaN,'reason','','error','');
switch s.status
    case {0,8,12}
        [s,r]=action_wait(s,r);
    case 1
        [s,r]=action_accumulate(s,cfg,t,x,r);
    case 2
        [s,r]=action_track(s,g,t,x,old_status,r);
    case {3,4,7,15}
        [s,r]=action_hold(s,g,t,x,missing,r);
    case {5,10,11}
        [s,r]=action_reject(s,cfg,g,t,x,r);
    case 6
        [s,r]=action_switch(s,g,t,x,missing,event,r);
    case 9
        [s,r]=action_reset(s,cfg,t,x,missing,r);
    case 13
        [s,r]=action_rebase(s,cfg,g,t,r);
    case 14
        [s,r]=action_blend(s,cfg,g,t,x,old_status,r);
    case 16
        [s,r]=action_settle(s,g,t,x,missing,r);
    otherwise
        r.error='INVALID_DESTINATION';
end
if ~isempty(r.error), debug.reason=r.error; return; end
accepted=r.accepted; reacquired=r.reacquired; output=r.output; weight=r.weight; reason=r.reason;
if ~isnan(output) && ~isfinite(output), debug.reason='NUMERIC_OUTPUT_OVERFLOW'; return; end
if ~missing, s.last_input=t; end
if accepted, s.last_main_accept=t; end
if s.status~=old_status, s.status_since=t; end
s.last_tick=t;
debug=struct('api_status',0,'reason',reason,'tact',s.tact,'time',t, ...
    'measurement',x,'missing',missing,'previous_status',old_status, ...
    'status',s.status,'status_name',filter2win_status_name(s.status), ...
    'event',event, ...
    'valid',isfinite(output),'output',output,'blend_weight',weight, ...
    'main_before',old_main,'main_count',s.main.count, ...
    'alt_before',old_alt,'alt_count',s.alt.count,'guards',g);
ctx.FILTER_STATE=s; ctx.FILTER_STATUS=s.status; ctx.FILTER_VALID=isfinite(output);
ctx.X_FILTERED_OUTPUT=output; ctx.W_ALT_POWER_OUTPUT=s.alt.count;
ctx.ACCEPTED=accepted; ctx.REACQUIRED=reacquired; ctx.FILTER_DEBUG=debug;
if isfinite(output)
    if ~isfield(ctx,'X_MAIN_REF'), ctx.X_MAIN_REF=output;
    else, ctx.X_MAIN_REF(1)=output; end
end
rc=0;
end

function [s,r]=action_wait(s,r)
switch s.status
    case 0
        r.reason='NO_FINITE_OBSERVATION';
    case 8
        s=clear_blend(s);
        r.reason='ESTIMATE_UNAVAILABLE_MEMORY_RETAINED';
    case 12
        r.reason='MISSING_BEFORE_INITIAL_BASE';
end
end

function [s,r]=action_accumulate(s,cfg,t,x,r)
s.main=q_push(s.main,t,x);
s.primary=filter2win_model(struct('time',zeros(1,0),'value',zeros(1,0)),cfg.main);
s.reacquired_at=NaN; s.settle_samples=0;
s=clear_alternative(s);
s=clear_blend(s);
s.deviation_since=NaN; r.accepted=true;
r.reason='INITIAL_BASE_NOT_READY';
end

function [s,r]=action_track(s,g,t,x,old_status,r)
s.main=q_push(s.main,t,x);
if g.main_ready, s.primary=g.main_model; end
if ~isfinite(s.primary.level), r.error='STATE_REQUIRES_MAIN_MODEL'; return; end
s=clear_alternative(s); s=clear_blend(s);
s.reacquired_at=NaN; s.settle_samples=0;
s.deviation_since=NaN; r.accepted=true;
r.output=predict(s.primary,t);
r.reason='MAIN_ACCEPTED';
if old_status==14, r.reason='HANDOVER_CANCELLED_ON_MAIN_RETURN'; end
end

function [s,r]=action_hold(s,g,t,x,missing,r)
switch s.status
    case 3
        if g.append_alt, s=save_candidate(s,g,t,x); end
        r.output=held_output(s,g,t,false);
        r.reason='OUTLIER_OR_HYSTERESIS_DEAD_BAND';
    case 4
        s=save_candidate(s,g,t,x);
        r.output=held_output(s,g,t,false);
        r.reason='ALTERNATIVE_CONFIRMATION_PENDING';
    case 7
        r.output=held_output(s,g,t,true);
        r.reason='MISSING_WITHIN_PROLONGATION';
    case 15
        r.output=held_output(s,g,t,missing);
        r.reason='NO_ACTIONABLE_TRANSITION';
end
end

function [s,r]=action_reject(s,cfg,g,t,x,r)
switch s.status
    case 5
        switch cfg.alt.on_reject
            case 'retain'
                s=save_candidate(s,g,t,x);
            case 'clear'
                s=clear_alternative(s);
            case 'restart'
                s=clear_alternative(s);
                s.alt=q_push(s.alt,t,x);
                s.alt_since=t;
        end
        r.output=held_output(s,g,t,false);
        r.reason='ALTERNATIVE_QUALITY_LIMIT';
    case 10
        s=clear_blend(s);
        s=save_candidate(s,g,t,x);
        r.output=held_output(s,g,t,false);
        r.reason='ALTERNATIVE_INCOMPATIBLE_SEQUENCE';
        if strcmp(g.incompatible_action,'ignore')
            r.reason='ALT_POINT_IGNORED_EVIDENCE_RETAINED';
        elseif strcmp(g.incompatible_action,'restart')
            r.reason='ALT_SEQUENCE_RESTARTED';
        end
    case 11
        s=save_candidate(s,g,t,x);
        r.reason='WARMUP_POINT_ISOLATED';
end
end

function [s,r]=action_switch(s,g,t,x,missing,event,r)
if strcmp(event,'BLEND_DONE')
    if g.append_alt && ~g.incompatible
        s=save_candidate(s,g,t,x);
    end
    [~,~,samples]=fifo_double('read',s.alt);
    target=g.target;
else
    samples=g.candidate; target=g.target_model;
end
if ~isfinite(target.level), r.error='STATE_REQUIRES_ALT_MODEL'; return; end
s.main=replace_queue(s.main,samples);
s.primary=target; s=clear_alternative(s); s=clear_blend(s);
s.reacquired_at=t; s.settle_samples=0;
s.deviation_since=NaN;
r.output=predict(s.primary,t); r.reacquired=true;
r.accepted=~missing && g.store_alt;
r.reason='AUTONOMOUS_ALT_PROMOTION'; r.weight=1;
end

function [s,r]=action_reset(s,cfg,t,x,missing,r)
tact=s.tact; s=filter2win_initial_state(cfg,t); s.tact=tact; s.status=9;
if ~missing
    s.main=q_push(s.main,t,x);
    r.accepted=true;
end
r.reason='RAW_INPUT_TIMEOUT_FULL_RESET';
end

function [s,r]=action_rebase(s,cfg,g,t,r)
s.main=replace_queue(s.main,g.candidate);
[~,~,samples]=fifo_double('read',s.main);
model=filter2win_model(samples,cfg.main);
if main_ready(model,samples,cfg.main)
    s.primary=model; r.output=predict(model,t);
    s.reacquired_at=t; s.settle_samples=0;
end
s=clear_alternative(s); s=clear_blend(s);
s.deviation_since=NaN; r.accepted=true; r.reacquired=true;
r.reason='INITIAL_CANDIDATE_REBASE';
end

function [s,r]=action_blend(s,cfg,g,t,x,old_status,r)
if old_status~=14
    if ~g.has_primary || ~g.alt_ready
        r.error='STATE_REQUIRES_TWO_MODELS'; return;
    end
    s=save_candidate(s,g,t,x);
    s.target=g.target_model; s.blend_elapsed=0;
else
    if g.append_alt
        s=save_candidate(s,g,t,x);
    end
    s.target=g.target; s.blend_elapsed=g.blend_elapsed;
end
fraction=min(1,max(0,s.blend_elapsed/cfg.handover.duration_seconds));
if strcmp(cfg.handover.curve,'smoothstep')
    r.weight=fraction*fraction*(3-2*fraction);
else
    r.weight=fraction;
end
r.output=(1-r.weight)*predict(s.primary,t)+r.weight*predict(s.target,t);
r.reason='AUTONOMOUS_HANDOVER_IN_PROGRESS';
if strcmp(g.incompatible_action,'ignore'), r.reason='HANDOVER_PAUSED_ALT_OUTLIER'; end
end

function [s,r]=action_settle(s,g,t,x,missing,r)
if ~g.has_primary || missing || ~g.main_in
    r.error='STATE_REQUIRES_SETTLING_MODEL'; return;
end
s.main=q_push(s.main,t,x);
s.settle_samples=g.settle_samples;
s=clear_alternative(s); s=clear_blend(s);
s.deviation_since=NaN; r.accepted=true;
r.output=predict(s.primary,t);
r.reason='REACQUIRED_MODEL_HELD_REAL_SAMPLES_ACCUMULATING';
end

function s=save_candidate(s,g,t,x)
if ~g.append_alt, return; end
if g.incompatible
    if strcmp(g.incompatible_action,'ignore')
        s.alt_incompatible_since=g.incompatible_since;
        s.alt_incompatible_samples=g.incompatible_samples;
        return; % last_time/count/span stay those of actual compatible data.
    end
    s=clear_alternative(s);
else
    s.alt_incompatible_since=NaN; s.alt_incompatible_samples=0;
end
if g.store_alt && ~isempty(g.candidate.time)
    s.alt=q_push(s.alt,t,x); s.alt_since=g.candidate_since;
end
end

function s=clear_alternative(s)
[~,s.alt]=fifo_double('clear',s.alt); s.alt_since=NaN;
s.alt_incompatible_since=NaN; s.alt_incompatible_samples=0;
end

function s=clear_blend(s)
s.target=filter2win_model(struct('time',zeros(1,0),'value',zeros(1,0)),'constant');
s.blend_elapsed=0;
end

function q=replace_queue(q,samples)
[~,q]=fifo_double('clear',q);
first=max(1,numel(samples.time)-q.capacity+1);
for k=first:numel(samples.time), q=q_push(q,samples.time(k),samples.value(k)); end
end

function q=q_push(q,t,x)
[code,q]=fifo_double('push',q,t,x);
assert(code==0,'libtr:filter2win:InternalQueue','Internal FIFO push refused.');
end

function output=held_output(s,g,t,missing)
output=NaN;
if (missing && g.gap_allowed) || (~missing && g.outlier_allowed)
    output=predict(s.primary,t);
end
end

function value=predict(model,t)
value=model.level+model.velocity*(t-model.last);
end

function ok=main_ready(model,samples,w)
n=numel(samples.time);
band=filter2win_band(model,w.band,0);
ok=n>=w.min_samples && band.quality;
if ~ok, return; end
ok=samples.time(end)-samples.time(1)>=w.min_span_seconds && ...
    max(diff(samples.time))<=w.max_gap_seconds;
end
