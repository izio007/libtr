function unit_test_filter2win_demo
% Registered system acceptance: complete mode fixtures plus system invariants.
% Artifacts go to the pipeline job's current folder; one canonical runner job.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
oldpath=path; cleanup=onCleanup(@() path(oldpath));
addpath(fullfile(root,'matlab','tests'),fullfile(root,'matlab','tests','support'), ...
    fullfile(root,'matlab','function'));
unit_test_filter2win_candidate;
candidate=load(fullfile(pwd,'filter2win_candidate_contract.mat'),'records','codes');
fid=fopen(fullfile(pwd,'FILTER_STATUS_all_modes.log'),'w','n','UTF-8');
assert(fid~=-1); log_cleanup=onCleanup(@() fclose(fid));
for k=1:numel(candidate.records)
    fprintf(fid,'%s\n',filter2win_debug_line(candidate.records{k}));
end
clear log_cleanup;
demo_filter2win(pwd);
end
