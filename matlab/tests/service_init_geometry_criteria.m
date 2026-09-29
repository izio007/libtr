function DataContext = service_init_geometry_criteria(contextFileName)
% Dispatch by configuration schema, never by artifact name.
if nargin<1, contextFileName='context_unit_geometry.mat'; end
saved=load(contextFileName); names=fieldnames(saved);
assert(numel(names)==1,'libtr:context:Schema','Expected one configuration');
cfg=saved.(names{1});
if isfield(cfg.Trajectory,'Points')
    DataContext=service_init_geometry_trajectory(contextFileName);
elseif isfield(cfg.Trajectory,'RangeSteps')
    DataContext=service_init_geometry_unit(contextFileName);
else
    error('libtr:context:Schema','Unknown trajectory schema');
end
end