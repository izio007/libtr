function result = service_run_ensemble(solver,P,alpha,beta,va,vb,truth)
% Compatibility adapter to the explicit init/step/result test model.
model=test_model_init(solver,P,alpha,beta,va,vb,truth);
for j=1:size(alpha,2)
    model=test_model_step(model);
end
result=test_model_result(model);
end