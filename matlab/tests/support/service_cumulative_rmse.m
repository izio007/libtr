function result = service_cumulative_rmse(samples,statuses,truth,eligible)
% Conditional prefix RMSE; failed trials are counted, never zero-error samples.
id='libtr:metrics:Input';
assert(isa(samples,'double') && isreal(samples) && ismatrix(samples) && ...
    size(samples,1)==3 && size(samples,2)>0,id,'Expected nonempty real double 3-by-N samples');
assert(isnumeric(statuses) && isreal(statuses) && isvector(statuses) && ...
    numel(statuses)==size(samples,2) && all(isfinite(statuses(:))) && ...
    all(statuses(:)==fix(statuses(:))),id,'Expected finite integer status per sample');
assert(isa(truth,'double') && isreal(truth) && isequal(size(truth),[3 1]) && ...
    all(isfinite(truth)),id,'Expected finite real double truth');
statuses=reshape(statuses,1,[]);
valid=statuses==0 & all(isfinite(samples),1);
if nargin>=4
    assert(islogical(eligible) && isvector(eligible) && numel(eligible)==numel(statuses), ...
        'libtr:metrics:Mask','Expected one logical eligibility flag per sample');
    valid=valid & reshape(eligible,1,[]);
end
squared=zeros(size(valid));
squared(valid)=sum((samples(:,valid)-truth).^2,1);
count=cumsum(valid); K=1:numel(valid);
rmse=NaN(size(count)); has=count>0;
rmse(has)=sqrt(cumsum(squared(has))./count(has));
curve=rmse; curve(~valid)=NaN;
result=struct('K',K,'successful',count,'rmse',rmse,'plot_rmse',curve, ...
    'failure_fraction',cumsum(~valid)./K,'valid',valid);
end