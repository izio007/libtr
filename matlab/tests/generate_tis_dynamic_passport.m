function report = generate_tis_dynamic_passport(contextFile,folder,runs)
setup_test_paths;
% Four-panel trajectory passport with independent ensembles at every cell.
if nargin<3, runs=32; end
validateattributes(runs,{'double'},{'scalar','integer','>=',2});
assert(~isfolder(folder),'libtr:experiment:Output','Use a new output folder');
data=load(contextFile); fields=fieldnames(data); assert(isscalar(fields));
cfg=data.(fields{1}); mkdir(folder);
context=engine_rng_init(cfg.Hardware.Random_Seed);
counts=unique(round(logspace(log10(4),log10(124),20)));
anchors=[cfg.Stations.X_anchors;cfg.Stations.Y_anchors;cfg.Stations.Z_anchors];
t=linspace(0,1,cfg.Trajectory.Points);
truth=[cfg.Trajectory.X_limits(1)+diff(cfg.Trajectory.X_limits)*t; ...
    cfg.Trajectory.Y_center_true*ones(size(t)); ...
    cfg.Trajectory.Z_base+cfg.Trajectory.Z_amplitude*sin(pi*t)];
records=cell(numel(counts),numel(t));
for n=1:numel(counts)
    stations=spline(1:4,anchors,linspace(1,4,counts(n)));
    for k=1:numel(t)
        [records{n,k},context]=tis_experiment_cell(stations,truth(:,k), ...
            cfg.Hardware.D_Error_Degree*pi/180,1,runs, ...
            fullfile(folder,sprintf('cell_%d_%d.mat',n,k)),context);
    end
    fprintf('Dynamic stations=%d points=%d runs=%d complete\n',counts(n),numel(t),runs); drawnow;
end
methods={'LLS','WLLS','GN','GNP'}; files=cell(1,4); selected=cfg.Hardware.Fixed_N_Index;
for m=1:4
    fig=figure('Visible','off','Position',[50 50 1400 900]); closer=onCleanup(@() close(fig));
    tiledlayout(fig,2,2); ax1=nexttile; hold(ax1,'on'); grid(ax1,'on');
    plot3(ax1,truth(1,:),truth(2,:),truth(3,:),'k-','LineWidth',2);
    stations=spline(1:4,anchors,linspace(1,4,counts(selected)));
    plot3(ax1,stations(1,:),stations(2,:),stations(3,:),'ks');
    sd=NaN(3,numel(t)); bound=sd; spatial=NaN(size(t));
    for k=1:numel(t)
        d=load(fullfile(folder,sprintf('cell_%d_%d.mat',selected,k)),'results');
        r=d.results{m}; valid=r.statuses==0 & all(isfinite(r.samples),1); x=r.samples(:,valid);
        scatter3(ax1,x(1,:),x(2,:),x(3,:),3,'.');
        sd(:,k)=records{selected,k}.std(:,m); bound(:,k)=records{selected,k}.crlb_std;
        spatial(k)=records{selected,k}.rmse(m);
    end
    view(ax1,3); title(ax1,'Truth, estimates and physical posts');
    xlabel(ax1,'X (m)'); ylabel(ax1,'Y (m)'); zlabel(ax1,'Z (m)');
    ax2=nexttile; hold(ax2,'on'); grid(ax2,'on'); colors=lines(3);
    labels={'X','Y','Z'};
    for a=1:3
        plot(ax2,t,bound(a,:),'--','Color',0.65+0.35*colors(a,:), ...
            'DisplayName',['CRLB ' labels{a}]);
        plot(ax2,t,sd(a,:),'Color',colors(a,:),'DisplayName',['SD ' labels{a}]);
    end
    plot(ax2,t,spatial,'k-','LineWidth',2.5,'DisplayName','Spatial RMSE');
    xlabel(ax2,'Normalized trajectory coordinate'); ylabel(ax2,'Metres'); legend(ax2,'Location','best');
    title(ax2,'Centered SD / CRLB / spatial RMSE');
    ax3=nexttile; hold(ax3,'on'); grid(ax3,'on');
    ax4=nexttile; hold(ax4,'on'); grid(ax4,'on');
    pooled=NaN(size(counts)); maxMiss=pooled;
    for n=1:numel(counts)
        weights=cellfun(@(r) r.successful(m),records(n,:));
        errors=cellfun(@(r) r.rmse(m),records(n,:)); good=weights>0;
        if any(good)
            pooled(n)=sqrt(sum(weights(good).*errors(good).^2)/sum(weights(good)));
            maxMiss(n)=max(cellfun(@(r) r.max_miss(m),records(n,good)));
        end
        bias=cellfun(@(r) r.bias(2,m),records(n,:));
        plot(ax4,t,bias,'DisplayName',sprintf('N=%d',counts(n)));
    end
    plot(ax3,counts,maxMiss,'o-',counts,pooled,'s-','LineWidth',1.5); set(ax3,'XScale','log');
    xlabel(ax3,'Physical station count'); ylabel(ax3,'Metres'); legend(ax3,'Max Miss','Pooled RMSE');
    title(ax3,'Conditional error versus redundancy');
    xlabel(ax4,'Normalized trajectory coordinate'); ylabel(ax4,'Bias Y (m)');
    title(ax4,'Range bias including trajectory flanks'); legend(ax4,'Location','eastoutside');
    failures=sum(cellfun(@(r) r.failure_fraction(m)>0,records(:)));
    sgtitle(sprintf('%s / %d runs per cell / cells with failures: %d',methods{m},runs,failures));
    assert(numel(findall(fig,'Type','axes'))==4);
    files{m}=['dynamic_' methods{m} '.png']; exportgraphics(fig,fullfile(folder,files{m})); clear closer;
end
failed=sum(cellfun(@(r) any(r.failure_fraction>0 | r.violations>0) || r.crlb_status~=0,records(:)));
report=struct('context',contextFile,'runs',runs,'counts',counts,'records',{records}, ...
    'files',{files},'failed_cells',failed,'passed',failed==0,'crlb_source','mock_covariance');
save(fullfile(folder,'dynamic_summary.mat'),'cfg','truth','counts','records');
service_pipeline_write_json(fullfile(folder,'dynamic_report.json'),report);
end