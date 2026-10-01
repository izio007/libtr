function [values,next] = engine_rng_normal(context,rows,columns)
validateattributes(rows,{'double'},{'real','finite','scalar','integer','nonnegative'});
validateattributes(columns,{'double'},{'real','finite','scalar','integer','nonnegative'});
assert(isstruct(context) && isscalar(context) && ...
    isequal(sort(fieldnames(context)),sort({'version';'type';'normal';'state'})), ...
    'libtr:rng:Context','Invalid context schema');
assert(isequal(context.version,1) && strcmp(context.type,'mt19937ar') && ...
    strcmp(context.normal,'Ziggurat') && isa(context.state,'uint32') && ...
    isequal(size(context.state),[625 1]),'libtr:rng:Context','Invalid RNG state');
s=RandStream('mt19937ar','Seed',0,'NormalTransform','Ziggurat');
s.State=context.state;
values=randn(s,rows,columns);
next=context; next.state=s.State;
end