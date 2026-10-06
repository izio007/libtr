function [spec,cfg]=filter2win_observation_config
% Declarative synthetic scenario; does not change RNG or filter state.
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
spec=jsondecode(fileread(fullfile(root,'matlab','tests','configs', ...
    'filter2win_observations.json')));
if nargout>1
    cfg=filter2win_config(fullfile(root,'matlab','tests','configs',spec.filter_config));
end
end