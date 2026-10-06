function unit_test_filter2win_demo
% The default demo and all-mode log exercise schema 3.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
oldpath=path; cleanup=onCleanup(@() path(oldpath));
addpath(fullfile(root,'matlab','tests'),fullfile(root,'matlab','tests','support'),fullfile(root,'matlab','function'));
unit_test_filter2win_persistent;
copyfile(fullfile(pwd,'FILTER_STATUS_schema3.log'),fullfile(pwd,'FILTER_STATUS_all_modes.log'));
demo_filter2win(pwd);
end
