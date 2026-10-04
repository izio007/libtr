function [cfg,ctx,t,truth,measured,missing] = filter2win_observations
% Synthetic input only; preserves the original single rand draw and ordering.
cfg=filter2win_config;
spec=filter2win_observation_config;
ctx=struct('X_MAIN_REF',spec.initial_reference);
t=spec.start_time:spec.time_step:spec.end_time;
truth=spec.truth_level*ones(1,numel(t));
measured=truth;
for k=1:size(spec.plateaus,1)
    event=spec.plateaus(k,:);
    measured(t>=event(1) & t<=event(2))=event(3);
end
for k=1:size(spec.spikes,1)
    measured(t==spec.spikes(k,1))=spec.spikes(k,2);
end
noise=spec.noise_width*rand(size(measured))+spec.noise_offset;
measured=measured+noise;
missing=t>spec.missing_open_interval(1) & t<spec.missing_open_interval(2);
measured(missing)=NaN;
end