function unit_test_filter2win_relocation
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','function'),fullfile(root,'matlab','tests'), ...
    fullfile(root,'matlab','tests','support'));
assert(strcmpi(which('filter2win'),fullfile(root,'matlab','function','filter2win.m')));
assert(numel(which('filter2win','-all'))==1);
assert(~isfile(fullfile(root,'matlab','filter2win.m')));
unit_test_filter2win;
end