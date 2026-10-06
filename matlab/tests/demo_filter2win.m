function demo_filter2win(output_dir)
% Current working kernel, persistent FIFO scenarios and actual status log.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1, output_dir=fullfile(root,'runtime','filter2win_schema3'); end
if ~isfolder(output_dir), mkdir(output_dir); end
oldpath=path; cleanup=onCleanup(@() path(oldpath));
addpath(fullfile(root,'matlab','function'),fullfile(root,'matlab','tests','support'));
result=filter2win_persistent_run(root,output_dir);
files={'matlab/function/filter2win.m','matlab/function/filter2win_persistent.m', ...
    'matlab/function/filter2win_settings.m', ...
    'matlab/function/filter2win_validate.m','matlab/function/filter2win_validate_persistent.m', ...
    'matlab/function/filter2win_model.m','matlab/function/filter2win_rule_checks.m', ...
    'matlab/function/filter2win_status_name.m','matlab/function/fifo_double.m', ...
    'matlab/tests/support/filter2win_config.m','matlab/tests/support/filter2win_debug_line.m', ...
    'matlab/tests/support/filter2win_debug_persistent.m','matlab/tests/support/filter2win_persistent_run.m', ...
    'matlab/tests/configs/filter2win_config.json','matlab/tests/configs/filter2win_optimizer_experiments.json', ...
    'matlab/tests/demo_filter2win.m','docs/filter2win_theory.md'};
provenance=struct('matlab_version',version,'files',struct('path',{},'bytes',{}));
for k=1:numel(files)
    fid=fopen(fullfile(root,files{k}),'rb'); assert(fid~=-1);
    closefile=onCleanup(@() fclose(fid)); bytes=fread(fid,Inf,'*uint8'); clear closefile;
    provenance.files(k)=struct('path',files{k},'bytes',bytes);
end
save(fullfile(output_dir,'filter2win_demo.mat'),'result','provenance');
fid=fopen(fullfile(output_dir,'FILTER_STATUS_debug.log'),'w','n','UTF-8'); assert(fid~=-1);
closelog=onCleanup(@() fclose(fid));
for j=1:numel(result.traces)
    tr=result.traces{j};
    fprintf(fid,'[CASE %s]\n',tr.case_id);
    for k=1:numel(tr.records), fprintf(fid,'%s\n',filter2win_debug_line(tr.records{k})); end
    f=figure('Visible','off','Color','w','Position',[80 80 1200 850]);
    closefigure=onCleanup(@() close(f));
    subplot(3,1,1); plot(tr.time,tr.truth,'k--'); hold on;
    colors=[0.08 .45 .72;.89 .52 .12];
    for k=1:numel(tr.records)
        d=tr.records{k}; if d.missing, continue; end
        if d.accepted, plot(d.time,d.measurement,'.','Color',colors(d.route,:),'MarkerSize',13);
        else, plot(d.time,d.measurement,'rx'); end
        if ~isempty(d.removed.time), plot(d.removed.time,d.removed.value,'mo','MarkerSize',9); end
    end
    finite=find(isfinite(tr.output));
    starts=[1 find(diff(finite)>1)+1]; ends=[starts(2:end)-1 numel(finite)];
    for segment=1:numel(starts)
        indices=finite(starts(segment):ends(segment));
        if isempty(indices), continue; end
        stairs(tr.time(indices),tr.output(indices),'Color',[.05 .55 .28],'LineWidth',1.6);
        if numel(indices)==1, plot(tr.time(indices),tr.output(indices),'go'); end
    end
    grid on;
    title([tr.case_id ' | MATLAB filter2win schema 3 | ' tr.title],'Interpreter','none');
    ylabel('Coordinate'); xlabel('Time, s');
    subplot(3,1,2);
    a=cellfun(@(d)d.main_count,tr.records); b=cellfun(@(d)d.alt_count,tr.records);
    stairs(tr.time,a,'Color',colors(1,:)); hold on; stairs(tr.time,b,'Color',colors(2,:)); grid on;
    legend('FIFO A','FIFO B','Location','best'); ylabel('Retained samples'); xlabel('Time, s');
    subplot(3,1,3); stairs(tr.time,tr.status,'LineWidth',1.2); grid on;
    ylabel('FILTER_STATUS','Interpreter','none'); xlabel('Time, s'); yticks([0:8 10:15]);
    exportgraphics(f,fullfile(output_dir,[tr.case_id '.png']),'Resolution',130);
    if strcmp(tr.case_id,'P02'), copyfile(fullfile(output_dir,'P02.png'),fullfile(output_dir,'filter2win_demo.png')); end
    clear closefigure;
end
report=rmfield(result,{'traces','spec'}); report.executed_checks=numel(result.checks);
file=fopen(fullfile(output_dir,'filter2win_system_checks.json'),'w','n','UTF-8'); assert(file~=-1);
closefile=onCleanup(@() fclose(file)); fprintf(file,'%s\n',jsonencode(report));
end
