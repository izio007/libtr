function unit_test_matmul3_relocation
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','function'));
clear matmul3;
expected=fullfile(root,'matlab','function','matmul3.m');
assert(strcmpi(which('matmul3'),expected));
assert(~isfile(fullfile(root,'matlab','matmul3.m')));
locations=which('matmul3','-all');
assert(numel(locations)==1);
[status,result]=matmul3([1 2;3 4],[5 6;7 8],[1;2]);
assert(status==0 && isequal(result,[63;143]));
fprintf('matmul3 production path and unique resolution: PASS\n');
end