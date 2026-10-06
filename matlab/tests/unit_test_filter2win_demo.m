function unit_test_filter2win_demo
% Scenario execution and rendering; the kernel suite owns analytical checks.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
oldpath=path; cleanup=onCleanup(@() path(oldpath));
addpath(fullfile(root,'matlab','tests'),fullfile(root,'matlab','tests','support'),fullfile(root,'matlab','function'));
demo_filter2win(pwd);
end
