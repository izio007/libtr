function result = service_run_ensemble(solver,P,alpha,beta,va,vb,truth)
% Execute a supplied operator on supplied independent observations, no test policy.
assert(isequal(size(alpha),size(beta)) && size(alpha,1)==size(P,2));
N=size(alpha,2);
result.samples=NaN(3,N); result.statuses=NaN(1,N);
result.errors=cell(1,N); result.contract_violations=false(1,N);
for j=1:N
    try
        [status,x]=solver(P,alpha(:,j),beta(:,j),va,vb);
        assert(isscalar(status) && ismember(status,[0 1 2]));
        assert(isa(x,'double') && isreal(x) && isequal(size(x),[3 1]));
        result.statuses(j)=status;
        result.samples(:,j)=x;
        if status==0
            result.contract_violations(j)=~all(isfinite(x));
        else
            result.contract_violations(j)=~all(isnan(x));
        end
    catch exception
        result.contract_violations(j)=true;
        result.errors{j}=getReport(exception,'extended','hyperlinks','off');
    end
end
result.metrics=service_ensemble_metrics(result.samples,result.statuses,truth);
end