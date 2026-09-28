function report = generate_tis_static_passport(folder,runs,repeats,range)
% Heavy four-post experiment; repeated raw observations, never averaged angles.
if nargin<2, runs=5000; end
if nargin<3, repeats=[1 2 4 8 16 31]; end
if nargin<4, range=450000; end
validateattributes(runs,{'double'},{'scalar','integer','>=',2});
validateattributes(repeats,{'double'},{'vector','integer','positive','increasing'});
validateattributes(range,{'double'},{'scalar','finite','positive'});
assert(~isfolder(folder),'libtr:experiment:Output','Use a new output folder');
mkdir(folder); state=rng; cleanup=onCleanup(@() rng(state)); rng(1337,'twister');
stations=[-20000 20000 0 0;0 0 -20000 20000;200 200 200 200];
truth=[0;range;10000]; sigma=2*pi/180;
records=cell(1,numel(repeats));
for k=1:numel(repeats)
    records{k}=tis_experiment_cell(stations,truth,sigma,repeats(k),runs, ...
        fullfile(folder,sprintf('repeat_%d.mat',repeats(k))));
    fprintf('Static repeats=%d runs=%d complete\n',repeats(k),runs); drawnow;
end
methods={'LLS','WLLS','GN','GNP'}; files=cell(1,4);
for m=1:4
    fig=figure('Visible','off','Position',[50 50 1600 550]); closer=onCleanup(@() close(fig));
    tiledlayout(fig,1,3);
    ax1=nexttile; hold(ax1,'on'); grid(ax1,'on');
    plot3(ax1,stations(1,:),stations(2,:),stations(3,:),'ks','DisplayName','Posts');
    plot3(ax1,truth(1),truth(2),truth(3),'rp','MarkerSize',12,'DisplayName','Truth');
    ax2=nexttile; hold(ax2,'on'); grid(ax2,'on');
    ax3=nexttile; hold(ax3,'on'); grid(ax3,'on');
    rmse=NaN(size(repeats)); failures=0;
    for k=1:numel(repeats)
        data=load(fullfile(folder,sprintf('repeat_%d.mat',repeats(k))),'results');
        r=data.results{m}; valid=r.statuses==0 & all(isfinite(r.samples),1);
        x=r.samples(:,valid); failures=failures+runs-sum(valid);
        label=sprintf('k=%d (%d/%d)',repeats(k),sum(valid),runs);
        scatter3(ax1,x(1,:),x(2,:),x(3,:),3,'.','DisplayName',label);
        if ~isempty(x), histogram(ax3,x(2,:)/1000,60,'DisplayStyle','stairs','DisplayName',label); end
        rmse(k)=records{k}.rmse(m);
    end
    plot(ax2,repeats,rmse,'o-','LineWidth',2); set(ax2,'XScale','log');
    xline(ax3,range/1000,'r--','Truth');
    title(ax1,'Geometry and empirical cloud'); xlabel(ax1,'X (m)'); ylabel(ax1,'Y (m)'); zlabel(ax1,'Z (m)'); view(ax1,3);
    title(ax2,'Conditional spatial RMSE'); xlabel(ax2,'Independent repeats per post'); ylabel(ax2,'RMSE (m)');
    title(ax3,'Empirical range distribution'); xlabel(ax3,'Y (km)'); ylabel(ax3,'Count');
    legend(ax1,'Location','best'); legend(ax3,'Location','best');
    sgtitle(sprintf('%s: four posts, 2 deg, %d runs/cell; failed trials=%d',methods{m},runs,failures));
    assert(numel(findall(fig,'Type','axes'))==3);
    files{m}=['static_' methods{m} '.png']; exportgraphics(fig,fullfile(folder,files{m})); clear closer;
end
failed=sum(cellfun(@(r) sum(r.failure_fraction>0 | r.violations>0),records));
report=struct('runs',runs,'repeats',repeats,'range',range,'physical_posts',4, ...
    'records',{records},'files',{files},'passed',failed==0,'failed_method_cells',failed);
service_pipeline_write_json(fullfile(folder,'static_report.json'),report);
end