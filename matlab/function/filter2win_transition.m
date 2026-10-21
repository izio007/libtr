function [ok,s,step]=filter2win_transition(cfg,s,t,x,missing)
% Schema 2 fixed transition: expire local windows, calculate guards, choose status.
% Expiry is a trial; only successful execution publishes its result to ctx.
step=struct('time',t,'measurement',x,'missing',missing, ...
    'previous_status',s.status,'main_before',s.main.count,'alt_before',s.alt.count, ...
    'status',s.status,'event','','guards',struct(),'start_deviation',false,'reason','');
s.tact=s.tact+1;
[s,ok]=expire_windows(s,cfg,t);
if ~ok, step.reason='TIME_ARITHMETIC_OVERFLOW'; return; end
g=filter2win_features(cfg,s,t,x,missing);
[destination,event]=select_event(g.events);
% Zero handover duration is an explicitly supported instantaneous switch.
if destination==14 && cfg.handover.duration_seconds==0, destination=6; end
step.status=destination; step.event=event; step.guards=g;
step.start_deviation=~missing && ~g.main_in && g.has_primary && ~isfinite(s.deviation_since);
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

function [destination,event]=select_event(events)
% Fixed legacy precedence, matching the former default schema-2 profile.
if events.TIMEOUT
    destination=9; event='TIMEOUT';
elseif events.BLEND_RETURN
    destination=2; event='BLEND_RETURN';
elseif events.BLEND_LOST
    destination=8; event='BLEND_LOST';
elseif events.BLEND_INCOMPATIBLE
    destination=10; event='BLEND_INCOMPATIBLE';
elseif events.BLEND_DONE
    destination=6; event='BLEND_DONE';
elseif events.BLEND_ACTIVE
    destination=14; event='BLEND_ACTIVE';
elseif events.EMPTY_MISSING
    destination=0; event='EMPTY_MISSING';
elseif events.WARMUP_MISSING
    destination=12; event='WARMUP_MISSING';
elseif events.GAP_EXPIRED
    destination=8; event='GAP_EXPIRED';
elseif events.GAP_HOLD
    destination=7; event='GAP_HOLD';
elseif events.MAIN_SETTLING
    destination=16; event='MAIN_SETTLING';
elseif events.MAIN_ACCEPT
    destination=2; event='MAIN_ACCEPT';
elseif events.MAIN_WARMUP
    destination=1; event='MAIN_WARMUP';
elseif events.INITIAL_REBASE
    destination=13; event='INITIAL_REBASE';
elseif events.ALTERNATIVE_READY
    destination=14; event='ALTERNATIVE_READY';
elseif events.ALT_REJECT
    destination=5; event='ALT_REJECT';
elseif events.ALT_INCOMPATIBLE
    destination=10; event='ALT_INCOMPATIBLE';
elseif events.WARMUP_OUTLIER
    destination=11; event='WARMUP_OUTLIER';
elseif events.OUTLIER_FIRST
    destination=3; event='OUTLIER_FIRST';
elseif events.ALT_COLLECT
    destination=4; event='ALT_COLLECT';
elseif events.DEAD_BAND
    destination=3; event='DEAD_BAND';
else
    destination=15; event='FALLBACK';
end
end
