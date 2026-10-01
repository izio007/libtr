function result = service_run_path(solver,parameter,P,alpha,beta,va,vb,truth)
% Geometric path parameter is not physical time; stateless estimators only.
N=size(alpha,2);
assert(isa(parameter,'double') && isreal(parameter) && ...
    isequal(size(parameter),[1 N]) && all(isfinite(parameter)) && ...
    all(diff(parameter)>0));
assert(isa(truth,'double') && isreal(truth) && isequal(size(truth),[3 N]) ...
    && all(isfinite(truth(:))));
assert(ismatrix(P));
model=test_model_init(solver,P,alpha,beta,va,vb,truth(:,1));
model.mode='trajectory'; model.truth=truth;
model.parameter=parameter;
for k=1:N, model=test_model_step(model); end
result=test_model_result(model);
end