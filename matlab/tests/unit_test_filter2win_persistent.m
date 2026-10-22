function unit_test_filter2win_persistent
% Independent analytical fixtures: FIFO identity, clocks, gates and outputs.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'matlab','tests','support'));
p=jsondecode(fileread(fullfile(root,'matlab','tests','configs','filter2win_schema3_cases.json')));
c=filter2win_config; assert(c.schema_version==3);
for name={'main','alt'}
    w=c.(name{1}); w.capacity=p.capacity; w.min_samples=p.min_samples;
    w.min_span_seconds=p.min_span_seconds; w.trim.min_samples=p.trim_min_samples;
    w.trim.scale_floor=p.scale_floor; w.band.max_mad=p.max_mad; w.band.max_range=p.max_range;
    w.band.lower_margin=p.band_radius; w.band.upper_margin=p.band_radius; c.(name{1})=w;
end
c.flow.gap_hold_seconds=p.hold_seconds; c.flow.outlier_hold_seconds=p.hold_seconds;
% Pure selection uses hand-written facts: no FIFO, timing or numeric preparation.
facts=struct('missing',false,'has_active',true,'no_samples',false, ...
    'has_route',true,'route_is_main',true,'route_is_active',false, ...
    'window_was_empty',false,'accepted',true,'ready_after',true, ...
    'can_hold',true,'main_hold',false,'wait_done',false,'instant_switch',false, ...
    'blend_active',true,'blend_done',false,'cancel_on_missing',false);
decision=filter2win_persistent_transition(facts);
assert(strcmp(decision.event,'SWITCH_WAIT') && strcmp(decision.action,'wait'));
facts.route_is_main=false; facts.route_is_active=true;
decision=filter2win_persistent_transition(facts);
assert(strcmp(decision.event,'BLEND_ACTIVE') && strcmp(decision.action,'blend'));
facts.blend_done=true;
decision=filter2win_persistent_transition(facts);
assert(strcmp(decision.event,'BLEND_ACTIVE') && strcmp(decision.action,'switch'));
facts.route_is_main=true; facts.route_is_active=false; facts.wait_done=true;
facts.blend_active=false; facts.blend_done=false;
decision=filter2win_persistent_transition(facts);
assert(strcmp(decision.event,'SWITCH_READY') && strcmp(decision.action,'blend'));
facts.instant_switch=true;
decision=filter2win_persistent_transition(facts);
assert(strcmp(decision.event,'SWITCH_READY') && strcmp(decision.action,'switch'));
codes=[]; records={};
step(c,struct(),p.baseline_time(1),NaN);
a=step(c,struct(),p.baseline_time(1),p.base); step(c,a,p.baseline_time(2),NaN);
a=baseline(c,p); assert(a.FILTER_STATE.active==1 && a.FILTER_STATUS==13);
a=step(c,a,p.candidate_time(1),p.base); assert(a.FILTER_STATUS==2);
b=baseline(c,p); original=b.FILTER_STATE.main;
for k=1:numel(p.candidate_time)
    [b,d]=step(c,b,p.candidate_time(k),p.candidate_value(k));
    assert(d.status==p.candidate_status(k) && b.FILTER_STATE.alt.count==p.candidate_counts(k));
    assert(isequaln(b.FILTER_STATE.main,original));
    if ~isempty(d.removed.time)
        assert(isequal(d.removed.time,p.candidate_time(1)) && d.removed.value==p.gross);
    end
end
[~,~,q]=fifo_double('read',b.FILTER_STATE.alt);
assert(isequal(q.time,p.candidate_retained_time(:).') && all(q.value==p.alternative));
[b,d]=step(c,b,p.hold_boundary_time,p.alternative);
assert(d.status==15 && d.active_window==1 && d.accepted && d.output==p.base);
assert(strcmp(d.reason,'MAIN_PROLONGATION_ACTIVE') && b.FILTER_STATE.last_accept(1)==p.baseline_time(end));
assert(isequaln(b.FILTER_STATE.main,original));
[b,d]=step(c,b,p.selection_time,p.alternative);
assert(d.status==6 && d.active_window==2 && d.output==p.alternative);
oldB=b.FILTER_STATE.alt; b=step(c,b,p.return_time,p.base);
assert(b.FILTER_STATE.active==1 && b.X_FILTERED_OUTPUT==p.base && isequaln(oldB,b.FILTER_STATE.alt));
for k=1:numel(p.gap_times)
    [gap,d]=step(c,b,p.gap_times(k),NaN);
    assert(d.status==p.gap_status(k));
    assert(isequaln(gap.FILTER_STATE.main,b.FILTER_STATE.main) && isequaln(gap.FILTER_STATE.alt,b.FILTER_STATE.alt));
end
% First accepted hit in ready B after a long gap, then immediate return.
gap=step(c,b,p.gap_times(end),NaN);
gap=step(c,gap,p.gap_times(end)+p.slow_time(end),p.alternative);
assert(gap.FILTER_STATE.active==2 && gap.FILTER_STATUS==6);
gap=step(c,gap,p.gap_times(end)+p.slow_time(end)+p.slow_time(end),p.base);
assert(gap.FILTER_STATE.active==1 && gap.FILTER_STATUS==6);
% Reject inside a band, before changing even one FIFO cell.
[bad,d]=step(c,b,p.reject_time,p.base+p.reject_offset);
assert(d.status==5 && ~d.accepted && isequaln(bad.FILTER_STATE.main,b.FILTER_STATE.main) && isequaln(bad.FILTER_STATE.alt,b.FILTER_STATE.alt));
assert(d.guards.proposal.stats.count==min(c.main.capacity,b.FILTER_STATE.main.count+1));
assert(d.guards.window_config.min_samples==c.main.min_samples && d.guards.hold_limit==c.flow.outlier_hold_seconds);
[bad,d]=step(c,b,p.reject_time,p.middle); assert(d.status==10 && ~d.accepted);
assert(isequaln(bad.FILTER_STATE.main,b.FILTER_STATE.main) && isequaln(bad.FILTER_STATE.alt,b.FILTER_STATE.alt));
warm=struct();
for k=1:numel(p.baseline_time)-1, warm=step(c,warm,p.baseline_time(k),p.base); end
warm=step(c,warm,p.baseline_time(end),p.gross); assert(warm.FILTER_STATUS==11);
% Count is identical; actual time span is not.
for fast=[true false]
    times=p.slow_time; if fast, times=p.fast_time; end
    a=struct();
    for k=1:numel(times), a=step(c,a,times(k),p.base); end
    assert(a.FILTER_VALID==~fast);
end
% Zero hold never fills or clears a FIFO.
z=c; z.flow.outlier_hold_seconds=0; z.flow.gap_hold_seconds=0;
a=baseline(z,p); [gap,d]=step(z,a,p.candidate_time(1),NaN);
assert(~d.valid && isequaln(gap.FILTER_STATE.main,a.FILTER_STATE.main));
a=step(z,a,p.candidate_time(1),p.gross); assert(~a.FILTER_VALID && a.FILTER_STATE.alt.count==1);
a=baseline(z,p);
for k=1:numel(p.candidate_time), a=step(z,a,p.candidate_time(k),p.candidate_value(k)); end
assert(a.FILTER_STATE.active==2 && a.FILTER_STATUS==6);
% Smoothstep has an independent closed-form reference.
smooth=c; smooth.handover.duration_seconds=p.blend_duration;
a=baseline(smooth,p);
for k=1:numel(p.candidate_time), a=step(smooth,a,p.candidate_time(k),p.candidate_value(k)); end
a=step(smooth,a,p.selection_time,p.alternative);
assert(a.FILTER_STATUS==14 && a.X_FILTERED_OUTPUT==p.base);
for k=2:numel(p.blend_offsets)
    a=step(smooth,a,p.selection_time+p.blend_offsets(k),p.alternative);
    expected=p.base+(p.alternative-p.base)*p.blend_weights(k);
    assert(abs(a.X_FILTERED_OUTPUT-expected)<=p.tolerance);
end
assert(a.FILTER_STATUS==6);
% Waiting for A during A->B blending pauses the blend, not its existence.
% Waiting is unsupported even with on_missing=continue: it is not a gap tick.
for mode={'pause','continue'}
    paused=smooth; paused.handover.return_wait_seconds=p.wait_seconds;
    paused.handover.on_missing=mode{1};
    a=baseline(paused,p);
    for k=1:numel(p.candidate_time), a=step(paused,a,p.candidate_time(k),p.candidate_value(k)); end
    a=step(paused,a,p.selection_time,p.alternative);
    assert(a.FILTER_STATUS==14 && a.FILTER_STATE.active==2);
    [a,d]=step(paused,a,p.selection_time+1,p.base);
    assert(strcmp(d.event,'SWITCH_WAIT') && d.status==15 && d.accepted && d.route==1);
    assert(d.active_window==2 && abs(d.output-p.base)<=p.tolerance);
    assert(a.FILTER_STATE.blend_duration==p.blend_duration && a.FILTER_STATE.blend_elapsed==0);
    [a,d]=step(paused,a,p.selection_time+2,p.alternative);
    assert(d.status==14 && d.active_window==2 && abs(d.output-p.base)<=p.tolerance);
    assert(a.FILTER_STATE.blend_duration==p.blend_duration && a.FILTER_STATE.blend_elapsed==0);
    [a,d]=step(paused,a,p.selection_time+3,p.alternative);
    assert(a.FILTER_STATE.blend_elapsed==1);
    assert(abs(d.output-(p.base+(p.alternative-p.base)*0.15625))<=p.tolerance);
    [a,d]=step(paused,a,p.selection_time+6,p.alternative);
    assert(d.status==6 && abs(d.output-p.alternative)<=p.tolerance);
    assert(a.FILTER_STATE.blend_duration==0);
end
% An unavailable published output selects a ready returning A immediately,
% even when the current outlier hold is longer than the preceding gap hold.
recovery=c; recovery.flow.gap_hold_seconds=0;
recovery.handover.duration_seconds=0;
recovery.handover.return_wait_seconds=0;
recovery.handover.return_duration_seconds=p.blend_duration;
a=baseline(recovery,p);
for k=1:numel(p.candidate_time), a=step(recovery,a,p.candidate_time(k),p.candidate_value(k)); end
a=step(recovery,a,p.selection_time,p.alternative);
assert(a.FILTER_STATE.active==2 && a.FILTER_VALID);
[a,d]=step(recovery,a,p.return_time,NaN);
assert(d.status==8 && d.active_window==2 && ~d.valid && isnan(a.FILTER_STATE.last_output));
[a,d]=step(recovery,a,p.reject_time,p.base);
assert(d.guards.age<=recovery.flow.outlier_hold_seconds);
assert(d.status==6 && d.active_window==1 && d.accepted);
assert(abs(d.output-p.base)<=p.tolerance && a.FILTER_STATE.blend_duration==0);
% Removed rule configurations are rejected before any state is changed.
a=baseline(c,p); old=a; obsolete=c; obsolete.rules=[];
[rc,out]=filter2win(obsolete,a,p.candidate_time(1),p.alternative,false);
assert(rc==1 && isequaln(out,old));
assert(~isfield(a.FILTER_STATE,'rule_since') && ~isfield(a.FILTER_STATE,'rule_hits'));
% Wait is measured from the first accepted candidate, not from tick number.
waiting=c; waiting.handover.wait_seconds=p.wait_seconds;
a=baseline(waiting,p);
for k=1:numel(p.candidate_time), a=step(waiting,a,p.candidate_time(k),p.candidate_value(k)); end
assert(a.FILTER_STATUS==15);
for k=1:numel(p.wait_times)
    a=step(waiting,a,p.wait_times(k),p.alternative);
    if k<numel(p.wait_times), assert(a.FILTER_STATUS==15); end
end
assert(a.FILTER_STATUS==6);
% Band overlap is checked with explicit retained history, not a truth hint.
overlap=c; overlap.main.band.lower_margin=p.overlap_radius; overlap.main.band.upper_margin=p.overlap_radius;
overlap.alt.band.lower_margin=p.overlap_radius; overlap.alt.band.upper_margin=p.overlap_radius;
fixture=b; fixture.FILTER_STATE.parameters=overlap;
[~,d]=step(overlap,fixture,p.reject_time,p.overlap_value); assert(d.route==fixture.FILTER_STATE.active);
[~,d]=step(overlap,fixture,p.reject_time,p.base+p.reject_offset); assert(d.route==1);
% Unequal radii: normalized distance can choose the farther raw coordinate.
unequal=overlap;
unequal.main.band.lower_margin=p.normalized_main_radius; unequal.main.band.upper_margin=p.normalized_main_radius;
unequal.alt.band.lower_margin=p.normalized_alt_radius; unequal.alt.band.upper_margin=p.normalized_alt_radius;
fixture=b; fixture.FILTER_STATE.parameters=unequal;
[~,d]=step(unequal,fixture,p.reject_time,p.normalized_value);
assert(d.route==2 && d.guards.distance(2)<d.guards.distance(1));
% Full FIFO: reject spread independently of the new-point outlier test.
spread=c; spread.main.trim.k=p.nontrimming_k;
full=struct();
for k=1:numel(p.full_history_time), full=step(spread,full,p.full_history_time(k),p.base); end
assert(full.FILTER_STATE.main.count==spread.main.capacity && full.FILTER_VALID);
[refused,d]=step(spread,full,p.full_reject_time,p.base+p.reject_offset);
assert(strcmp(d.reason,'PROPOSED_SPREAD_REJECTED') && ~d.accepted);
assert(isequaln(refused.FILTER_STATE.main,full.FILTER_STATE.main));
assert(isequaln(refused.FILTER_STATE.alt,full.FILTER_STATE.alt));
assert(isequal(refused.FILTER_STATE.last_accept,full.FILTER_STATE.last_accept));
assert(isempty(d.evicted.time) && isempty(d.removed.time));
% The exact range boundary is inclusive; a successful write evicts oldest.
boundary=spread; boundary.main.band.max_range=abs((p.base+p.reject_offset)-p.base);
fixture=full; fixture.FILTER_STATE.parameters=boundary;
[accepted,d]=step(boundary,fixture,p.full_reject_time,p.base+p.reject_offset);
assert(d.accepted && d.evicted.time==p.full_history_time(1));
assert(accepted.FILTER_STATE.main.count==boundary.main.capacity);
% Shift both coordinate and clock origin: no hidden nominal plateau/time.
a=struct(); shifted=struct();
time=[p.baseline_time(:).' p.candidate_time(:).' p.hold_boundary_time p.selection_time]; values=[p.base*ones(size(p.baseline_time(:).')) p.candidate_value(:).' p.alternative p.alternative];
for k=1:numel(time)
    [a,d]=step(c,a,time(k),values(k));
    [shifted,e]=step(c,shifted,time(k)+p.translation_time,values(k)+p.translation_value);
    assert(d.status==e.status && d.valid==e.valid);
    if d.valid, assert(abs(e.output-d.output-p.translation_value)<=p.tolerance); end
end
% Refused API calls are atomic, including malformed configuration and state.
old=a;
[rc,a]=filter2win(c,a,time(end),p.base,false); assert(rc==1 && isequaln(a,old));
invalid=c; invalid.main.trim.scale_floor=0;
[rc,a]=filter2win(invalid,old,time(end)+p.slow_time(end),p.base,false); assert(rc==1 && isequaln(a,old));
invalid=old; invalid.FILTER_STATE.active=NaN;
[rc,out]=filter2win(c,invalid,time(end)+p.slow_time(end),p.base,false); assert(rc==1 && isequaln(out,invalid));
% A finite API time step can still overflow the active forecast horizon.
% With an infinite hold, 0*Inf in a constant model must not publish NaN as
% ordinary unavailability: refuse the tick and retain the complete context.
overflow=c; overflow.flow.gap_hold_seconds=Inf;
a=struct(); far_time=[-1e308 -9e307 -8e307 -7e307];
for k=1:numel(far_time)
    [rc,a]=filter2win(overflow,a,far_time(k),p.base,false); assert(rc==0);
end
[rc,a]=filter2win(overflow,a,0,NaN,true);
assert(rc==0 && a.X_FILTERED_OUTPUT==p.base);
old=a;
[rc,out,d]=filter2win(overflow,old,1.7e308,NaN,true);
assert(rc==1 && strcmp(d.reason,'NUMERIC_OUTPUT_OVERFLOW') && isequaln(out,old));
% A robust cleanup can reduce a previously ready base below min_samples.
% Retained test history is explicitly supplied; no stale readiness latch.
edge=c; edge.alt.capacity=p.cleanup_capacity; edge.alt.trim.min_samples=p.cleanup_capacity;
edge.alt.trim.k=p.cleanup_k; edge.alt.trim.mad_scale=p.cleanup_scale;
edge.alt.trim.scale_floor=p.cleanup_floor; edge.handover.duration_seconds=p.blend_duration;
fixture=b; fixture.FILTER_STATE.parameters=edge;
[~,q]=fifo_double('init',[],edge.alt.capacity);
for j=1:numel(p.cleanup_times)
    [~,q]=fifo_double('push',q,p.cleanup_times(j),p.alternative+p.cleanup_offsets(j));
end
fixture.FILTER_STATE.alt=q;
fixture.FILTER_STATE.active=2; fixture.FILTER_STATE.status=14;
fixture.FILTER_STATE.blend_duration=p.blend_duration; fixture.FILTER_STATE.blend_elapsed=0;
fixture.FILTER_STATE.blend_start=p.return_time; fixture.FILTER_STATE.blend_from=p.base;
fixture.FILTER_STATE.last_accept(2)=p.return_time;
fixture.FILTER_STATE.last_supported=true;
[depleted,d]=step(edge,fixture,p.reject_time,p.alternative+p.cleanup_new_offset);
assert(~d.valid && depleted.FILTER_STATE.active==0 && depleted.FILTER_STATUS==4);
assert(d.route==2 && d.accepted && d.alt_count==2 && ~d.windows(2).ready);
assert(strcmp(d.reason,'BASE_NO_LONGER_READY_AFTER_REMOVAL'));
assert(isequaln(depleted.FILTER_STATE.main,fixture.FILTER_STATE.main));
step(edge,depleted,p.reject_time+p.slow_time(end),p.alternative+p.cleanup_new_offset);
% The same loss in A must identify A, even outside a blend. With five values
% [10,10.1,10.2,10.3,10.2], median=10.2 and the 0.05 band retains two 10.2s.
edge=c; edge.main.capacity=p.cleanup_capacity; edge.main.trim.min_samples=p.cleanup_capacity;
edge.main.trim.k=p.cleanup_k; edge.main.trim.mad_scale=p.cleanup_scale;
edge.main.trim.scale_floor=p.cleanup_floor;
a=struct();
for k=1:numel(p.baseline_time)
    a=step(edge,a,p.baseline_time(k),p.base+p.cleanup_offsets(k));
end
assert(a.FILTER_STATE.active==1 && a.FILTER_VALID && a.FILTER_STATE.main.count==4);
oldB=a.FILTER_STATE.alt;
[depleted,d]=step(edge,a,4,p.base+p.cleanup_new_offset);
assert(d.status==1 && d.route==1 && d.accepted && d.active_window==0 && ~d.valid);
assert(strcmp(d.reason,'BASE_NO_LONGER_READY_AFTER_REMOVAL'));
assert(d.main_count==2 && ~d.windows(1).ready && isequaln(depleted.FILTER_STATE.alt,oldB));
[~,~,retained]=fifo_double('read',depleted.FILTER_STATE.main);
assert(isequal(retained.time,[2 4]) && all(abs(retained.value-(p.base+p.cleanup_new_offset))<=p.tolerance));
% Real-time linear and known-velocity models use the same physical samples.
for model={'linear','known_velocity'}
    moving=c;
    for name={'main','alt'}
        moving.(name{1}).model=model{1}; moving.(name{1}).known_velocity=p.line_velocity;
    end
    a=struct();
    for j=1:numel(p.slow_time)
        a=step(moving,a,p.slow_time(j),p.base+p.line_velocity*p.slow_time(j));
    end
    assert(a.FILTER_VALID && abs(a.X_FILTERED_OUTPUT-p.base-p.line_velocity*p.slow_time(end))<=p.tolerance);
end
% Explicit pause/continue/cancel branches of a smooth transition.
for mode={'pause','continue','cancel'}
    transition=smooth; transition.handover.on_missing=mode{1};
    a=baseline(transition,p);
    for j=1:numel(p.candidate_time), a=step(transition,a,p.candidate_time(j),p.candidate_value(j)); end
    a=step(transition,a,p.selection_time,p.alternative);
    [a,d]=step(transition,a,p.selection_time+p.blend_offsets(2),NaN);
    if strcmp(mode{1},'cancel')
        assert(~d.valid && d.status==8);
    elseif strcmp(mode{1},'pause')
        assert(d.status==14 && abs(d.output-p.base)<=p.tolerance);
    else
        expected=p.base+(p.alternative-p.base)*p.blend_weights(2);
        assert(d.status==14 && abs(d.output-expected)<=p.tolerance);
    end
    if ~strcmp(mode{1},'cancel')
        % The first accepted tick after a gap follows the selected clock rule.
        [a,d]=step(transition,a,p.selection_time+p.blend_offsets(3),p.alternative);
        expected=p.base; elapsed=0;
        if strcmp(mode{1},'continue')
            expected=p.base+(p.alternative-p.base)*p.blend_weights(3); elapsed=2;
        end
        assert(d.status==14 && abs(d.output-expected)<=p.tolerance);
        assert(a.FILTER_STATE.blend_elapsed==elapsed);
        if strcmp(mode{1},'pause')
            [a,d]=step(transition,a,p.selection_time+3,p.alternative);
            assert(a.FILTER_STATE.blend_elapsed==1);
            assert(abs(d.output-(p.base+(p.alternative-p.base)*0.15625))<=p.tolerance);
        end
    end
end
assert(isequal(unique(codes),p.required_statuses(:).'));
save(fullfile(pwd,'filter2win_schema3_contract.mat'),'records','codes','p','c');
fid=fopen(fullfile(pwd,'FILTER_STATUS_schema3.log'),'w','n','UTF-8'); assert(fid~=-1);
cleanup=onCleanup(@() fclose(fid));
for k=1:numel(records), fprintf(fid,'%s\n',filter2win_debug_line(records{k})); end

    function [state,d]=step(cfg,state,t,x)
        [rc,state,d]=filter2win(cfg,state,t,x,isnan(x));
        assert(rc==0,'libtr:f2w:Schema3','Refused: %s',d.reason);
        assert(state.FILTER_STATUS==state.FILTER_STATE.status && d.valid==isfinite(d.output));
        codes(end+1)=d.status; records{end+1}=d;
        if d.valid, assert(d.active_window>0 && d.windows(d.active_window).ready); end
    end
    function a=baseline(cfg,p)
        a=struct();
        for j=1:numel(p.baseline_time), a=step(cfg,a,p.baseline_time(j),p.base); end
    end
end
