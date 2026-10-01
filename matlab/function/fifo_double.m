function [status, state, value, time] = fifo_double(action, state, value, time)
% FIFO_DOUBLE Fixed-capacity ring of finite double (value,time) pairs.
% See docs/fifo_double_theory.md. Failure leaves state unchanged.
status=1;
if ~ischar(action) || ~isrow(action), return; end
if strcmp(action,'init')
    capacity=value;
    if ~isa(capacity,'double') || ~isreal(capacity) || ~isscalar(capacity) ...
            || ~isfinite(capacity) || capacity<1 || capacity~=fix(capacity)
        return;
    end
    state=struct('values',zeros(1,capacity),'times',zeros(1,capacity), ...
        'count',0,'head',1);
    value=NaN; time=NaN; status=0; return;
end
if ~isstruct(state) || ~isscalar(state) ...
        || ~all(isfield(state,{'values','times','count','head'})), return; end
capacity=numel(state.values);
if ~isa(state.values,'double') || ~isreal(state.values) || ~isrow(state.values) ...
        || capacity<1 || ~isa(state.times,'double') || ~isreal(state.times) ...
        || ~isequal(size(state.times),size(state.values)), return; end
if ~isa(state.count,'double') || ~isscalar(state.count) || ~isreal(state.count) ...
        || ~isfinite(state.count) || state.count<0 || state.count>capacity ...
        || state.count~=fix(state.count) || ~isa(state.head,'double') ...
        || ~isscalar(state.head) || ~isreal(state.head) || ~isfinite(state.head) ...
        || state.head<1 || state.head>capacity || state.head~=fix(state.head), return; end
switch action
    case 'push'
        if ~isa(value,'double') || ~isreal(value) || ~isscalar(value) || ~isfinite(value) ...
                || ~isa(time,'double') || ~isreal(time) || ~isscalar(time) || ~isfinite(time)
            return;
        end
        index=mod(state.head+state.count-1,capacity)+1;
        state.values(index)=value; state.times(index)=time;
        if state.count==capacity
            state.head=mod(state.head,capacity)+1;
        else
            state.count=state.count+1;
        end
    case 'get'
        if ~isa(value,'double') || ~isreal(value) || ~isscalar(value) ...
                || ~isfinite(value) || value~=fix(value) || value<1 || value>state.count
            return;
        end
        index=mod(state.head+value-2,capacity)+1;
        value=state.values(index); time=state.times(index);
    case 'clear'
        state.count=0; state.head=1; value=NaN; time=NaN;
    otherwise
        return;
end
status=0;
end