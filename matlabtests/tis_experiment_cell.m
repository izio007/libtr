function record = tis_experiment_cell(stations,truth,sigma,repeats,runs,file)
setup_test_paths;
% Scenario adapter: common observations, independent estimators, saved evidence.
[P,alpha,beta,variance]=service_sample_bearings(stations,truth,sigma,repeats,runs);
methods={'lls_position','wlls_position','gn_position','gnp_position'};
results=cell(1,4);
d=truth-P;
a=atan2(d(2,:),d(1,:)).'; b=atan2(d(3,:),hypot(d(1,:),d(2,:))).';
[crlbStatus,K]=mock_covariance(P,a,b,variance,variance,truth);
record=struct('truth',truth,'crlb_status',crlbStatus,'crlb_std',sqrt(diag(K)), ...
    'std',NaN(3,4),'axis_rmse',NaN(3,4),'rmse',NaN(1,4), ...
    'bias',NaN(3,4),'max_miss',NaN(1,4),'failure_fraction',NaN(1,4), ...
    'violations',zeros(1,4),'successful',zeros(1,4));
for m=1:4
    results{m}=service_run_ensemble(str2func(methods{m}),P,alpha,beta,variance,variance,truth);
    r=results{m}; valid=r.statuses==0 & all(isfinite(r.samples),1);
    record.rmse(m)=r.metrics.rmse; record.bias(:,m)=r.metrics.bias;
    record.std(:,m)=sqrt(diag(r.metrics.covariance));
    record.failure_fraction(m)=r.metrics.failure_fraction;
    record.violations(m)=sum(r.contract_violations);
    record.successful(m)=sum(valid);
    if any(valid)
        err=r.samples(:,valid)-truth;
        record.axis_rmse(:,m)=sqrt(mean(err.^2,2));
        record.max_miss(m)=max(sqrt(sum(err.^2,1)));
    end
end
save(file,'stations','truth','sigma','repeats','runs','P','alpha','beta', ...
    'variance','results','record','K','methods');
end