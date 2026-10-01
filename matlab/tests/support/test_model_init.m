function model = test_model_init(solver,P,alpha,beta,va,vb,truth)
% Explicit observation model and independent algorithm binding; no execution.
assert(isa(solver,'function_handle'),'libtr:testmodel:Solver','Expected function handle');
assert(isa(P,'double') && isreal(P) && size(P,1)==3);
assert(isequal(size(alpha),size(beta)) && size(alpha,1)==size(P,2));
assert(ismatrix(alpha) && ~isempty(alpha));
assert(numel(va)==size(P,2) && numel(vb)==size(P,2));
assert(isequal(size(truth),[3 1]) && all(isfinite(truth)));
N=size(alpha,2);
model.observations=struct('P',P,'alpha',alpha,'beta',beta,'va',va,'vb',vb);
model.algorithm=solver;
model.truth=truth;
model.cursor=0;
model.result.samples=NaN(3,N);
model.result.statuses=NaN(1,N);
model.result.errors=cell(1,N);
model.result.contract_violations=false(1,N);
end