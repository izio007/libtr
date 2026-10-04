function g=filter2win_features(c,s,t,x,missing)
% Read-only transition guards. No true coordinate or scenario times are used.
[~,~,main]=fifo_double('read',s.main);
[~,~,alt]=fifo_double('read',s.alt);
g=struct();
g.limits=struct('alt_min_samples',c.alt.min_samples, ...
    'alt_min_span',c.alt.min_span_seconds,'alt_confirm_seconds',c.alt.confirm_seconds, ...
    'alt_max_gap',c.alt.max_gap_seconds,'alt_freshness',c.alt.freshness_seconds, ...
    'alt_max_mad',c.alt.band.max_mad,'relative_mad_ratio',c.alt.relative_mad_ratio, ...
    'alt_max_trimmed_range',c.alt.band.max_trimmed_range, ...
    'compatibility',c.alt.compatibility.method, ...
    'neighbor_radius',c.alt.compatibility.neighbor_radius, ...
    'incompatible_min_samples',c.alt.incompatible_min_samples, ...
    'incompatible_min_seconds',c.alt.incompatible_min_seconds, ...
    'settle_seconds',c.handover.settle_seconds, ...
    'settle_min_samples',c.handover.settle_min_samples, ...
    'outlier_hold_seconds',c.flow.outlier_hold_seconds, ...
    'gap_hold_seconds',c.flow.gap_hold_seconds,'timeout_seconds',c.flow.timeout_seconds);
g.has_primary=isfinite(s.primary.level);
g.primary_model=s.primary;
g.main_before=window_metrics(main,t);
g.alt_before=window_metrics(alt,t);
g.prediction=NaN; g.residual=NaN;
g.enter_lower=NaN; g.enter_upper=NaN; g.exit_lower=NaN; g.exit_upper=NaN;
g.main_in=false; g.outside_exit=false; g.append_alt=false; g.store_alt=false;
g.incompatible=false; g.alt_quality=false; g.target_quality=false; g.relative_quality=true;
g.incompatible_action='none'; g.incompatible_since=NaN;
g.incompatible_samples=0; g.incompatible_age=0;
g.neighbor_distance=NaN; g.neighbor_limit=NaN;
g.candidate=alt; g.candidate_since=s.alt_since;
g.candidate_model=filter2win_model(alt,c.alt);
g.target_model=filter2win_model(alt,c.main);
g.main_candidate=main; g.main_model=filter2win_model(main,c.main);
g.main_ready=false; g.alt_ready=false; g.partial=false;
g.alt_confirmation=0; g.alt_metrics=g.alt_before;
g.wait_elapsed=0;
g.primary_fresh=g.has_primary && t-s.primary.last<=c.main.freshness_seconds;
g.idle=age(t,s.last_input);
g.gap_age=clock_age(c.flow.gap_clock,t,s.last_input,s.last_main_accept);
if strcmp(c.flow.outlier_clock,'first_deviation')
    g.outlier_age=age(t,s.deviation_since);
else
    g.outlier_age=age(t,s.last_main_accept);
end
if ~isfinite(s.deviation_since), g.outlier_age=0; end
g.gap_allowed=g.has_primary && g.primary_fresh && g.gap_age<=c.flow.gap_hold_seconds;
g.outlier_allowed=g.has_primary && g.primary_fresh && ...
    c.flow.outlier_hold_seconds>0 && g.outlier_age<=c.flow.outlier_hold_seconds;
g.settle_age=0; g.settle_samples=s.settle_samples;
g.settle_pending=false;
if isfinite(s.reacquired_at)
    g.settle_age=t-s.reacquired_at;
end

if ~missing
    predictor=s.primary;
    if ~g.has_primary
        predictor=filter2win_model(main,c.main);
        if ~isfinite(predictor.level) && ~isempty(main.value)
            predictor.level=main.value(end); predictor.velocity=0; predictor.last=main.time(end);
        end
    end
    if isempty(main.time) && ~g.has_primary
        g.main_in=true;
    else
        [g.main_in,g.outside_exit,g.prediction,g.residual, ...
            g.enter_lower,g.enter_upper,g.exit_lower,g.exit_upper]=membership(t,x,predictor,c.main.band);
        if ~g.primary_fresh && ~g.main_in
            g.outside_exit=true; % no trusted hysteresis lock during warm-up/staleness.
        end
    end
    if g.main_in
        g.main_candidate=append(main,t,x,c.main.capacity);
        g.main_model=filter2win_model(g.main_candidate,c.main);
        g.main_ready=ready(g.main_model,g.main_candidate,c.main);
        if g.has_primary && isfinite(s.reacquired_at)
            g.settle_samples=s.settle_samples+1;
            g.settle_pending=g.primary_fresh && ...
                (g.settle_age<c.handover.settle_seconds || ...
                g.settle_samples<c.handover.settle_min_samples);
        end
    elseif g.outside_exit
        g.append_alt=true; g.store_alt=true;
        trial=append(alt,t,x,c.alt.capacity);
        trial_model=filter2win_model(trial,c.alt);
        previous_model=filter2win_model(alt,c.alt);
        [compatible,g.neighbor_distance,g.neighbor_limit]= ...
            alternative_compatible(alt,previous_model,trial_model,c.alt,t,x);
        g.incompatible=~isempty(alt.time) && ~compatible;
        if g.incompatible
            g.incompatible_since=s.alt_incompatible_since;
            if ~isfinite(g.incompatible_since), g.incompatible_since=t; end
            g.incompatible_samples=s.alt_incompatible_samples+1;
            g.incompatible_age=t-g.incompatible_since;
            g.incompatible_action=c.alt.on_incompatible;
            if strcmp(g.incompatible_action,'ignore') && ...
                    g.incompatible_samples>=c.alt.incompatible_min_samples && ...
                    g.incompatible_age>=c.alt.incompatible_min_seconds
                g.incompatible_action='restart';
            end
            switch g.incompatible_action
                case 'clear'
                    trial=struct('time',zeros(1,0),'value',zeros(1,0));
                    g.candidate_since=NaN; g.store_alt=false;
                case 'restart'
                    trial=struct('time',t,'value',x); g.candidate_since=t;
                case 'ignore'
                    trial=alt; g.store_alt=false;
            end
            trial_model=filter2win_model(trial,c.alt);
        elseif ~isfinite(g.candidate_since)
            g.candidate_since=t;
        end
        g.candidate=trial; g.candidate_model=trial_model;
        g.target_model=filter2win_model(trial,c.main);
        g.alt_metrics=window_metrics(trial,t);
        if ~isempty(trial.time) && isfinite(g.candidate_since)
            g.alt_confirmation=trial.time(end)-g.candidate_since;
        end
        g.alt_quality=quality(trial_model,c.alt.band);
        g.target_quality=quality(g.target_model,c.main.band);
        if isfinite(c.alt.relative_mad_ratio) && g.has_primary
            scale=max(s.primary.mad,c.main.band.mad_floor);
            g.relative_quality=isfinite(trial_model.mad) && ...
                trial_model.mad<=c.alt.relative_mad_ratio*scale;
        end
        full=trial_model.n>=c.alt.min_samples && ...
            g.alt_metrics.span>=c.alt.min_span_seconds && ...
            g.alt_confirmation>=c.alt.confirm_seconds;
        partial=c.alt.allow_partial && trial_model.n>=c.alt.partial_min_samples && ...
            g.alt_metrics.span>=c.alt.partial_min_span_seconds && ...
            g.alt_confirmation>=c.alt.partial_confirm_seconds;
        gap_ok=g.alt_metrics.max_gap<=c.alt.max_gap_seconds;
        fresh=g.alt_metrics.age<=c.alt.freshness_seconds;
        % An ignored point cannot confirm or promote a retained hypothesis.
        g.alt_ready=g.store_alt && ~g.incompatible && (full || partial) && ...
            gap_ok && fresh && g.alt_quality && g.relative_quality && ...
            g.target_quality;
        g.partial=~full && partial;
        g.wait_elapsed=age(t,s.deviation_since);
        if ~isfinite(s.deviation_since), g.wait_elapsed=0; end
    end
end

% Blending uses retained numerical models; status 14 is its only control mode.
g.blend_elapsed=s.blend_elapsed;
if s.status==14
    advance=~missing || strcmp(c.handover.on_missing,'continue');
    if strcmp(c.handover.on_missing,'pause') && s.last_input~=s.last_tick
        advance=false;
    end
    if g.incompatible && strcmp(g.incompatible_action,'ignore'), advance=false; end
    if advance, g.blend_elapsed=s.blend_elapsed+t-s.last_tick; end
end
target=s.target;
if s.status==14 && g.append_alt && ~g.incompatible && g.alt_quality
    if quality(g.target_model,c.main.band), target=g.target_model; end
end
g.target=target;
g.target_fresh=isfinite(target.level) && t-target.last<=c.alt.freshness_seconds;
g.blend_lost=~g.target_fresh || ...
    (missing && (~g.gap_allowed || strcmp(c.handover.on_missing,'cancel')));

e=struct();
e.TIMEOUT=isfinite(s.last_input) && g.idle>c.flow.timeout_seconds;
e.BLEND_RETURN=s.status==14 && ~missing && g.main_in && c.handover.cancel_on_main_return;
e.BLEND_LOST=s.status==14 && g.blend_lost;
e.BLEND_INCOMPATIBLE=s.status==14 && ~missing && g.incompatible && ...
    ~strcmp(g.incompatible_action,'ignore');
e.BLEND_DONE=s.status==14 && ~g.blend_lost && ...
    g.blend_elapsed>=c.handover.duration_seconds;
e.BLEND_ACTIVE=s.status==14 && ~g.blend_lost && ~e.BLEND_DONE;
e.EMPTY_MISSING=missing && ~g.has_primary && isempty(main.time) && isempty(alt.time);
e.WARMUP_MISSING=missing && ~g.has_primary && ~e.EMPTY_MISSING;
e.GAP_EXPIRED=missing && g.has_primary && ~g.gap_allowed;
e.GAP_HOLD=missing && g.gap_allowed;
e.MAIN_SETTLING=~missing && g.main_in && g.primary_fresh && g.settle_pending;
e.MAIN_ACCEPT=~missing && g.main_in && ~g.settle_pending && (g.primary_fresh || g.main_ready);
e.MAIN_WARMUP=~missing && g.main_in && ~g.primary_fresh && ~g.main_ready;
e.INITIAL_REBASE=~missing && ~g.has_primary && g.append_alt && g.alt_ready;
e.ALTERNATIVE_READY=~missing && g.has_primary && g.append_alt && ...
    g.alt_ready && g.wait_elapsed>=c.handover.wait_seconds;
quality_count=g.candidate_model.n>=c.alt.min_samples || ...
    (c.alt.allow_partial && g.candidate_model.n>=c.alt.partial_min_samples);
e.ALT_REJECT=~missing && g.append_alt && ~g.incompatible && ...
    quality_count && ...
    (~g.alt_quality || ~g.relative_quality || ~g.target_quality);
e.ALT_INCOMPATIBLE=~missing && g.append_alt && g.incompatible;
e.WARMUP_OUTLIER=~missing && ~g.has_primary && ~g.main_in && ~g.alt_ready;
e.OUTLIER_FIRST=~missing && g.has_primary && g.append_alt && isempty(alt.time);
e.ALT_COLLECT=~missing && g.has_primary && g.append_alt && ~isempty(alt.time);
e.DEAD_BAND=~missing && ~g.main_in && ~g.outside_exit;
e.FALLBACK=true;
main_metrics=window_metrics(g.main_candidate,t);
g.metrics=struct('main_count',main_metrics.count,'main_span',main_metrics.span, ...
    'main_age',g.main_before.age,'main_mad',g.main_model.mad, ...
    'main_trimmed_range',g.main_model.trimmed_range, ...
    'alt_count',g.alt_metrics.count,'alt_span',g.alt_metrics.span, ...
    'alt_confirmed',g.alt_confirmation,'alt_max_gap',g.alt_metrics.max_gap, ...
    'alt_age',g.alt_metrics.age,'alt_mad',g.candidate_model.mad, ...
    'alt_trimmed_range',g.candidate_model.trimmed_range, ...
    'alt_incompatible_samples',g.incompatible_samples, ...
    'alt_incompatible_age',g.incompatible_age, ...
    'neighbor_distance',g.neighbor_distance, ...
    'alt_abs_velocity',abs(g.candidate_model.velocity),'residual_abs',abs(g.residual), ...
    'gap_age',g.gap_age,'outlier_age',g.outlier_age,'idle',g.idle, ...
    'wait_elapsed',g.wait_elapsed,'blend_elapsed',g.blend_elapsed, ...
    'settle_age',g.settle_age,'settle_samples',g.settle_samples);
g.events=e;
end

function samples=append(samples,t,x,capacity)
samples.time=[samples.time t]; samples.value=[samples.value x];
if numel(samples.time)>capacity
    samples.time=samples.time(end-capacity+1:end);
    samples.value=samples.value(end-capacity+1:end);
end
end

function m=window_metrics(samples,t)
m=struct('count',numel(samples.time),'span',0,'max_gap',0,'age',Inf);
if m.count>0
    m.span=samples.time(end)-samples.time(1); m.age=t-samples.time(end);
end
if m.count>1, m.max_gap=max(diff(samples.time)); end
end

function ok=ready(model,samples,w)
metrics=window_metrics(samples,model.last);
ok=model.n>=w.min_samples && metrics.span>=w.min_span_seconds && ...
    metrics.max_gap<=w.max_gap_seconds && quality(model,w.band);
end

function ok=quality(model,b)
band=filter2win_band(model,b,0); ok=band.quality;
end

function [ok,distance,limit]=alternative_compatible(samples,previous,trial,w,t,x)
distance=NaN; limit=NaN; ok=true;
if isempty(samples.time), return; end
% The first candidate is a usable positional anchor even when a linear
% slope cannot yet be estimated. Known V is applied from the first sample.
if ~isfinite(previous.level)
    previous.level=samples.value(end); previous.last=samples.time(end);
    previous.velocity=0;
    if strcmp(w.model,'known_velocity'), previous.velocity=w.known_velocity; end
end
switch w.compatibility.method
    case 'median_band'
        ok=membership(t,x,previous,w.band);
    case 'nearest_neighbor'
        elapsed=t-samples.time(end);
        distance=abs((x-samples.value(end))-previous.velocity*elapsed);
        limit=w.compatibility.neighbor_radius+ ...
            w.compatibility.neighbor_growth_per_second*elapsed;
        ok=isfinite(distance) && isfinite(limit) && distance<=limit;
    case 'trimmed_range'
        % Both a bounded global cluster and membership of the NEW point are
        % required. Trimming a remote point must not make it evidence.
        ok=isfinite(trial.trimmed_range) && ...
            trial.trimmed_range<=w.band.max_trimmed_range && ...
            membership(t,x,trial,w.band);
end
% Global MAD/range/velocity limits remain mandatory for promotion even
% when the chosen local criterion is nearest-neighbor connectivity.
end

function [inside,outside,prediction,residual,lower,upper,exit_lower,exit_upper]=membership(t,x,model,b)
prediction=model.level+model.velocity*(t-model.last); residual=x-prediction;
band=filter2win_band(model,b,t-model.last);
lower=band.lower; upper=band.upper;
exit_lower=band.exit_lower; exit_upper=band.exit_upper;
inside=isfinite(residual) && residual>=-lower && residual<=upper;
outside=isfinite(residual) && (residual< -exit_lower || residual>exit_upper);
end

function seconds=age(t,reference)
if isfinite(reference), seconds=t-reference; else, seconds=Inf; end
end

function seconds=clock_age(kind,t,last_input,last_main)
if strcmp(kind,'last_input'), reference=last_input; else, reference=last_main; end
seconds=age(t,reference);
end
