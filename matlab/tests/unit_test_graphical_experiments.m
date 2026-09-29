function unit_test_graphical_experiments
setup_test_paths;
% Raw repetition layout and independent scalar checks of ensemble metrics.
state=rng; cleanup=onCleanup(@() rng(state)); rng(17,'twister');
P=[-20000 20000 0 0;0 0 -20000 20000;200 200 200 200]; truth=[0;160000;10000];
[expanded,a,b,v]=service_sample_bearings(P,truth,0.01,3,20);
assert(isequal(expanded,repmat(P,1,3)) && isequal(size(a),[12 20]));
assert(isequal(size(b),size(a)) && all(v==0.0001));
assert(any(a(1,:)~=a(5,:)) && any(b(1,:)~=b(5,:)));
x=[1 3 5;2 4 6;0 0 0]; metrics=service_ensemble_metrics(x,[0 0 0],[0;0;0]);
assert(norm(metrics.bias-[3;4;0])<1e-12);
assert(abs(metrics.rmse-sqrt(91/3))<1e-12);
assert(norm(metrics.covariance-[4 4 0;4 4 0;0 0 0],'fro')<1e-12);
prefix=service_cumulative_rmse([NaN 3 NaN 0;NaN 4 NaN 0;NaN 0 NaN 0], ...
    [2 0 2 0],[0;0;0]);
assert(isequal(prefix.successful,[0 1 1 2]));
assert(isnan(prefix.rmse(1)) && prefix.rmse(2)==5 && prefix.rmse(3)==5);
assert(abs(prefix.rmse(4)-sqrt(12.5))<1e-12);
assert(isnan(prefix.plot_rmse(3)) && prefix.failure_fraction(4)==0.5);
empty=service_cumulative_rmse(NaN(3,2),[2 2],[0;0;0]);
assert(all(isnan(empty.rmse)) && all(empty.failure_fraction==1));
invalid=service_cumulative_rmse([NaN 3;0 4;0 0],[0 0],[0;0;0]);
assert(isequal(invalid.valid,[false true]) && invalid.rmse(2)==5);
assert(invalid.failure_fraction(2)==0.5);
fprintf('Graphical experiment contracts: PASS\n');
end