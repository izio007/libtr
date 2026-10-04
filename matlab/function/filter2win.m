function [rc,ctx,debug]=filter2win(cfg,ctx,current_time,X_meas_tick,is_nan_tick)
% FILTER2WIN Autonomous configurable two-window scalar state machine.
% rc=0: step executed, possibly NaN output. rc=1: ctx unchanged.
% ctx.FILTER_STATE.status and ctx.FILTER_STATUS: operating mode 0..16.
% Only real measurements enter either FIFO. No synthetic window padding.
% Schema 2 changes MAD fields/state: initialize ctx=struct() when adopting it.
% handover.settle_seconds and settle_min_samples both set to zero disable
% post-capture model freezing. All elapsed-time guards use input timestamps.
% Optional third output also explains refused steps without mutating ctx.
rc=1;
debug=struct('api_status',1,'reason','INVALID_INPUT','time',current_time);
[ok,reason]=filter2win_validate(cfg);
if ~ok, debug.reason=reason; return; end
if ~isstruct(ctx) || ~isscalar(ctx) || ~finite_scalar(current_time) || ...
        ~isa(X_meas_tick,'double') || ~isreal(X_meas_tick) || ~isscalar(X_meas_tick) || ...
        ~(islogical(is_nan_tick) || isa(is_nan_tick,'double')) || ...
        ~isreal(is_nan_tick) || ~isscalar(is_nan_tick) || ~ismember(is_nan_tick,[0 1])
    return;
end
missing=logical(is_nan_tick) || isnan(X_meas_tick);
if ~missing && ~isfinite(X_meas_tick), return; end
if isfield(ctx,'X_MAIN_REF') && ...
        (~isa(ctx.X_MAIN_REF,'double') || ~isreal(ctx.X_MAIN_REF) || ...
        ~(isscalar(ctx.X_MAIN_REF) || isequal(size(ctx.X_MAIN_REF),[3 1])) || ...
        ~all(isfinite(ctx.X_MAIN_REF)))
    return;
end
if isfield(ctx,'FILTER_STATE')
    s=ctx.FILTER_STATE;
    if ~valid_state(s,cfg), debug.reason='INVALID_STATE_OR_RECONFIGURATION'; return; end
    if current_time<=s.last_tick, debug.reason='NONINCREASING_TIME'; return; end
else
    s=initial_state(cfg,current_time);
end
old_status=s.status; old_main=s.main.count; old_alt=s.alt.count;
s.tact=s.tact+1;
[s,ok]=expire_windows(s,cfg,current_time);
if ~ok, debug.reason='TIME_ARITHMETIC_OVERFLOW'; return; end
g=filter2win_features(cfg,s,current_time,X_meas_tick,missing);
[s,selected,blocked,rule_checks]=select_rule(s,cfg,g,current_time);
if isempty(selected)
    destination=15; rule_name='NO_ELIGIBLE_RULE'; event='FALLBACK';
else
    rule=cfg.rules(selected);
    destination=rule.to; rule_name=rule.name; event=rule.event;
end
% Zero handover duration is an explicitly supported instantaneous switch.
if destination==14 && cfg.handover.duration_seconds==0, destination=6; end
s.status=destination; % choose the handler before changing numerical windows.
if ~missing && ~g.main_in && g.has_primary && ~isfinite(s.deviation_since)
    s.deviation_since=current_time;
end
accepted=false; reacquired=false; output=NaN; weight=NaN;

switch s.status
    case 0 % WAITING_FOR_DATA
        reason='NO_FINITE_OBSERVATION';
    case 1 % ACCUMULATING
        s.main=q_push(s.main,current_time,X_meas_tick);
        s.primary=filter2win_model(struct('time',zeros(1,0),'value',zeros(1,0)),cfg.main);
        s.reacquired_at=NaN; s.settle_samples=0;
        s=clear_alternative(s);
        s=clear_blend(s);
        s.deviation_since=NaN; accepted=true;
        reason='INITIAL_BASE_NOT_READY';
    case 2 % STEADY_TRACKING; also the configurable return/cancel handler.
        s.main=q_push(s.main,current_time,X_meas_tick);
        if g.main_ready, s.primary=g.main_model; end
        if ~isfinite(s.primary.level), debug.reason='POLICY_REQUIRES_MAIN_MODEL'; return; end
        s=clear_alternative(s); s=clear_blend(s);
        s.reacquired_at=NaN; s.settle_samples=0;
        s.deviation_since=NaN; accepted=true;
        output=predict(s.primary,current_time);
        reason='MAIN_ACCEPTED';
        if old_status==14, reason='HANDOVER_CANCELLED_ON_MAIN_RETURN'; end
    case 3 % TRACKING_WITH_OUTLIERS
        if g.append_alt, s=save_candidate(s,g,current_time,X_meas_tick); end
        output=held_output(s,g,current_time,false);
        reason='OUTLIER_OR_HYSTERESIS_DEAD_BAND';
    case 4 % ALT_ACCUMULATING
        s=save_candidate(s,g,current_time,X_meas_tick);
        output=held_output(s,g,current_time,false);
        reason='ALTERNATIVE_CONFIRMATION_PENDING';
    case 5 % ALT_QUALITY_REJECTED: rejection does not necessarily erase evidence.
        switch cfg.alt.on_reject
            case 'retain'
                s=save_candidate(s,g,current_time,X_meas_tick);
            case 'clear'
                s=clear_alternative(s);
            case 'restart'
                s=clear_alternative(s);
                s.alt=q_push(s.alt,current_time,X_meas_tick);
                s.alt_since=current_time;
        end
        output=held_output(s,g,current_time,false);
        reason='ALTERNATIVE_QUALITY_LIMIT';
    case 6 % ALT_ACCEPTED: atomic replacement; no mixed FIFO samples.
        if strcmp(event,'BLEND_DONE')
            if g.append_alt && ~g.incompatible
                s=save_candidate(s,g,current_time,X_meas_tick);
            end
            [~,~,samples]=fifo_double('read',s.alt);
            target=g.target;
        else
            samples=g.candidate; target=g.target_model;
        end
        if ~isfinite(target.level), debug.reason='POLICY_REQUIRES_ALT_MODEL'; return; end
        s.main=replace_queue(s.main,samples);
        s.primary=target; s=clear_alternative(s); s=clear_blend(s);
        s.reacquired_at=current_time; s.settle_samples=0;
        s.deviation_since=NaN;
        output=predict(s.primary,current_time); reacquired=true;
        accepted=~missing && g.store_alt;
        reason='AUTONOMOUS_ALT_PROMOTION'; weight=1;
    case 7 % GAP_PROLONGATION
        output=held_output(s,g,current_time,true);
        reason='MISSING_WITHIN_PROLONGATION';
    case 8 % GAP_EXPIRED or unusable handover target.
        s=clear_blend(s);
        reason='ESTIMATE_UNAVAILABLE_MEMORY_RETAINED';
    case 9 % TIMEOUT_RESET
        tact=s.tact; s=initial_state(cfg,current_time); s.tact=tact; s.status=9;
        if ~missing
            s.main=q_push(s.main,current_time,X_meas_tick);
            accepted=true;
        end
        reason='RAW_INPUT_TIMEOUT_FULL_RESET';
    case 10 % ALT_COMPACTNESS_REJECTED: isolated point need not erase the FIFO.
        s=clear_blend(s);
        s=save_candidate(s,g,current_time,X_meas_tick);
        output=held_output(s,g,current_time,false);
        reason='ALTERNATIVE_INCOMPATIBLE_SEQUENCE';
        if strcmp(g.incompatible_action,'ignore')
            reason='ALT_POINT_IGNORED_EVIDENCE_RETAINED';
        elseif strcmp(g.incompatible_action,'restart')
            reason='ALT_SEQUENCE_RESTARTED';
        end
    case 11 % WARMUP_OUTLIER
        s=save_candidate(s,g,current_time,X_meas_tick);
        reason='WARMUP_POINT_ISOLATED';
    case 12 % WARMUP_GAP
        reason='MISSING_BEFORE_INITIAL_BASE';
    case 13 % INITIAL_REBASE, still obeying the initial main-base criteria.
        s.main=replace_queue(s.main,g.candidate);
        [~,~,samples]=fifo_double('read',s.main);
        model=filter2win_model(samples,cfg.main);
        if main_ready(model,samples,cfg.main)
            s.primary=model; output=predict(model,current_time);
            s.reacquired_at=current_time; s.settle_samples=0;
        end
        s=clear_alternative(s); s=clear_blend(s);
        s.deviation_since=NaN; accepted=true; reacquired=true;
        reason='INITIAL_CANDIDATE_REBASE';
    case 14 % TRANSITIONING: separate handler with two numerical models.
        if old_status~=14
            if ~g.has_primary || ~g.alt_ready
                debug.reason='POLICY_REQUIRES_TWO_MODELS'; return;
            end
            s=save_candidate(s,g,current_time,X_meas_tick);
            s.target=g.target_model; s.blend_elapsed=0;
        else
            if g.append_alt
                s=save_candidate(s,g,current_time,X_meas_tick);
            end
            s.target=g.target; s.blend_elapsed=g.blend_elapsed;
        end
        fraction=min(1,max(0,s.blend_elapsed/cfg.handover.duration_seconds));
        if strcmp(cfg.handover.curve,'smoothstep')
            weight=fraction*fraction*(3-2*fraction);
        else
            weight=fraction;
        end
        output=(1-weight)*predict(s.primary,current_time)+weight*predict(s.target,current_time);
        reason='AUTONOMOUS_HANDOVER_IN_PROGRESS';
        if strcmp(g.incompatible_action,'ignore'), reason='HANDOVER_PAUSED_ALT_OUTLIER'; end
    case 15 % POLICY_HOLD: disabled or still-confirming transitions.
        output=held_output(s,g,current_time,missing);
        reason='NO_ACTIONABLE_TRANSITION';
    case 16 % REACQUISITION_SETTLING: retained model is a prior, not fake data.
        if ~g.has_primary || missing || ~g.main_in
            debug.reason='POLICY_REQUIRES_SETTLING_MODEL'; return;
        end
        s.main=q_push(s.main,current_time,X_meas_tick);
        s.settle_samples=g.settle_samples;
        s=clear_alternative(s); s=clear_blend(s);
        s.deviation_since=NaN; accepted=true;
        output=predict(s.primary,current_time);
        reason='REACQUIRED_MODEL_HELD_REAL_SAMPLES_ACCUMULATING';
    otherwise
        debug.reason='INVALID_DESTINATION'; return;
end
if ~isnan(output) && ~isfinite(output), debug.reason='NUMERIC_OUTPUT_OVERFLOW'; return; end
if ~missing, s.last_input=current_time; end
if accepted, s.last_main_accept=current_time; end
if s.status~=old_status, s.status_since=current_time; end
s.last_tick=current_time;
debug=struct('api_status',0,'reason',reason,'tact',s.tact,'time',current_time, ...
    'measurement',X_meas_tick,'missing',missing,'previous_status',old_status, ...
    'status',s.status,'status_name',filter2win_status_name(s.status), ...
    'rule',rule_name,'event',event,'blocked_rules',{blocked},'rule_checks',rule_checks, ...
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

function s=initial_state(cfg,t)
[~,main]=fifo_double('init',[],cfg.main.capacity);
[~,alt]=fifo_double('init',[],cfg.alt.capacity);
empty=filter2win_model(struct('time',zeros(1,0),'value',zeros(1,0)),cfg.main);
s=struct('parameters',cfg,'status',0,'status_since',t,'tact',0,'last_tick',-Inf, ...
    'last_input',-Inf,'last_main_accept',-Inf,'deviation_since',NaN, ...
    'alt_since',NaN,'alt_incompatible_since',NaN,'alt_incompatible_samples',0, ...
    'reacquired_at',NaN,'settle_samples',0, ...
    'main',main,'alt',alt,'primary',empty,'target',empty, ...
    'blend_elapsed',0,'rule_since',NaN(1,numel(cfg.rules)), ...
    'rule_hits',zeros(1,numel(cfg.rules)));
end

function [s,ok]=expire_windows(s,c,t)
ok=true;
names={'main','alt'};
for k=1:2
    name=names{k}; w=c.(name); q=s.(name);
    if isfinite(w.history_seconds)
        cutoff=t-w.history_seconds;
        if ~isfinite(cutoff), ok=false; return; end
        [~,q]=fifo_double('prune',q,cutoff);
    end
    if q.count>0 && t-q.last_time>w.max_gap_seconds
        if strcmp(name,'main') || strcmp(c.alt.gap_action,'restart')
            [~,q]=fifo_double('clear',q);
        end
        if strcmp(name,'alt')
            s.alt_since=NaN; s.alt_incompatible_since=NaN; s.alt_incompatible_samples=0;
        end
    end
    s.(name)=q;
end
if s.alt.count==0
    s.alt_since=NaN; s.alt_incompatible_since=NaN; s.alt_incompatible_samples=0;
end
end

function [s,selected,blocked,selected_checks]=select_rule(s,c,g,t)
selected=[]; priority=-Inf; blocked={};
selected_checks=struct('metric',{},'actual',{},'operator',{},'threshold',{},'passed',{});
for k=1:numel(c.rules)
    r=c.rules(k);
    active=r.enabled && (isempty(r.from) || ismember(s.status,r.from)) && g.events.(r.event);
    if ~active
        s.rule_since(k)=NaN; s.rule_hits(k)=0; continue;
    end
    [conditions_pass,checks]=filter2win_rule_checks(r,g.metrics);
    if ~conditions_pass
        s.rule_since(k)=NaN; s.rule_hits(k)=0;
    end
    if conditions_pass
        if ~isfinite(s.rule_since(k)), s.rule_since(k)=t; end
        s.rule_hits(k)=s.rule_hits(k)+1;
        elapsed=t-s.rule_since(k);
    else
        elapsed=0;
    end
    dwell=t-s.status_since;
    eligible=conditions_pass && s.rule_hits(k)>=r.confirm_ticks && elapsed>=r.confirm_seconds && ...
        dwell>=r.min_dwell_seconds;
    if eligible && r.priority>priority
        selected=k; priority=r.priority; selected_checks=checks;
    elseif ~eligible
        blocked{end+1}=struct('name',r.name,'hits',s.rule_hits(k), ...
            'required_hits',r.confirm_ticks,'seconds',elapsed, ...
            'required_seconds',r.confirm_seconds,'dwell',dwell, ...
            'required_dwell',r.min_dwell_seconds,'checks',checks); %#ok<AGROW>
    end
end
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

function ok=finite_scalar(x)
ok=isa(x,'double') && isreal(x) && isscalar(x) && isfinite(x);
end

function ok=valid_state(s,cfg)
fields={'parameters','status','status_since','tact','last_tick','last_input', ...
    'last_main_accept','deviation_since','alt_since','main','alt','primary', ...
    'target','blend_elapsed','rule_since','rule_hits','alt_incompatible_since', ...
    'alt_incompatible_samples','reacquired_at','settle_samples'};
ok=isstruct(s) && isscalar(s) && all(isfield(s,fields));
if ~ok, return; end
ok=isequaln(s.parameters,cfg) && finite_scalar(s.status) && ...
    s.status==fix(s.status) && s.status>=0 && s.status<=16 && ...
    finite_scalar(s.status_since) && finite_scalar(s.tact) && s.tact>=0 && ...
    s.tact==fix(s.tact) && finite_scalar(s.last_tick) && ...
    finite_scalar(s.blend_elapsed) && s.blend_elapsed>=0 && ...
    finite_scalar(s.alt_incompatible_samples) && s.alt_incompatible_samples>=0 && ...
    s.alt_incompatible_samples==fix(s.alt_incompatible_samples) && ...
    finite_scalar(s.settle_samples) && s.settle_samples>=0 && ...
    s.settle_samples==fix(s.settle_samples) && ...
    isequal(size(s.rule_since),[1 numel(cfg.rules)]) && ...
    isequal(size(s.rule_hits),[1 numel(cfg.rules)]);
if ~ok, return; end
ok=s.status_since<=s.last_tick && isa(s.rule_since,'double') && isreal(s.rule_since) && ...
    isa(s.rule_hits,'double') && isreal(s.rule_hits) && ...
    all(isfinite(s.rule_hits) & s.rule_hits>=0 & s.rule_hits==fix(s.rule_hits)) && ...
    all(isnan(s.rule_since) | (isfinite(s.rule_since) & s.rule_since<=s.last_tick));
if ~ok, return; end
clocks={'last_input','last_main_accept','deviation_since','alt_since', ...
    'alt_incompatible_since','reacquired_at'};
for k=1:numel(clocks)
    value=s.(clocks{k});
    if ~isa(value,'double') || ~isreal(value) || ~isscalar(value), ok=false; return; end
    if k<=2
        valid=(isfinite(value) && value<=s.last_tick) || value==-Inf;
    else
        valid=(isfinite(value) && value<=s.last_tick) || isnan(value);
    end
    if ~valid, ok=false; return; end
end
[main_rc,~,~]=fifo_double('read',s.main); [alt_rc,~,~]=fifo_double('read',s.alt);
ok=main_rc==0 && alt_rc==0 && s.main.capacity==cfg.main.capacity && ...
    s.alt.capacity==cfg.alt.capacity && s.main.last_time<=s.last_tick && ...
    s.alt.last_time<=s.last_tick && valid_model(s.primary,s.last_tick) && ...
    valid_model(s.target,s.last_tick);
end

function ok=valid_model(m,t)
fields={'n','first','last','level','velocity','mad','min_residual','max_residual', ...
    'trimmed_min_residual','trimmed_max_residual','trimmed_range','trimmed_count'};
ok=isstruct(m) && isscalar(m) && all(isfield(m,fields));
if ~ok, return; end
for k=1:numel(fields)
    x=m.(fields{k});
    if ~isa(x,'double') || ~isreal(x) || ~isscalar(x), ok=false; return; end
end
if isfinite(m.level)
    ok=isfinite(m.n) && m.n>=2 && m.n==fix(m.n) && ...
        isfinite(m.first) && isfinite(m.last) && m.first<=m.last && m.last<=t && ...
        isfinite(m.velocity) && isfinite(m.mad) && m.mad>=0 && ...
        isfinite(m.min_residual) && isfinite(m.max_residual) && ...
        m.min_residual<=m.trimmed_min_residual && ...
        m.trimmed_min_residual<=m.trimmed_max_residual && ...
        m.trimmed_max_residual<=m.max_residual && ...
        isfinite(m.trimmed_range) && m.trimmed_range>=0 && ...
        m.trimmed_count>=1 && m.trimmed_count<=m.n && m.trimmed_count==fix(m.trimmed_count);
else
    ok=m.n==0 && isnan(m.level) && isnan(m.velocity) && isnan(m.mad) && ...
        m.trimmed_count==0;
end
end
