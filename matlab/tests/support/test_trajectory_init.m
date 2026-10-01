function model = test_trajectory_init(solver,time,P,alpha,beta,va,vb,truth)
% Replay supplied observations; time is supplied in seconds, never inferred.
N=size(alpha,2);
assert(isa(time,'double') && isreal(time) && isequal(size(time),[1 N]) ...
    && all(isfinite(time)) && all(diff(time)>0), ...
    'libtr:testmodel:Time','Expected finite strictly increasing seconds');
assert(isa(truth,'double') && isreal(truth) && isequal(size(truth),[3 N]) ...
    && all(isfinite(truth(:))),'libtr:testmodel:Truth','Expected finite trajectory');
assert(ndims(P)<=3 && (size(P,3)==1 || size(P,3)==N), ...
    'libtr:testmodel:Navigation','Expected constant or per-frame station positions');
model=test_model_init(solver,P(:,:,1),alpha,beta,va,vb,truth(:,1));
model.observations.P=P;
model.truth=truth;
model.time=time;
model.current_time=NaN;
model.mode='trajectory';
end