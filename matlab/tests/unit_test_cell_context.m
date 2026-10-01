function unit_test_cell_context
setup_test_paths;
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
folder=tempname(fullfile(root,'runtime')); mkdir(folder);
P=[-5000 5000 0 0;0 0 -5000 5000;0 0 0 0]; truth=[1000;30000;3000];
a=engine_rng_init(812); b=engine_rng_init(27); globalBefore=rng;
[r,a1]=tis_experiment_cell(P,truth,0.001,1,8,fullfile(folder,'a.mat'),a);
tis_experiment_cell(P,truth,0.001,1,8,fullfile(folder,'b.mat'),b);
[rr,aa1]=tis_experiment_cell(P,truth,0.001,1,8,fullfile(folder,'copy.mat'),a);
assert(isequaln(r,rr) && isequal(a1,aa1) && isequal(rng,globalBefore));
d=load(fullfile(folder,'a.mat')); copy=load(fullfile(folder,'copy.mat'));
assert(isequal(d.initial,a) && isequal(d.next,a1));
assert(isequal(d.alpha,copy.alpha) && isequal(d.beta,copy.beta));
assert(isequaln(d.results,copy.results));
[~,a2]=tis_experiment_cell(P,truth,0.001,1,8,fullfile(folder,'next.mat'),d.next);
[~,aa2]=tis_experiment_cell(P,truth,0.001,1,8,fullfile(folder,'next_copy.mat'),aa1);
assert(isequal(a2,aa2) && isequal(rng,globalBefore));
unit_test_production_isolation;
fprintf('Explicit scenario context and persisted continuation PASS: %s\n',folder);
end