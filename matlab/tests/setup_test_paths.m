function setup_test_paths
% Explicit development composition root; never called by production services.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'matlab','function'),fullfile(root,'matlab','engine'), ...
    fullfile(root,'matlab','tests','support'),fullfile(root,'tools','pipeline'), ...
    fullfile(root,'tools','docs'),fullfile(root,'tools','matlab'));
end