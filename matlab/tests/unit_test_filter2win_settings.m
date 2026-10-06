function unit_test_filter2win_settings
% Pre-change full profiles are independent references for conversion.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
folder=fullfile(root,'matlab','tests','configs');
p=jsondecode(fileread(fullfile(folder,'filter2win_config.json')));
cfg=filter2win_settings(p);
reference=filter2win_config(fullfile(folder,'filter2win_expanded_reference.json'));
assert(isequaln(cfg,reference),'libtr:f2w:SettingsTest','Default profile changed behavior');
cfg=filter2win_config(fullfile(folder,'filter2win_observation_filter.json'));
reference=filter2win_config(fullfile(folder,'filter2win_observation_reference.json'));
assert(isequaln(cfg,reference),'libtr:f2w:SettingsTest','Observation profile changed behavior');
v=jsondecode(fileread(fullfile(folder,'filter2win_schema3_cases.json')));
q=p; q.alt=struct('min_samples',v.min_samples,'radius',v.normalized_alt_radius);
c=filter2win_settings(q);
assert(c.main.min_samples==p.window.min_samples && c.alt.min_samples==v.min_samples);
assert(c.alt.band.lower_margin==v.normalized_alt_radius && c.alt.band.upper_margin==v.normalized_alt_radius);
q.hold.outliers_seconds=0; q.hold.missing_seconds=[];
q.handover.duration_seconds=v.blend_duration;
q.advanced=struct('main',struct('band',struct('lower_margin',v.normalized_main_radius)), ...
    'rules',struct('switch',struct('confirm_seconds',v.wait_seconds)));
c=filter2win_settings(q);
assert(c.flow.outlier_hold_seconds==0 && isinf(c.flow.gap_hold_seconds));
assert(c.handover.duration_seconds==v.blend_duration);
assert(c.main.band.lower_margin==v.normalized_main_radius && c.main.band.upper_margin==p.window.radius);
assert(c.rules(strcmp({c.rules.name},'switch')).confirm_seconds==v.wait_seconds);
bad=p; bad.window.capcity=p.window.capacity; refused(bad);
bad=p; bad.window.radius=-abs(p.window.radius); refused(bad);
bad=p; bad.window.min_samples=p.window.capacity+1; refused(bad);
bad=p; bad.hold=rmfield(bad.hold,'missing_seconds'); refused(bad);
bad=p; bad.advanced=struct('main',struct('band',struct('max_mad',v.max_mad))); refused(bad);
bad=p; bad.advanced=struct('rules',struct('swich',struct('enabled',false))); refused(bad);
end
function refused(p)
failed=false;
try
    filter2win_settings(p);
catch e
    failed=strcmp(e.identifier,'libtr:f2w:Settings');
end
assert(failed,'libtr:f2w:SettingsTest','Invalid profile was not clearly refused');
end
