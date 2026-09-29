function result = service_cumulative_rmse(samples,statuses,truth)
% Conditional prefix RMSE; failed trials are counted, never zero-error samples.
assert(size(samples,1)==3 && numel(statuses)==size(samples,2));
assert(isequal(size(truth),[3 1]) && all(isfinite(truth)));
statuses=reshape(statuses,1,[]);
valid=statuses==0 & all(isfinite(samples),1);
squared=zeros(size(valid));
squared(valid)=sum((samples(:,valid)-truth).^2,1);
count=cumsum(valid); K=1:numel(valid);
rmse=NaN(size(count)); has=count>0;
rmse(has)=sqrt(cumsum(squared(has))./count(has));
curve=rmse; curve(~valid)=NaN;
result=struct('K',K,'successful',count,'rmse',rmse,'plot_rmse',curve, ...
    'failure_fraction',cumsum(~valid)./K,'valid',valid);
end