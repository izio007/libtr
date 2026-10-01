function report = service_pipeline_run(request, folder)
% Execute registered stages and persist failures without hiding later results.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
selected=service_pipeline_select_test(request,root);
previous=pwd; oldpath=path; state=rng;
cleanup=onCleanup(@() restore(previous,oldpath,state));
addpath(fullfile(root,'matlab','tests'));
setup_test_paths;
cd(folder); rng(1729,'twister');
report=struct('v',1,'id',request.id,'action',request.action,'state','running', ...
    'matlab',version,'started',char(datetime('now','TimeZone','UTC')), ...
    'stages',{{}},'visual_review','pending');
file=fullfile(folder,'report.json');
report.context_protocol=2;
report.host_pid=feature('getpid');
if isfield(request,'test_sha256')
    report.test_sha256=service_pipeline_test_version(request,root);
end
service_pipeline_write_json(file,report);
if strcmp(request.action,'all')
    stages={'environment','unit','integration','png','documents','liveeditor'};
elseif strcmp(request.action,'mapping')
    stages={'mapping_unit','environment','mapping_integration','mapping_png'};
    report.visual_review='not_requested';
elseif strcmp(request.action,'mapping5000')
    stages={'mapping_unit','ensemble5000','spectral_png'};
    report.visual_review='pending';
elseif strcmp(request.action,'liveeditor')
    stages={'documents','liveeditor'};
elseif strcmp(request.action,'unit')
    if isempty(selected), stages={'environment','unit'};
    else, stages={'unit'}; end
else
    stages={request.action};
end
failed=false;
documentsPassed=false;
for k=1:numel(stages)
    drawnow;
    if isfile(fullfile(folder,'cancel'))
        report.state='cancelled'; break;
    end
    item=struct('name',stages{k},'state','running','seconds',0,'metrics',struct(),'error','');
    report.stages{end+1}=item;
    service_pipeline_write_json(file,report);
    clock=tic;
    log='';
    try
        if (strcmp(request.action,'mapping') || ...
                (strcmp(request.action,'mapping5000') && ~strcmp(stages{k},'spectral_png'))) && failed
            item.state='blocked';
            item.error='A prerequisite of statistical mapping failed.';
        elseif strcmp(stages{k},'liveeditor') && ~documentsPassed
            item.state='blocked'; failed=true;
            item.error='Live Editor export not attempted: documents stage did not pass.';
        else
            log=evalc('item.metrics=runStage(stages{k},root,folder,selected);');
            item.state='passed';
            if strcmp(stages{k},'ensemble5000') && item.metrics.failures>0
                item.state='failed'; failed=true;
                item.error='Mathematical acceptance failed; saved ensembles remain available for diagnostic plots.';
            end
            if strcmp(stages{k},'documents')
                documentsPassed=item.metrics.failures==0;
                if ~documentsPassed
                    item.state='failed'; failed=true;
                    item.error=sprintf('%d documents failed; see documents_results.json', ...
                        item.metrics.failures);
                end
            end
        end
    catch exception
        item.state='failed'; failed=true;
        item.error=getReport(exception,'extended','hyperlinks','off');
    end
    item.seconds=toc(clock);
    fid=fopen(fullfile(folder,[stages{k} '.log']),'w','n','UTF-8');
    assert(fid~=-1,'libtr:pipeline:IO','Cannot write log');
    fprintf(fid,'%s\n%s',log,item.error); fclose(fid);
    report.stages{end}=item;
    service_pipeline_write_json(file,report);
end
if strcmp(report.state,'running')
    if failed, report.state='failed'; else, report.state='passed'; end
end
report.finished=char(datetime('now','TimeZone','UTC'));
files=dir(fullfile(folder,'*')); files=files(~[files.isdir]);
report.artifacts={files.name};
service_pipeline_write_json(file,report);
end

function metrics=runStage(stage,root,folder,selected)
metrics=struct();
switch stage
    case 'documents'
        metrics=service_validate_documents(root,folder);
    case 'environment'
        service_generate_static_context;
        context=service_init_geometry_unit;
        assert(all(isfinite(context.alpha_noisy_matrix(:))));
        save(fullfile(folder,'engine_context.mat'),'context');
        metrics.points=context.Points;
        metrics.stations=size(context.P_max_matrix,2);
    case {'unit','mapping_unit'}
        tests=dir(fullfile(root,'matlab','tests','unit_test_*.m'));
        if ~isempty(selected)
            tests=tests(strcmp({tests.name},[selected '.m']));
            assert(numel(tests)==1,'libtr:pipeline:Test','Selected test missing');
        end
        if strcmp(stage,'mapping_unit')
            names={'unit_test_lls_position.m','unit_test_wlls_position.m', ...
                'unit_test_gn_position.m','unit_test_gnp_position.m', ...
                'unit_test_mock_position.m','unit_test_mock_covariance.m', ...
                'unit_test_matmul3.m','unit_test_ensemble_metrics.m', ...
                'unit_test_graphical_experiments.m'};
            tests=tests(ismember({tests.name},names));
            assert(numel(tests)==numel(names),'Missing mapping dependency tests');
        end
        results=cell(1,numel(tests)); failures=0;
        for j=1:numel(tests)
            [~,name]=fileparts(tests(j).name);
            result=struct('name',name,'state','passed','error','');
            try
                service_pipeline_reset(root);
                output=evalc('feval(name);');
            catch exception
                output=''; result.state='failed'; failures=failures+1;
                result.error=getReport(exception,'extended','hyperlinks','off');
            end
            fid=fopen(fullfile(folder,[name '.log']),'w','n','UTF-8');
            assert(fid~=-1); fprintf(fid,'%s\n%s',output,result.error); fclose(fid);
            results{j}=result;
        end
        service_pipeline_write_json(fullfile(folder,'unit_results.json'),results);
        assert(failures==0,'libtr:pipeline:UnitFailures','%d of %d unit tests failed',failures,numel(tests));
        metrics.total=numel(tests);
    case 'mapping_integration'
        metrics=test_tis_ensemble(folder);
    case 'ensemble5000'
        metrics=test_tis_ensemble(folder,5000,false);
    case 'spectral_png'
        metrics=generate_tis_spectral_images(folder);
    case 'mapping_png'
        metrics=generate_tis_mapping_images(folder);
    case {'integration','png'}
        if strcmp(stage,'png')
            scenarios=tis_trajectory_scenarios;
            if ~all(cellfun(@(cfg) isfile(fullfile(folder,tis_context_filename(cfg))),scenarios))
                service_generate_static_context;
            end
            metrics.context_images=generate_context_test_images(folder,folder);
            assert(metrics.context_images.failures==0, ...
                'libtr:pipeline:ContextImages','Context scenarios failed; see context_images.json');
        end
        metrics.tis=test_tis_ensemble(folder);
        generate_filter2win_doc_images(folder);
        data=load(fullfile(folder,'filter2win_doc_data.mat'));
        assert(numel(data.t)==101 && all(diff(data.t)>0));
        expectedMissing=data.t(:)>114 & data.t(:)<170;
        assert(all(isnan(data.filtered(expectedMissing))), ...
            'libtr:pipeline:Trajectory','Missing-data hold exceeded without NaN');
        assert(all(isfinite(data.filtered(data.t(:)<30))), ...
            'libtr:pipeline:Trajectory','Initial normal segment is not finite');
        assert(~any(isinf(data.filtered)) && all(data.power>=0 & data.power<=20));
        metrics.samples=numel(data.t);
        valid=isfinite(data.filtered(:));
        truth=data.truth(:);
        metrics.rmse_finite=sqrt(mean((data.filtered(valid)-truth(valid)).^2));
        metrics.finite_samples=sum(valid);
        metrics.missing_samples=sum(~valid);
        metrics.max_window=max(data.power);
        metrics.seed=1729;
        service_pipeline_write_json(fullfile(folder,'trajectory_metrics.json'),metrics);
    case 'liveeditor'
        sources=dir(fullfile(root,'docs','liveeditor','*_theory.m'));
        results=cell(1,numel(sources)); failures=0;
        for j=1:numel(sources)
            source=fullfile(sources(j).folder,sources(j).name);
            [~,name]=fileparts(source);
            result=struct('name',name,'state','passed','error','');
            try
                issues=checkcode(source,'-id');
                assert(isempty(issues),'libtr:pipeline:CodeAnalyzer','Code Analyzer reported %d issues',numel(issues));
                export(source,fullfile(folder,[name '.pdf']), ...
                    'Run',false,'HideCode',true,'OpenExportedFile',false);
                pdf=dir(fullfile(folder,[name '.pdf'])); assert(pdf.bytes>0);
            catch exception
                result.state='failed'; failures=failures+1;
                result.error=getReport(exception,'extended','hyperlinks','off');
            end
            results{j}=result;
        end
        service_pipeline_write_json(fullfile(folder,'liveeditor_results.json'),results);
        assert(failures==0,'libtr:pipeline:LiveEditor','%d exports failed',failures);
        metrics.exports=numel(sources);
        metrics.executed=false;
        metrics.visual_review='pending';
    otherwise
        error('libtr:pipeline:Action','Unknown stage');
end
end

function restore(previous,oldpath,state)
cd(previous); path(oldpath); rng(state);
end