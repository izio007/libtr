function model = test_stateful_init(step,state,time,P,alpha,beta,va,vb,truth)
% Explicit value state and observation-only frame interface.
test_state_validate(state);
model=test_trajectory_init(step,time,P,alpha,beta,va,vb,truth);
model.algorithm_state=state;
model.stateful=true;
end