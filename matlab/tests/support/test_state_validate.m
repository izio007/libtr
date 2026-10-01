function test_state_validate(value)
% Value-only state: no shared mutable handles or external resources.
if isnumeric(value) || islogical(value) || ischar(value), return; end
if iscell(value)
    for k=1:numel(value), test_state_validate(value{k}); end
    return;
end
if isstruct(value)
    names=fieldnames(value);
    for k=1:numel(value)
        for n=1:numel(names), test_state_validate(value(k).(names{n})); end
    end
    return;
end
error('libtr:testmodel:State','State must contain only value data');
end