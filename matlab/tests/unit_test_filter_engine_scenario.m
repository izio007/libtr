function unit_test_filter_engine_scenario
setup_test_paths;
clear filter2win_scenario filter2win_observations generate_filter2win_doc_images;
old=rng; cleanup=onCleanup(@() rng(old));
spec=filter2win_observation_config;
rng(spec.seed,spec.rng_algorithm);
t=spec.start_time:spec.time_step:spec.end_time;
truth=spec.truth_level*ones(size(t)); z=truth;
% Independent scalar reconstruction, not a call to the observation generator.
for j=1:numel(t)
    for k=1:size(spec.plateaus,1)
        if t(j)>=spec.plateaus(k,1) && t(j)<=spec.plateaus(k,2)
            z(j)=spec.plateaus(k,3);
        end
    end
    for k=1:size(spec.spikes,1)
        if t(j)==spec.spikes(k,1), z(j)=spec.spikes(k,2); end
    end
end
% Preserve original rounding: add the precomputed noise.
noise=spec.noise_width*rand(size(z))+spec.noise_offset;
z=z+noise;
z(t>spec.missing_open_interval(1) & t<spec.missing_open_interval(2))=NaN;
expectedRng=rng;
cfg=filter2win_config;
ctx=struct('X_MAIN_REF',spec.initial_reference); y=zeros(numel(t),1); p=y;
for k=1:numel(t)
    [s,ctx]=filter2win(cfg,ctx,t(k),z(k),isnan(z(k)));
    assert(s==0); y(k)=ctx.X_FILTERED_OUTPUT; p(k)=ctx.W_ALT_POWER_OUTPUT;
end
rng(spec.seed,spec.rng_algorithm);
[actualT,actualTruth,actualZ,actualY,actualP]=filter2win_scenario;
assert(isequaln({t,truth,z,y,p},{actualT,actualTruth,actualZ,actualY,actualP}));
assert(isequal(rng,expectedRng));
unit_test_filter_model;
unit_test_filter_plot_path;
fprintf('Scenario via engine: original inputs/RNG/outputs and plot replay PASS\n');
end