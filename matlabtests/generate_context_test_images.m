function summary = generate_context_test_images(contextFolder,folder)
% Full trajectories and central-point ensembles from saved configurations.
state=rng; cleanup=onCleanup(@() rng(state));
if ~isfolder(folder), mkdir(folder); end
names={'30km','160km'}; reports={}; files={};
for c=1:numel(names)
    input=fullfile(contextFolder,['context_' names{c} '.mat']);
    data=load(input); cfg=data.(['cfg_' names{c}]);
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
        trajectory=NaN(size(truth)); statuses=NaN(size(t));
        for k=1:numel(t)
            [statuses(k),trajectory(:,k)]=solver(P,alpha(:,k),beta(:,k),variance,variance);
        end
        ensemble=service_run_ensemble(solver,P,aa,bb,variance,variance,truth(:,mid));
        [mockStatus,mock]=mock_position(P,a(:,mid),b(:,mid),variance,variance);
        report=struct('context',names{c},'method',method,'samples',N, ...
            'trajectory_failures',sum(statuses~=0 | any(~isfinite(trajectory),1)), ...
            'metrics',ensemble.metrics,'mock_status',mockStatus, ...
            'mock_delta',norm(mock-truth(:,mid)));
        report.passed=report.trajectory_failures==0 && ...
            ensemble.metrics.failure_fraction==0 && ~any(ensemble.contract_violations) && mockStatus==0;
        stem=['context_' names{c} '_' method];
        save(fullfile(folder,[stem '.mat']),'trajectory','statuses','ensemble','report');
        fig=figure('Visible','off','Position',[100 100 1200 850]);
        closer=onCleanup(@() close(fig)); tiledlayout(fig,2,2);
        nexttile; plot3(truth(1,:),truth(2,:),truth(3,:),'k-', ...
            trajectory(1,:),trajectory(2,:),trajectory(3,:),'.');
        grid on; axis equal; title('Truth and estimated trajectory');
        xlabel('East (m)'); ylabel('North (m)'); zlabel('Up (m)');
        nexttile; plot(t,sqrt(sum((trajectory-truth).^2,1)));
        grid on; xlabel('Normalized trajectory time'); ylabel('Single-sample error (m)');
        title(sprintf('Trajectory failures: %d',report.trajectory_failures));
        nexttile; cloud=ensemble.samples-truth(:,mid);
        scatter3(cloud(1,:),cloud(2,:),cloud(3,:),4,'.'); hold on;
        mu=ensemble.metrics.bias; plot3(mu(1),mu(2),mu(3),'rx','MarkerSize',12);
        grid on; axis equal; xlabel('East error (m)'); ylabel('North error (m)'); zlabel('Up error (m)');
        title('Central-point ensemble and empirical bias');
        nexttile; bar(ensemble.metrics.semiaxes); ylabel('Empirical semiaxis (m)');
        title(sprintf('RMSE %.3g m; failures %.2f%%',ensemble.metrics.rmse,100*ensemble.metrics.failure_fraction));
        sgtitle(sprintf('%s / %s / N=%d / PASS=%d',names{c},method,N,report.passed),'Interpreter','none');
        filename=[stem '.png']; exportgraphics(fig,fullfile(folder,filename)); clear closer;
        files{end+1}=filename; reports{end+1}=report; %#ok<AGROW>
    end
end
unit_test_cov2std(folder); unit_test_cov2std_3d(folder);
files=[files {'tis_cov2std_2d.png','tis_cov2std_3d.png'}];
for k=1:numel(files)
    info=imfinfo(fullfile(folder,files{k}));
    assert(strcmpi(info.Format,'png') && info.Width>0 && info.Height>0);
end
summary=struct('png_count',numel(files),'files',{files}, ...
    'failures',sum(cellfun(@(r) ~r.passed,reports)),'reports',{reports});
service_pipeline_write_json(fullfile(folder,'context_images.json'),summary);
end