% Start once in a dedicated MATLAB process; existing listeners are untouched.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root, 'tools', 'pipeline'));
service_pipeline_host(5555);