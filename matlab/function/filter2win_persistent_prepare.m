function [ok,s,missing,debug]=filter2win_persistent_prepare(c,ctx,t,x,missing)
% Schema 3 input/state contract. Failed preparation never changes ctx.
ok=false; s=[];
debug=struct('api_status',1,'reason','INVALID_INPUT','time',t);
[valid,why]=filter2win_validate_persistent(c);
if ~valid, debug.reason=why; return; end
if ~isstruct(ctx) || ~isscalar(ctx) || ~finite(t) || ...
        ~isa(x,'double') || ~isreal(x) || ~isscalar(x) || ...
        ~(islogical(missing) || isa(missing,'double')) || ...
        ~isreal(missing) || ~isscalar(missing) || ~ismember(missing,[0 1]), return; end
missing=logical(missing) || isnan(x);
if ~missing && ~isfinite(x), return; end
if isfield(ctx,'X_MAIN_REF') && (~isa(ctx.X_MAIN_REF,'double') || ~isreal(ctx.X_MAIN_REF) || ...
        ~(isscalar(ctx.X_MAIN_REF) || isequal(size(ctx.X_MAIN_REF),[3 1])) || ...
        ~all(isfinite(ctx.X_MAIN_REF))), return; end
if isfield(ctx,'FILTER_STATE')
    s=ctx.FILTER_STATE;
    if ~valid_state(s,c), debug.reason='INVALID_STATE_OR_RECONFIGURATION'; return; end
    if t<=s.last_tick, debug.reason='NONINCREASING_TIME'; return; end
    if ~isfinite(t-s.last_tick), debug.reason='TIME_ARITHMETIC_OVERFLOW'; return; end
else
    s=initial(c,t);
end
ok=true;
end

function s=initial(c,t)
[~,a]=fifo_double('init',[],c.main.capacity); [~,b]=fifo_double('init',[],c.alt.capacity);
s=struct('schema_version',3,'parameters',c,'main',a,'alt',b,'active',0, ...
    'primary',filter2win_model(struct('time',[],'value',[]),'constant'),'status',0,'status_since',t,'tact',0,'last_tick',-Inf, ...
    'last_input',-Inf,'last_accept',[-Inf -Inf],'last_supported',false,'last_output',NaN, ...
    'pending_window',0,'pending_since',NaN,'blend_from',NaN,'blend_start',NaN, ...
    'blend_duration',0,'blend_elapsed',0);
end

function ok=valid_state(s,c)
fields={'schema_version','parameters','main','alt','active','status','status_since','tact', ...
    'last_tick','last_input','last_accept','last_supported','last_output','pending_window', ...
    'pending_since','blend_from','blend_start','blend_duration','blend_elapsed'};
ok=isstruct(s) && isscalar(s) && all(isfield(s,fields));
if ~ok, return; end
ok=isequal(s.schema_version,3) && isequaln(s.parameters,c) && integer(s.active,0,2) && ...
    integer(s.pending_window,0,2) && integer(s.status,0,15) && s.status~=9 && ...
    integer(s.tact,0,flintmax) && finite(s.last_tick) && finite(s.status_since) && ...
    s.status_since<=s.last_tick && finite(s.blend_duration) && s.blend_duration>=0 && ...
    finite(s.blend_elapsed) && s.blend_elapsed>=0 && ...
    islogical(s.last_supported) && isscalar(s.last_supported);
if ~ok, return; end
for f={'last_input','last_output','pending_since','blend_from','blend_start'}
    a=s.(f{1});
    if ~isa(a,'double') || ~isreal(a) || ~isscalar(a), ok=false; return; end
end
if ~(isfinite(s.last_input) || s.last_input==-Inf) || s.last_input>s.last_tick || ...
        ~(isfinite(s.last_output) || isnan(s.last_output)), ok=false; return; end
if ~isa(s.last_accept,'double') || ~isreal(s.last_accept) || ...
        ~isequal(size(s.last_accept),[1 2]) || any(isnan(s.last_accept) | s.last_accept>s.last_tick), ok=false; return; end
if s.pending_window>0 && (~isfinite(s.pending_since) || s.pending_since>s.last_tick), ok=false; return; end
if s.status==14 && (s.active==0 || ~finite(s.blend_from) || ...
        ~finite(s.blend_start) || s.blend_start>s.last_tick || s.blend_duration<=0), ok=false; return; end
[a,~,~]=fifo_double('read',s.main); [b,~,~]=fifo_double('read',s.alt);
ok=a==0 && b==0;
if ~ok, return; end
ok=s.main.capacity==c.main.capacity && s.alt.capacity==c.alt.capacity && ...
    s.main.last_time<=s.last_tick && s.alt.last_time<=s.last_tick;
end

function ok=finite(x)
ok=isa(x,'double') && isreal(x) && isscalar(x) && isfinite(x);
end

function ok=integer(x,lo,hi)
ok=finite(x) && x>=lo && x<=hi && x==fix(x);
end
