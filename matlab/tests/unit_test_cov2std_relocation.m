function unit_test_cov2std_relocation
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','function'));
clear tis_cov2std;
assert(strcmpi(which('tis_cov2std'),fullfile(root,'matlab','function','tis_cov2std.m')));
assert(numel(which('tis_cov2std','-all'))==1);
assert(~isfile(fullfile(root,'matlab','tis_cov2std.m')));
[status,r,a,b]=tis_cov2std(diag([4 9 16]),[10;0;0],zeros(3,1));
assert(status==0 && max(abs([r a b]-[2 3 4]))<1e-12);
fprintf('tis_cov2std isolated resolution and diagonal oracle: PASS\n');
end