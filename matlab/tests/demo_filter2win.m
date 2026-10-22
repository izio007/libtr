function demo_filter2win(output_dir,showFigures)
% Current working kernel, persistent FIFO scenarios and actual status log.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1, output_dir=fullfile(root,'runtime','filter2win_schema3'); end
if nargin<2, showFigures=false; end
validateattributes(showFigures,{'logical'},{'scalar'});
visibility='off'; if showFigures, visibility='on'; end
if ~isfolder(output_dir), mkdir(output_dir); end
oldpath=path; cleanup=onCleanup(@() path(oldpath));
addpath(fullfile(root,'matlab','function'),fullfile(root,'matlab','tests','support'));
result=filter2win_persistent_run(root,output_dir);
files={'matlab/function/filter2win.m','matlab/function/filter2win_persistent.m', ...
    'matlab/function/filter2win_execute.m', ...
    'matlab/function/filter2win_initial_state.m', ...
    'matlab/function/filter2win_persistent_conditions.m', ...
    'matlab/function/filter2win_persistent_execute.m', ...
    'matlab/function/filter2win_persistent_prepare.m', ...
    'matlab/function/filter2win_persistent_transition.m', ...
    'matlab/function/filter2win_prepare.m', ...
    'matlab/function/filter2win_transition.m', ...
    'matlab/function/filter2win_window_view.m', ...
    'matlab/function/filter2win_settings.m', ...
    'matlab/function/filter2win_validate.m','matlab/function/filter2win_validate_persistent.m', ...
    'matlab/function/filter2win_model.m', ...
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
    f=figure('Visible',visibility,'Color','w','Position',[80 80 1200 850], ...
        'Name',['filter2win ' tr.case_id],'NumberTitle','off');
    if ~showFigures, closefigure=onCleanup(@() close(f)); end
    ax=subplot(3,1,1,'Parent',f);
    plot(ax,tr.time,tr.truth,'k--'); hold(ax,'on');
    colors=[0.08 .45 .72;.89 .52 .12];
    for k=1:numel(tr.records)
        d=tr.records{k}; if d.missing, continue; end
        if d.accepted, plot(ax,d.time,d.measurement,'.','Color',colors(d.route,:),'MarkerSize',13);
        else, plot(ax,d.time,d.measurement,'rx'); end
        if ~isempty(d.removed.time), plot(ax,d.removed.time,d.removed.value,'mo','MarkerSize',9); end
    end
    finite=find(isfinite(tr.output));
    starts=[1 find(diff(finite)>1)+1]; ends=[starts(2:end)-1 numel(finite)];
    for segment=1:numel(starts)
        indices=finite(starts(segment):ends(segment));
        if isempty(indices), continue; end
        stairs(ax,tr.time(indices),tr.output(indices),'Color',[.05 .55 .28],'LineWidth',1.6);
        if numel(indices)==1, plot(ax,tr.time(indices),tr.output(indices),'go'); end
    end
    grid(ax,'on');
    title(ax,[tr.case_id ' | MATLAB filter2win schema 3 | ' tr.title],'Interpreter','none');
    ylabel(ax,'Coordinate'); xlabel(ax,'Time, s');
    ax=subplot(3,1,2,'Parent',f);
    a=cellfun(@(d)d.main_count,tr.records); b=cellfun(@(d)d.alt_count,tr.records);
    stairs(ax,tr.time,a,'Color',colors(1,:)); hold(ax,'on');
    stairs(ax,tr.time,b,'Color',colors(2,:)); grid(ax,'on');
    legend(ax,'FIFO A','FIFO B','Location','best'); ylabel(ax,'Retained samples'); xlabel(ax,'Time, s');
    ax=subplot(3,1,3,'Parent',f); stairs(ax,tr.time,tr.status,'LineWidth',1.2); grid(ax,'on');
    ylabel(ax,'FILTER_STATUS','Interpreter','none'); xlabel(ax,'Time, s'); yticks(ax,[0:8 10:15]);
    exportgraphics(f,fullfile(output_dir,[tr.case_id '.png']),'Resolution',130);
    if showFigures
        drawnow;
    else
        clear closefigure;
    end
end
report=rmfield(result,{'traces','spec'}); report.executed_checks=numel(result.checks);
file=fopen(fullfile(output_dir,'filter2win_system_checks.json'),'w','n','UTF-8'); assert(file~=-1);
closefile=onCleanup(@() fclose(file)); fprintf(file,'%s\n',jsonencode(report));
end
