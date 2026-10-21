function [ok,reason]=filter2win_validate_persistent(c)
% Schema 3: persistent physical FIFOs, transactional robust admission.
ok=false; reason='INVALID_CONFIGURATION';
if ~object(c,{'schema_version','main','alt','flow','handover'}) || ...
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
function ok=choice(x,values)
ok=ischar(x) && isrow(x) && any(strcmp(x,values));
end
