function metrics = service_ensemble_metrics(samples, statuses, truth)
% Conditional ensemble statistics; see docs/guides/ENSEMBLE_VALIDATION.md.
assert(isa(samples,'double') && isreal(samples) && size(samples,1)==3);
assert(isequal(size(truth),[3 1]) && all(isfinite(truth)));
assert(numel(statuses)==size(samples,2) && ~isempty(statuses));
valid=statuses(:).'==0 & all(isfinite(samples),1);
metrics.total=size(samples,2);
metrics.successful=sum(valid);
metrics.failure_fraction=1-metrics.successful/metrics.total;
metrics.mean=NaN(3,1); metrics.bias=NaN(3,1); metrics.rmse=NaN;
metrics.covariance=NaN(3); metrics.axes=NaN(3); metrics.eigenvalues=NaN(3,1);
metrics.semiaxes=NaN(3,1); metrics.psi=NaN(1,3); metrics.theta=NaN(1,3);
metrics.conditional_on_success=true;
if metrics.successful==0, return; end
cloud=samples(:,valid);
metrics.mean=mean(cloud,2);
metrics.bias=metrics.mean-truth;
metrics.rmse=sqrt(mean(sum((cloud-truth).^2,1)));
if metrics.successful<2, return; end
centered=cloud-metrics.mean;
metrics.covariance=(centered*centered.')/(metrics.successful-1);
[V,S]=eig(metrics.covariance);
metrics.axes=V; metrics.eigenvalues=diag(S);
% Do not clip negative eigenvalues into apparently physical axes.
if all(diag(S)>=0), metrics.semiaxes=sqrt(diag(S)); end
metrics.psi=atan2(V(2,:),V(1,:));
metrics.theta=atan2(V(3,:),hypot(V(1,:),V(2,:)));
end