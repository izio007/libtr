function unit_test_filter2win_relocation
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','function'));
clear filter2win;
assert(strcmpi(which('filter2win'),fullfile(root,'matlab','function','filter2win.m')));
assert(numel(which('filter2win','-all'))==1);
assert(~isfile(fullfile(root,'matlab','filter2win.m')));
c=struct('N',4,'S',3,'R_MAX',2,'R_ALT_MAX',1, ...
    'T_PROLONGATION_MAX',3,'T_TIMEOUT_CLEAR',10);
[s,a]=filter2win(c,struct('X_MAIN_REF',0),0,0,false);
assert(s==0 && a.X_FILTERED_OUTPUT==0);
[s,b]=filter2win(c,struct('X_MAIN_REF',100),0,100,false);
assert(s==0 && b.X_FILTERED_OUTPUT==100);
[s,a]=filter2win(c,a,1,2,false);
assert(s==0 && a.X_FILTERED_OUTPUT==1 && b.X_FILTERED_OUTPUT==100);
saved=a; [s,a]=filter2win(c,a,1,2,false);
assert(s==1 && isequaln(a,saved));
[s,a]=filter2win(c,a,4,NaN,true);
assert(s==0 && a.X_FILTERED_OUTPUT==1);
[s,a]=filter2win(c,a,5,NaN,true);
assert(s==0 && isnan(a.X_FILTERED_OUTPUT));
fprintf('filter2win isolated path, independent states and hold boundary: PASS\n');
end