function unit_test_filter_engine_scenario
setup_test_paths;
clear filter2win_scenario filter2win_observations generate_filter2win_doc_images;
old=rng; cleanup=onCleanup(@() rng(old));
rng(1729,'twister');
t=0:3:300; truth=10*ones(size(t)); z=truth;
z(t==30)=40; z(t>=60 & t<=100)=25;
z(t>=171 & t<=216)=25; z(t==252 | t==255)=28;
% Preserve original rounding: add the precomputed noise.
noise=4*rand(size(z))-2;
z=z+noise; z(t>100 & t<170)=NaN;
expectedRng=rng;
cfg=struct('N',20,'S',6,'R_MAX',5,'R_ALT_MAX',6, ...
    'T_PROLONGATION_MAX',15,'T_TIMEOUT_CLEAR',70,'V',0);
ctx=struct('X_MAIN_REF',10); y=zeros(numel(t),1); p=y;
for k=1:numel(t)
    [s,ctx]=filter2win(cfg,ctx,t(k),z(k),isnan(z(k)));
    assert(s==0); y(k)=ctx.X_FILTERED_OUTPUT; p(k)=ctx.W_ALT_POWER_OUTPUT;
end
rng(1729,'twister');
[actualT,actualTruth,actualZ,actualY,actualP]=filter2win_scenario;
assert(isequaln({t,truth,z,y,p},{actualT,actualTruth,actualZ,actualY,actualP}));
assert(isequal(rng,expectedRng));
unit_test_filter_model;
unit_test_filter_plot_path;
fprintf('Scenario via engine: original inputs/RNG/outputs and plot replay PASS\n');
end