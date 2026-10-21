function summary = generate_context_test_images(contextFolder,folder,showFigures,scenarios)
setup_test_paths;
% Full trajectories and central-point ensembles from saved configurations.
if nargin<3, showFigures=false; end
validateattributes(showFigures,{'logical'},{'scalar'});
if nargin<4, scenarios=tis_trajectory_scenarios; end
state=rng; cleanup=onCleanup(@() rng(state));
if ~isfolder(folder), mkdir(folder); end
names=cellfun(@(cfg) erase(erase(tis_context_filename(cfg),'context_'),'.mat'), ...
    scenarios,'UniformOutput',false); reports={}; files={};
for c=1:numel(names)
    input=fullfile(contextFolder,['context_' names{c} '.mat']);
    data=load(input); fields=fieldnames(data); assert(numel(fields)==1);
    cfg=data.(fields{1});
    counts=unique(round(logspace(log10(4),log10(124),20)));
    M=counts(cfg.Hardware.Fixed_N_Index);
    anchors=[cfg.Stations.X_anchors;cfg.Stations.Y_anchors;cfg.Stations.Z_anchors];
    P=spline(1:4,anchors,linspace(1,4,124)); P=P(:,1:M);
    t=linspace(0,1,cfg.Trajectory.Points);
    truth=[cfg.Trajectory.X_limits(1)+diff(cfg.Trajectory.X_limits)*t; ...
        cfg.Trajectory.Y_center_true*ones(size(t)); ...
        cfg.Trajectory.Z_base+cfg.Trajectory.Z_amplitude*sin(pi*t)];
    sigma=cfg.Hardware.D_Error_Degree*pi/180;
    variance=repmat(sigma^2,M,1); N=cfg.Hardware.N_Monte_Carlo;
    a=zeros(M,numel(t)); b=a;
    for j=1:M
        d=truth-P(:,j);
        a(j,:)=atan2(d(2,:),d(1,:));
        b(j,:)=atan2(d(3,:),hypot(d(1,:),d(2,:)));
    end
    rng(cfg.Hardware.Random_Seed,'twister');
    alpha=a+sigma*randn(size(a)); beta=b+sigma*randn(size(b));
    mid=round(numel(t)/2);
    rng(cfg.Hardware.Random_Seed+1,'twister');
    aa=a(:,mid)+sigma*randn(M,N); bb=b(:,mid)+sigma*randn(M,N);
    save(fullfile(folder,['context_' names{c} '_inputs.mat']), ...
        'cfg','P','truth','t','alpha','beta','aa','bb','variance','mid');
    for m=1:numel(cfg.Methods.Solvers)
        method=cfg.Methods.Solvers{m}; solver=str2func(method);
        pathResult=service_run_path(solver,t,P,alpha,beta,variance,variance,truth);
        trajectory=pathResult.samples; statuses=pathResult.statuses;
        ensemble=service_run_ensemble(solver,P,aa,bb,variance,variance,truth(:,mid));
        pathValid=test_result_valid_mask(pathResult);
        ensembleValid=test_result_valid_mask(ensemble);
        [mockStatus,mock]=mock_position(P,a(:,mid),b(:,mid),variance,variance);
        report=struct('context',names{c},'method',method,'samples',N, ...
            'trajectory_failures',sum(~pathValid), ...
            'metrics',ensemble.metrics,'mock_status',mockStatus, ...
            'mock_delta',norm(mock-truth(:,mid)));
        report.passed=report.trajectory_failures==0 && ...
            ~any(pathResult.contract_violations) && ...
            ensemble.metrics.failure_fraction==0 && ~any(ensemble.contract_violations) && mockStatus==0;
        stem=['context_' names{c} '_' method];
        save(fullfile(folder,[stem '.mat']),'trajectory','statuses','ensemble','report','pathResult');
        fig=figure('Visible','off','Position',[100 100 1200 850], ...
            'Name',['TIS integration: ' names{c} ' / ' method],'NumberTitle','off');
        closer=onCleanup(@() closeHidden(fig));
        layout=tiledlayout(fig,2,2);
        ax=nexttile(layout,1);
        plot3(ax,truth(1,:),truth(2,:),truth(3,:),'k-', ...
            trajectory(1,:),trajectory(2,:),trajectory(3,:),'.');
        grid(ax,'on'); axis(ax,'equal'); title(ax,'Truth and estimated trajectory');
        xlabel(ax,'East (m)'); ylabel(ax,'North (m)'); zlabel(ax,'Up (m)');
        legend(ax,'Truth','Estimate','Location','best');
        ax=nexttile(layout,2);
        errorNorm=sqrt(sum((trajectory-truth).^2,1)); errorNorm(~pathValid)=NaN;
        plot(ax,t,errorNorm);
        grid(ax,'on'); xlabel(ax,'Normalized trajectory parameter'); ylabel(ax,'Single-sample error (m)');
        title(ax,sprintf('Trajectory failures: %d',report.trajectory_failures));
        ax=nexttile(layout,3); cloud=ensemble.samples(:,ensembleValid)-truth(:,mid);
        scatter3(ax,cloud(1,:),cloud(2,:),cloud(3,:),4,'.'); hold(ax,'on');
        mu=ensemble.metrics.bias; plot3(ax,mu(1),mu(2),mu(3),'rx','MarkerSize',12);
        grid(ax,'on'); axis(ax,'equal');
        xlabel(ax,'East error (m)'); ylabel(ax,'North error (m)'); zlabel(ax,'Up error (m)');
        title(ax,'Central-point ensemble and empirical bias');
        ax=nexttile(layout,4); bar(ax,ensemble.metrics.semiaxes); ylabel(ax,'Empirical semiaxis (m)');
        title(ax,sprintf('RMSE %.3g m; failures %.2f%%',ensemble.metrics.rmse,100*ensemble.metrics.failure_fraction));
        title(layout,sprintf('%s / %s / N=%d / PASS=%d',names{c},method,N,report.passed),'Interpreter','none');
        filename=[stem '.png']; exportgraphics(fig,fullfile(folder,filename));
        if showFigures, set(fig,'Visible','on'); drawnow; end
        clear closer;
        files{end+1}=filename; reports{end+1}=report; %#ok<AGROW>
    end
end
summary=struct('png_count',numel(files),'files',{files}, ...
    'failures',sum(cellfun(@(r) ~r.passed,reports)),'reports',{reports});
service_pipeline_write_json(fullfile(folder,'context_images.json'),summary);
end

function closeHidden(fig)
if isgraphics(fig) && strcmp(get(fig,'Visible'),'off'), close(fig); end
end
