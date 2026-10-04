function [rc,q,data] = fifo_double(operation,q,varargin)
% FIFO_DOUBLE Fixed-capacity ring of finite double (timestamp,value) pairs.
% [rc,q]      = fifo_double('init',[],capacity)
% [rc,q]      = fifo_double('push',q,time,value)
% [rc,q]      = fifo_double('prune',q,oldest_allowed_time)
% [rc,q,data] = fifo_double('read'|'peek'|'pop',q)
% [rc,q]      = fifo_double('clear',q)
% rc=1 refuses atomically; rc=0 succeeds. read order is chronological.
% Empty allocated cells are NOT samples: only count active entries are read.
% The filter inserts real observations only; predictions do not fill capacity.
rc=1; data=struct('time',zeros(1,0),'value',zeros(1,0));
if ~(ischar(operation) && isrow(operation)), return; end
if strcmp(operation,'init')
    if numel(varargin)~=1, return; end
    capacity=varargin{1};
    if ~finite_scalar(capacity) || capacity<1 || capacity~=fix(capacity), return; end
    q=struct('capacity',capacity,'head',1,'count',0,'last_time',-Inf, ...
        'time',zeros(1,capacity),'value',zeros(1,capacity));
    rc=0; return;
end
if ~valid_queue(q), return; end
next=q;
switch operation
    case 'push'
        if numel(varargin)~=2, return; end
        t=varargin{1}; x=varargin{2};
        if ~finite_scalar(t) || ~finite_scalar(x) || t<=q.last_time, return; end
        if next.count<next.capacity
            slot=mod(next.head-1+next.count,next.capacity)+1;
            next.count=next.count+1;
        else
            slot=next.head;
            next.head=mod(next.head,next.capacity)+1;
        end
        next.time(slot)=t; next.value(slot)=x; next.last_time=t;
    case 'prune'
        if numel(varargin)~=1 || ~finite_scalar(varargin{1}), return; end
        cutoff=varargin{1};
        while next.count>0 && next.time(next.head)<cutoff
            next.time(next.head)=0; next.value(next.head)=0;
            next.head=mod(next.head,next.capacity)+1;
            next.count=next.count-1;
        end
    case 'clear'
        if ~isempty(varargin), return; end
        next.time(:)=0; next.value(:)=0;
        next.head=1; next.count=0; next.last_time=-Inf;
    case 'read'
        if ~isempty(varargin), return; end
        indices=mod(q.head-1+(0:q.count-1),q.capacity)+1;
        data.time=q.time(indices); data.value=q.value(indices);
    case {'peek','pop'}
        if ~isempty(varargin), return; end
        if q.count>0
            data.time=q.time(q.head); data.value=q.value(q.head);
            if strcmp(operation,'pop')
                next.time(next.head)=0; next.value(next.head)=0;
                next.head=mod(next.head,next.capacity)+1; next.count=next.count-1;
            end
        end
    otherwise
        return;
end
q=next; rc=0;
end

function ok=finite_scalar(x)
ok=isa(x,'double') && isreal(x) && isscalar(x) && isfinite(x);
end

function ok=valid_queue(q)
names={'capacity','head','count','last_time','time','value'};
ok=isstruct(q) && isscalar(q) && all(isfield(q,names));
if ~ok, return; end
ok=finite_scalar(q.capacity) && q.capacity>=1 && q.capacity==fix(q.capacity) && ...
    finite_scalar(q.head) && q.head>=1 && q.head<=q.capacity && q.head==fix(q.head) && ...
    finite_scalar(q.count) && q.count>=0 && q.count<=q.capacity && q.count==fix(q.count) && ...
    isa(q.last_time,'double') && isreal(q.last_time) && isscalar(q.last_time) && ...
    (isfinite(q.last_time) || q.last_time==-Inf) && ...
    isa(q.time,'double') && isreal(q.time) && isequal(size(q.time),[1 q.capacity]) && ...
    isa(q.value,'double') && isreal(q.value) && isequal(size(q.value),[1 q.capacity]) && ...
    all(isfinite(q.time)) && all(isfinite(q.value));
if ~ok || q.count==0, return; end
indices=mod(q.head-1+(0:q.count-1),q.capacity)+1;
times=q.time(indices);
ok=all(diff(times)>0) && times(end)<=q.last_time;
end
