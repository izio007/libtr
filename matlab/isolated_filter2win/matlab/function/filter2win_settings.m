function cfg=filter2win_settings(p)
% Expand a practical profile once, before processing observations.
% Pure conversion: no files, timestamps, observed coordinates or side effects.
allowed(p,{'profile_version','window','main','alt','hold','handover','return_to_main','advanced'});
assert(isfield(p,'profile_version') && isequal(p.profile_version,1), ...
    'libtr:f2w:Settings','Expected profile_version=1');
for name={'window','hold','handover','return_to_main'}
    assert(isfield(p,name{1}),'libtr:f2w:Settings','Missing section: %s',name{1});
end
keys={'capacity','min_samples','min_span_seconds','radius','max_mad','max_range'};
allowed(p.window,keys);
assert(all(isfield(p.window,keys)),'libtr:f2w:Settings','Incomplete window settings');
a=p.window; b=a;
if isfield(p,'main'), a=merge(a,p.main); end
if isfield(p,'alt'), b=merge(b,p.alt); end
cfg=struct('schema_version',3,'main',window(a),'alt',window(b));
allowed(p.hold,{'outliers_seconds','missing_seconds'});
assert(all(isfield(p.hold,{'outliers_seconds','missing_seconds'})), ...
    'libtr:f2w:Settings','Incomplete hold settings');
cfg.flow=struct('outlier_hold_seconds',bound(p.hold.outliers_seconds), ...
    'gap_hold_seconds',bound(p.hold.missing_seconds));
for name={'handover','return_to_main'}
    v=p.(name{1}); allowed(v,{'wait_seconds','duration_seconds'});
    assert(all(isfield(v,{'wait_seconds','duration_seconds'})), ...
        'libtr:f2w:Settings','Incomplete transition settings');
end
cfg.handover=struct('wait_seconds',p.handover.wait_seconds, ...
    'return_wait_seconds',p.return_to_main.wait_seconds, ...
    'duration_seconds',p.handover.duration_seconds, ...
    'return_duration_seconds',p.return_to_main.duration_seconds, ...
    'curve','smoothstep','on_missing','pause');
names={'empty','warmup_gap','gap','expired','reject_quality','outside', ...
    'initial_collect','candidate_collect','initial_ready','track','switch', ...
    'wait','blend','outlier','warmup_reject','fallback'};
events={'EMPTY_MISSING','WARMUP_MISSING','GAP_HOLD','GAP_EXPIRED','QUALITY_REJECT', ...
    'OUTSIDE_BOTH','MAIN_ACCUMULATE','ALT_ACCUMULATE','INITIAL_READY','ACTIVE_ACCEPT', ...
    'SWITCH_READY','SWITCH_WAIT','BLEND_ACTIVE','OUTLIER_HOLD','WARMUP_REJECTED','FALLBACK'};
dest=[0 12 7 8 5 10 1 4 13 2 14 15 14 3 11 15];
priority=[100:-1:87 50 0];
for k=1:numel(names)
    cfg.rules(k)=struct('name',names{k},'event',events{k},'from',[], ...
        'to',dest(k),'enabled',true,'priority',priority(k), ...
        'min_dwell_seconds',0,'confirm_ticks',1,'confirm_seconds',0, ...
        'combine','ALL','conditions',[]);
end
if isfield(p,'advanced')
    z=p.advanced; allowed(z,{'main','alt','handover','rules'});
    for name={'main','alt'}
        if isfield(z,name{1})
            v=z.(name{1});
            allowed(v,{'model','known_velocity','linear_min_pair_seconds','trim','band'});
            if isfield(v,'band')
                % Practical fields have one owner; no ambiguous override.
                allowed(v.band,{'lower_margin','upper_margin','mad_multiplier','mad_floor', ...
                    'growth_per_second','max_adaptive_radius','max_abs_velocity'});
            end
            cfg.(name{1})=merge(cfg.(name{1}),v);
        end
    end
    if isfield(z,'handover')
        allowed(z.handover,{'curve','on_missing'});
        cfg.handover=merge(cfg.handover,z.handover);
    end
    if isfield(z,'rules')
        allowed(z.rules,names);
        for name=fieldnames(z.rules).'
            k=find(strcmp(names,name{1})); v=z.rules.(name{1});
            allowed(v,{'from','to','enabled','priority','min_dwell_seconds', ...
                'confirm_ticks','confirm_seconds','combine','conditions'});
            cfg.rules(k)=merge(cfg.rules(k),v);
        end
    end
end
for name={'main','alt'}
    for field={'max_adaptive_radius','max_abs_velocity','max_mad','max_range'}
        cfg.(name{1}).band.(field{1})=bound(cfg.(name{1}).band.(field{1}));
    end
end
for k=1:numel(cfg.rules)
    for j=1:numel(cfg.rules(k).conditions)
        cfg.rules(k).conditions(j).value=bound(cfg.rules(k).conditions(j).value);
    end
end
[ok,why]=filter2win_validate_persistent(cfg);
assert(ok,'libtr:f2w:Settings','Invalid resolved settings: %s',why);
cfg.rules=cfg.rules(:);
end

function w=window(v)
w=struct('capacity',v.capacity,'min_samples',v.min_samples, ...
    'min_span_seconds',v.min_span_seconds,'model','constant','known_velocity',0, ...
    'linear_min_pair_seconds',0,'trim_fraction',0, ...
    'trim',struct('min_samples',min(5,v.capacity),'k',4,'mad_scale',1.4826,'scale_floor',0.12), ...
    'band',struct('lower_margin',v.radius,'upper_margin',v.radius, ...
    'mad_multiplier',0,'mad_floor',0.12,'growth_per_second',0, ...
    'max_adaptive_radius',Inf,'max_mad',bound(v.max_mad), ...
    'max_range',bound(v.max_range),'max_abs_velocity',Inf));
end
function out=merge(out,changes)
allowed(changes,fieldnames(out));
for key=fieldnames(changes).'
    name=key{1}; value=changes.(name);
    if isstruct(out.(name)) && isscalar(out.(name))
        out.(name)=merge(out.(name),value);
    else
        out.(name)=value;
    end
end
end
function allowed(v,keys)
assert(isstruct(v) && isscalar(v),'libtr:f2w:Settings','Expected a settings object');
unknown=setdiff(fieldnames(v),keys);
assert(isempty(unknown),'libtr:f2w:Settings','Unknown setting: %s',strjoin(unknown,', '));
end
function x=bound(x)
if isequal(x,[]), x=Inf; end
end
