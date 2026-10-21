function [ok,reason]=filter2win_validate_persistent(c)
% Schema 3: persistent physical FIFOs, transactional robust admission.
ok=false; reason='INVALID_CONFIGURATION';
if ~object(c,{'schema_version','main','alt','flow','handover','rules'}) || ...
        ~integer(c.schema_version,3) || c.schema_version~=3, return; end
for name={'main','alt'}
    w=c.(name{1});
    if ~object(w,{'capacity','min_samples','min_span_seconds','model','known_velocity', ...
            'linear_min_pair_seconds','trim_fraction','trim','band'}), return; end
    if ~integer(w.capacity,2) || ~integer(w.min_samples,2) || w.min_samples>w.capacity || ...
            ~nonnegative(w.min_span_seconds,false) || ~number(w.known_velocity,false) || ...
            ~nonnegative(w.linear_min_pair_seconds,false) || ...
            ~choice(w.model,{'constant','linear','known_velocity'}) || ...
            ~number(w.trim_fraction,false) || w.trim_fraction~=0, return; end
    if strcmp(w.model,'linear') && w.min_samples<3, return; end
    r=w.trim;
    if ~object(r,{'min_samples','k','mad_scale','scale_floor'}) || ...
            ~integer(r.min_samples,3) || r.min_samples>w.capacity || ...
            ~positive(r.k) || ~positive(r.mad_scale) || ~positive(r.scale_floor), return; end
    b=w.band;
    fields={'lower_margin','upper_margin','mad_multiplier','mad_floor','growth_per_second', ...
            'max_adaptive_radius','max_mad','max_range','max_abs_velocity'};
    if ~object(b,fields), return; end
    for j=1:numel(fields)
        if ~nonnegative(b.(fields{j}),j>=6), return; end
    end
end
if ~object(c.flow,{'outlier_hold_seconds','gap_hold_seconds'}) || ...
        ~nonnegative(c.flow.outlier_hold_seconds,true) || ...
        ~nonnegative(c.flow.gap_hold_seconds,true), return; end
h=c.handover;
if ~object(h,{'wait_seconds','return_wait_seconds','duration_seconds','return_duration_seconds','curve','on_missing'}), return; end
for f={'wait_seconds','return_wait_seconds','duration_seconds','return_duration_seconds'}
    if ~nonnegative(h.(f{1}),false), return; end
end
if ~choice(h.curve,{'linear','smoothstep'}) || ~choice(h.on_missing,{'pause','continue','cancel'}), return; end
events={'EMPTY_MISSING','WARMUP_MISSING','GAP_HOLD','GAP_EXPIRED','QUALITY_REJECT', ...
    'OUTSIDE_BOTH','WARMUP_REJECTED','MAIN_ACCUMULATE','ALT_ACCUMULATE','INITIAL_READY', ...
    'ACTIVE_ACCEPT','SWITCH_READY','SWITCH_WAIT','BLEND_ACTIVE','OUTLIER_HOLD','FALLBACK'};
dest={0,12,7,8,5,10,11,1,4,13,2,[6 14],15,14,3,15};
modes=[0:8 10:15];
r=c.rules;
fields={'name','event','from','to','enabled','priority','min_dwell_seconds', ...
    'confirm_ticks','confirm_seconds','combine','conditions'};
if ~isstruct(r) || isempty(r) || ~isvector(r) || ~all(isfield(r,fields)), return; end
metrics={'count','span','mad','range','abs_velocity','residual_abs','age','wait_elapsed','blend_elapsed'};
for k=1:numel(r)
    a=r(k);
    if ~choice(a.event,events) || ~ischar(a.name) || ~isrow(a.name) || isempty(a.name) || ...
            ~integer(a.to,0) || ~ismember(a.to,[dest{strcmp(a.event,events)} 15]) || ...
            ~boolean(a.enabled) || ~number(a.priority,false) || ...
            ~nonnegative(a.min_dwell_seconds,false) || ~integer(a.confirm_ticks,1) || ...
            ~nonnegative(a.confirm_seconds,false) || ~choice(a.combine,{'ALL','ANY'}) || ...
            ~isa(a.from,'double') || ~isreal(a.from) || (~isempty(a.from) && ~isvector(a.from)) || ...
            any(~ismember(a.from,modes)), return; end
    q=a.conditions;
    if ~isempty(q)
        if ~isstruct(q) || ~isvector(q) || ~all(isfield(q,{'metric','operator','value'})), return; end
        for j=1:numel(q)
            if ~choice(q(j).metric,metrics) || ~choice(q(j).operator,{'lt','le','gt','ge','eq'}) || ...
                    ~number(q(j).value,true), return; end
        end
    end
end
if numel(unique({r.name}))~=numel(r) || numel(unique([r.priority]))~=numel(r), return; end
ok=true; reason='';
end
function ok=object(x,fields)
ok=isstruct(x) && isscalar(x) && all(isfield(x,fields)) && numel(fieldnames(x))==numel(fields);
end
function ok=number(x,allow_inf)
ok=isa(x,'double') && isreal(x) && isscalar(x) && (isfinite(x) || (allow_inf && x==Inf));
end
function ok=nonnegative(x,allow_inf)
ok=number(x,allow_inf) && x>=0;
end
function ok=positive(x)
ok=number(x,false) && x>0;
end
function ok=integer(x,minimum)
ok=number(x,false) && x>=minimum && x==fix(x);
end
function ok=boolean(x)
ok=(islogical(x) || isa(x,'double')) && isreal(x) && isscalar(x) && ismember(x,[0 1]);
end
function ok=choice(x,values)
ok=ischar(x) && isrow(x) && any(strcmp(x,values));
end
