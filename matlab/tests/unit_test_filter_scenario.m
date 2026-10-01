function unit_test_filter_scenario
setup_test_paths;
state=rng; cleanup=onCleanup(@() rng(state));
rng(1729,'twister');
[t,x,m,y,p]=filter2win_scenario;
assert(isequal(t,0:3:300) && isequal(x,10*ones(1,101)));
assert(isequal(isnan(m),t>100 & t<170));
assert(isequal(size(y),[101 1]) && isequal(size(p),[101 1]));
rng(1729,'twister');
[t2,x2,m2,y2,p2]=filter2win_scenario;
assert(isequaln({t,x,m,y,p},{t2,x2,m2,y2,p2}));
fprintf('Explicit filter scenario repeatability and inputs: PASS\n');
end