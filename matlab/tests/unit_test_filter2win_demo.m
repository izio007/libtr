function unit_test_filter2win_demo
% Registered demo executor: artifacts go to the pipeline job's current folder.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
oldpath=path; cleanup=onCleanup(@() path(oldpath));
addpath(fullfile(root,'matlab','tests'));
demo_filter2win(pwd);
end
