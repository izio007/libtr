function demo_filter2win(output_dir)
% System acceptance and its presentation share the SAME saved realization.
% rc==0 or a generated plot alone cannot make this executor pass.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1, output_dir=fullfile(root,'runtime','demo'); end
if ~isfolder(output_dir), mkdir(output_dir); end
oldpath=path; oldrng=rng; cleanup=onCleanup(@() restore(oldpath,oldrng));
addpath(fullfile(root,'matlab','function'),fullfile(root,'matlab','tests','support'));
result=filter2win_system_run(root,output_dir);
provenance=source_records(root);
% Retain familiar top-level MAT fields for existing consumers of this demo.
run=result.traces{1}; cfg=result.cfg; spec=result.spec;
time=run.time; expected_level=run.data.plateau_model; measured=run.measured;
output=run.output; status=run.status; records=run.records;
save(fullfile(output_dir,'filter2win_demo.mat'),'result','provenance', ...
    'cfg','spec','time','expected_level','measured','output','status','records');
fid=fopen(fullfile(output_dir,'FILTER_STATUS_debug.log'),'w','n','UTF-8');
assert(fid~=-1); file_cleanup=onCleanup(@() fclose(fid));
for j=1:numel(result.traces)
    tr=result.traces{j}; fprintf(fid,'\n[CASE %s]\n',tr.case_id);
    for k=1:numel(tr.records), fprintf(fid,'%s\n',filter2win_debug_line(tr.records{k})); end
end
for j=1:numel(result.spec.seeds)
    tr=result.traces{j}; data=tr.data;
    f=figure('Visible','off','Color','w','Position',[100 100 1200 750]);
    figure_cleanup=onCleanup(@() close(f));
    subplot(2,1,1);
    plot(tr.time,data.reference,'k-'); hold on;
    plot(tr.time,data.plateau_model,'Color',[0.3 0.6 0.3],'LineStyle','--');
    plot(tr.time,tr.measured,'r.'); plot(tr.time,tr.output,'b-','LineWidth',1.5); grid on;
    xlabel('Time, s'); ylabel('Scalar coordinate');
    title(sprintf('Autonomous persistent-error capture / return / gap / reset; seed %d',tr.seed));
    legend('Physical reference','Measurement plateau model','Measurements','Filter output','Location','best');
    subplot(2,1,2); stairs(tr.time,tr.status,'LineWidth',1.2); grid on;
    xlabel('Time, s'); ylabel('FILTER_STATUS'); yticks(0:16);
    if j==1, file='filter2win_demo.png'; else, file=sprintf('filter2win_demo_%d.png',tr.seed); end
    exportgraphics(f,fullfile(output_dir,file),'Resolution',150);
    clear figure_cleanup;
end
fid_report=fopen(fullfile(output_dir,'filter2win_system_checks.json'),'w','n','UTF-8');
assert(fid_report~=-1); report_cleanup=onCleanup(@() fclose(fid_report));
report=struct('status',result.status,'executed_checks',result.executed_checks, ...
    'requirement_ids',{result.spec.requirement_ids},'checks',result.checks, ...
    'mat_file','filter2win_demo.mat','debug_file','FILTER_STATUS_debug.log');
fprintf(fid_report,'%s\n',jsonencode(report));
end

function sources=source_records(root)
files={'matlab/function/filter2win.m','matlab/function/fifo_double.m', ...
    'matlab/function/filter2win_band.m','matlab/function/filter2win_features.m', ...
    'matlab/function/filter2win_model.m','matlab/function/filter2win_rule_checks.m', ...
    'matlab/function/filter2win_status_name.m','matlab/function/filter2win_validate.m', ...
    'matlab/tests/support/filter2win_config.m','matlab/tests/support/filter2win_debug_line.m', ...
    'matlab/tests/support/filter2win_system_run.m','matlab/tests/demo_filter2win.m', ...
    'matlab/tests/unit_test_filter2win_demo.m','matlab/tests/unit_test_filter2win_candidate.m', ...
    'matlab/tests/configs/filter2win_config.json','matlab/tests/configs/filter2win_cases.json', ...
    'matlab/tests/configs/filter2win_system.json','docs/filter2win_theory.md'};
sources=struct('matlab_version',version,'files',struct('path',{},'bytes',{}));
for j=1:numel(files)
    fid=fopen(fullfile(root,files{j}),'rb'); assert(fid~=-1);
    file_cleanup=onCleanup(@() fclose(fid)); bytes=fread(fid,Inf,'*uint8'); clear file_cleanup;
    sources.files(j)=struct('path',files{j},'bytes',bytes);
end
end

function restore(oldpath,oldrng)
path(oldpath); rng(oldrng);
end
