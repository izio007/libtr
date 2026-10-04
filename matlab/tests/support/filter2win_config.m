function cfg=filter2win_config(file)
% Schema 2: robust median/MAD policy; no plateau coordinates/times here.
% Changing schema/parameters requires a fresh ctx, not the old FILTER_STATE.
% known_velocity is used only with model='known_velocity', in units/s.
% trim_fraction is trimmed independently at each tail (0 <= fraction < .5).
% mad_floor/max_mad/margins/range are in measurement units, not variance.
% compatibility.method: median_band | nearest_neighbor | trimmed_range.
% on_incompatible='ignore' preserves evidence until BOTH configured streak
% thresholds are met, then restarts from the current real observation.
% null streak thresholds disable that restart. Null upper bounds mean Inf.
if nargin<1
    root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    file=fullfile(root,'matlab','tests','configs','filter2win_config.json');
end
cfg=jsondecode(fileread(file));
% JSON has no infinity. A null upper bound means that limit is disabled.
windows={'main','alt'};
for k=1:numel(windows)
    name=windows{k};
    limits={'history_seconds','max_gap_seconds','freshness_seconds'};
    for j=1:numel(limits)
        field=limits{j};
        if isempty(cfg.(name).(field)), cfg.(name).(field)=Inf; end
    end
    band_limits={'max_mad','max_abs_velocity','max_trimmed_range','max_adaptive_radius'};
    for j=1:numel(band_limits)
        field=band_limits{j};
        if isempty(cfg.(name).band.(field)), cfg.(name).band.(field)=Inf; end
    end
end
if isempty(cfg.alt.relative_mad_ratio), cfg.alt.relative_mad_ratio=Inf; end
if isempty(cfg.alt.incompatible_min_samples), cfg.alt.incompatible_min_samples=Inf; end
if isempty(cfg.alt.incompatible_min_seconds), cfg.alt.incompatible_min_seconds=Inf; end
flow_limits={'outlier_hold_seconds','gap_hold_seconds','timeout_seconds'};
for j=1:numel(flow_limits)
    field=flow_limits{j};
    if isempty(cfg.flow.(field)), cfg.flow.(field)=Inf; end
end
for k=1:numel(cfg.rules)
    for j=1:numel(cfg.rules(k).conditions)
        if isempty(cfg.rules(k).conditions(j).value)
            cfg.rules(k).conditions(j).value=Inf;
        end
    end
end
end
