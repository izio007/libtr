function cfg=filter2win_config(file)
% Compact profile by default; explicit full schema-2/3 files are also read.
% Changing schema/parameters requires a fresh ctx, not the old FILTER_STATE.
% known_velocity is used only with model='known_velocity', in units/s.
% Schema 3 requires trim_fraction=0; detected extremes use FIFO retain.
% mad_floor/max_mad/margins/range are in measurement units, not variance.
% Null upper bounds mean Inf. Schema-2-only fields are normalized below.
if nargin<1
    root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    file=fullfile(root,'matlab','tests','configs','filter2win_config.json');
end
cfg=jsondecode(fileread(file));
if isfield(cfg,'profile_version')
    cfg=filter2win_settings(cfg);
    return;
end
assert(isstruct(cfg) && isscalar(cfg) && isfield(cfg,'schema_version') && ...
    ~isfield(cfg,'rules'),'libtr:f2w:Settings', ...
    'Expected a fixed-transition configuration without rules');
% Schema 3 has no time pruning, partial-output bypass or hidden reset.
if cfg.schema_version==3
    for name={'main','alt'}
        for key={'max_mad','max_range','max_abs_velocity','max_adaptive_radius'}
            if isempty(cfg.(name{1}).band.(key{1})), cfg.(name{1}).band.(key{1})=Inf; end
        end
    end
    for key={'outlier_hold_seconds','gap_hold_seconds'}
        if isempty(cfg.flow.(key{1})), cfg.flow.(key{1})=Inf; end
    end
    [ok,why]=filter2win_validate_persistent(cfg);
    assert(ok,'libtr:f2w:Settings','Invalid resolved settings: %s',why);
    return;
end
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
[ok,why]=filter2win_validate(cfg);
assert(ok,'libtr:f2w:Settings','Invalid resolved settings: %s',why);
end
