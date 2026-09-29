function setup_test_paths
% Explicit development composition root; never called by production services.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'matlabengine'), ...
    fullfile(root,'matlabtests','support'),fullfile(root,'tools','pipeline'), ...
    fullfile(root,'tools','docs'));
end