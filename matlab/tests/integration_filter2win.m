function result = integration_filter2win(folder,showFigures)
% INTEGRATION_FILTER2WIN Bearings -> WLLS -> three scalar filter2win consumers.
% Coordinates/settings are metres, time is seconds, bearing noise is radians.
% Truth is used by the observation generator and metrics, never by a solver
% or a filter decision. X/Y/Z filters have separate state, not a joint covariance.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1, folder=fullfile(root,'runtime','integration_filter2win'); end
if nargin<2, showFigures=false; end
validateattributes(showFigures,{'logical'},{'scalar'});
oldpath=path; cleanup=onCleanup(@() path(oldpath));
addpath(fullfile(root,'matlab','tests'),fullfile(root,'matlab','tests','support'), ...
    fullfile(root,'matlab','function'),fullfile(root,'matlab','engine'));
if ~isfolder(folder), mkdir(folder); end

% One physical trajectory; controlled disturbances enter before the solver.
scenarios=tis_trajectory_scenarios; geometry=scenarios{1};
stations=[geometry.Stations.X_anchors;geometry.Stations.Y_anchors;geometry.Stations.Z_anchors];
time=0:180; n=numel(time); phase=time/time(end);
truth=[geometry.Trajectory.X_limits(1)+diff(geometry.Trajectory.X_limits)*phase; ...
    geometry.Trajectory.Y_center_true*ones(1,n); 1000+300*sin(pi*phase)];
seed=1729; sigma=0.02*pi/180;
biased=time>=70 & time<=94; missing=time>=120 & time<=134;
spikes=ismember(time,[40 155]);
source=truth; source(:,biased)=source(:,biased)+[2200;1400;800];
random=engine_rng_init(seed);
alpha=zeros(size(stations,2),n); beta=alpha;
for k=1:n
    [P,alpha(:,k),beta(:,k),variance,random]= ...
        service_sample_bearings(stations,source(:,k),sigma,1,1,random);
end
alpha(:,spikes)=alpha(:,spikes)+[0.06;-0.05;0.04;-0.06];
beta(:,spikes)=beta(:,spikes)+[0.03;-0.02;0.025;-0.03];
alpha(:,missing)=NaN; beta(:,missing)=NaN;

% The existing trajectory engine calls the real solver at every timestamp.
model=test_trajectory_init(@solve_available,time,P,alpha,beta,variance,variance,truth);
for k=1:n, model=test_model_step(model); end
raw=test_model_result(model);
assert(~any(raw.contract_violations),'libtr:integration:Solver','Solver output contract failed');
assert(all(raw.valid(~missing)) && all(raw.statuses(missing)==1), ...
    'libtr:integration:Observations','Available/missing bearings were not propagated');

% An explicit experimental profile in SI units. Linear velocity is estimated
% from solver observations; the true trajectory speed is not supplied.
profile=struct('profile_version',1,'window',struct('capacity',18,'min_samples',8, ...
    'min_span_seconds',7,'radius',250,'max_mad',120,'max_range',600), ...
    'hold',struct('outliers_seconds',6,'missing_seconds',6), ...
    'handover',struct('wait_seconds',2,'duration_seconds',4), ...
    'return_to_main',struct('wait_seconds',2,'duration_seconds',4));
window=struct('model','linear','linear_min_pair_seconds',1, ...
    'trim',struct('scale_floor',25));
profile.advanced=struct('main',window,'alt',window);
cfg=filter2win_settings(profile);
filtered=NaN(3,n); records=cell(3,n); filters=cell(1,3); finalContexts=cell(1,3);
for axis=1:3
    model=test_filter_init(cfg,struct(),time,raw.samples(axis,:),~raw.valid,truth(axis,:));
    for k=1:n
        before=model.algorithm_state.ctx;
        model=test_model_step(model);
        assert(~model.result.contract_violations(k),'libtr:integration:Filter', ...
            'Filter axis %d refused timestamp %.9g',axis,time(k));
        ctx=model.algorithm_state.ctx; d=ctx.FILTER_DEBUG;
        assert(isequaln(d.measurement,raw.samples(axis,k)) && d.missing==~raw.valid(k));
        assert(isequaln(d.output,model.result.samples(k)) && d.valid==isfinite(d.output));
        assert(ctx.FILTER_STATE.last_tick==time(k) && (~d.accepted || raw.valid(k)));
        assert(~d.valid || (d.active_window>0 && d.windows(d.active_window).ready));
        assert(d.main_count<=cfg.main.capacity && d.alt_count<=cfg.alt.capacity);
        % FIFO contents must be actual, available WLLS outputs, not predictions.
        for name={'main','alt'}
            [code,~,points]=fifo_double('read',ctx.FILTER_STATE.(name{1}));
            [found,index]=ismember(points.time,time(1:k));
            assert(code==0 && all(found) && all(raw.valid(index)));
            assert(isequal(points.value,raw.samples(axis,index)));
            if ~raw.valid(k) && k>1
                assert(isequaln(before.FILTER_STATE.(name{1}),ctx.FILTER_STATE.(name{1})), ...
                    'libtr:integration:Memory','Missing input changed retained observations');
            end
        end
        records{axis,k}=d;
    end
    filters{axis}=test_model_result(model);
    filtered(axis,:)=filters{axis}.samples;
    finalContexts{axis}=model.algorithm_state.ctx;
end
valid=isfinite(filtered); vectorValid=all(valid,1);
lateGap=missing & time>time(find(missing,1))+cfg.flow.gap_hold_seconds;
assert(~any(isinf(filtered(:))) && ~any(any(valid(:,lateGap))), ...
    'libtr:integration:Hold','Unavailable observations outlived the configured hold');
assert(any(vectorValid & raw.valid),'libtr:integration:Output','No complete filtered positions');
active=cellfun(@(d)d.active_window,records); states=cellfun(@(d)d.status,records);
mainCount=cellfun(@(d)d.main_count,records); altCount=cellfun(@(d)d.alt_count,records);
accepted=cellfun(@(d)d.accepted,records);
filteredMetrics=service_ensemble_metrics(filtered-truth,double(~vectorValid),zeros(3,1));
common=raw.valid & vectorValid;
rawCommon=service_ensemble_metrics(raw.samples-truth,double(~common),zeros(3,1));
filteredCommon=service_ensemble_metrics(filtered-truth,double(~common),zeros(3,1));
metrics=struct('raw_valid',sum(raw.valid),'filtered_valid',sum(vectorValid), ...
    'common_valid',sum(common),'raw_rmse_m',raw.metrics.rmse, ...
    'filtered_rmse_m',filteredMetrics.rmse,'raw_rmse_common_m',rawCommon.rmse, ...
    'filtered_rmse_common_m',filteredCommon.rmse, ...
    'window_switches_per_axis',sum(active(:,2:end)>0 & active(:,1:end-1)>0 & ...
        active(:,2:end)~=active(:,1:end-1),2).');

artifacts=struct('data','filter2win_integration.mat','trace','filter2win_integration.csv', ...
    'trajectory','filter2win_integration_trajectory.png','states','filter2win_integration_states.png', ...
    'summary','filter2win_integration.json');
save(fullfile(folder,artifacts.data),'time','truth','stations','source','alpha','beta', ...
    'variance','sigma','seed','random','biased','missing','spikes','profile','cfg','raw', ...
    'filtered','filters','records','finalContexts','metrics');
labels={'X','Y','Z'}; tables=cell(1,3);
for axis=1:3
    event=cellfun(@(d)d.event,records(axis,:),'UniformOutput',false).';
    reason=cellfun(@(d)d.reason,records(axis,:),'UniformOutput',false).';
    tables{axis}=table(time.',repmat(labels(axis),n,1),truth(axis,:).',raw.samples(axis,:).', ...
        filtered(axis,:).',raw.statuses.',valid(axis,:).',states(axis,:).',active(axis,:).', ...
        accepted(axis,:).',mainCount(axis,:).',altCount(axis,:).',event,reason, ...
        'VariableNames',{'time_s','axis','truth_m','solver_m','filtered_m','solver_status', ...
        'filter_valid','filter_status','active_window','accepted','count_A','count_B','event','reason'});
end
writetable(vertcat(tables{:}),fullfile(folder,artifacts.trace));
plot_trajectory(folder,artifacts.trajectory,showFigures,time,truth,stations,raw,filtered,metrics);
plot_states(folder,artifacts.states,showFigures,time,active,states,mainCount,altCount);
result=struct('name','filter2win','state','passed','failures',0,'samples',n,'seed',seed, ...
    'solver','wlls_position','filter_mode','three independent scalar axes', ...
    'noise_sigma_degrees',sigma*180/pi,'output_dir',folder,'metrics',metrics, ...
    'checks',{{'solver and filter contracts','solver outputs reach real FIFOs', ...
    'missing input retains memory','hold expires','valid output has a ready active window'}}, ...
    'artifacts',artifacts);
fid=fopen(fullfile(folder,artifacts.summary),'w','n','UTF-8');
assert(fid~=-1,'libtr:integration:IO','Cannot write integration summary');
closefile=onCleanup(@() fclose(fid)); fprintf(fid,'%s\n',jsonencode(result));
fprintf('Filter integration: %d solver / %d filtered positions; common-frame RMSE %.3f / %.3f m.\n', ...
    metrics.raw_valid,metrics.filtered_valid,metrics.raw_rmse_common_m,metrics.filtered_rmse_common_m);
end

function [status,x]=solve_available(P,alpha,beta,va,vb)
% Measurement availability is handled before the unchanged numerical solver.
available=isfinite(alpha) & isfinite(beta);
[status,x]=wlls_position(P(:,available),alpha(available),beta(available),va(available),vb(available));
end

function plot_trajectory(folder,file,showFigures,time,truth,stations,raw,filtered,metrics)
visibility='off'; if showFigures, visibility='on'; end
f=figure('Visible',visibility,'Color','w','Position',[60 60 1280 850], ...
    'Name','Integration: bearings, WLLS and filter2win','NumberTitle','off');
cleanup=onCleanup(@() close_owned(f,showFigures));
ax=subplot(2,2,1,'Parent',f);
plot(ax,truth(1,:)/1000,truth(2,:)/1000,'k-','LineWidth',1.8); hold(ax,'on');
plot(ax,raw.samples(1,:)/1000,raw.samples(2,:)/1000,'.','Color',[.85 .4 .1]);
plot(ax,filtered(1,:)/1000,filtered(2,:)/1000,'b-','LineWidth',1.3);
plot(ax,stations(1,:)/1000,stations(2,:)/1000,'kv','MarkerFaceColor','k');
axis(ax,'equal'); grid(ax,'on'); xlabel(ax,'X, km'); ylabel(ax,'Y, km');
title(ax,'Actual horizontal trajectory and station geometry');
legend(ax,'Truth','WLLS','Filtered','Stations','Location','best');
ax=subplot(2,2,2,'Parent',f);
plot(ax,time,truth(3,:),'k-','LineWidth',1.5); hold(ax,'on');
plot(ax,time,raw.samples(3,:),'.','Color',[.85 .4 .1]);
plot(ax,time,filtered(3,:),'b-','LineWidth',1.3);
grid(ax,'on'); xlabel(ax,'Time, s'); ylabel(ax,'Z, m'); title(ax,'Vertical trajectory');
legend(ax,'Truth','WLLS','Filtered','Location','best');
ax=subplot(2,2,3,'Parent',f);
plot(ax,time,sqrt(sum((raw.samples-truth).^2,1)),'Color',[.85 .4 .1]); hold(ax,'on');
plot(ax,time,sqrt(sum((filtered-truth).^2,1)),'b-','LineWidth',1.3);
xline(ax,70,'--','Biased bearings','HandleVisibility','off');
xline(ax,95,'--','Return','HandleVisibility','off');
xline(ax,120,':','Gap','HandleVisibility','off'); xline(ax,135,':','Resume','HandleVisibility','off');
grid(ax,'on'); xlabel(ax,'Time, s'); ylabel(ax,'3D error, m');
title(ax,sprintf('Same-frame RMSE: WLLS %.1f m; filtered %.1f m', ...
    metrics.raw_rmse_common_m,metrics.filtered_rmse_common_m));
legend(ax,'WLLS','Filtered','Location','best');
ax=subplot(2,2,4,'Parent',f);
stairs(ax,time,double(raw.valid),'Color',[.85 .4 .1],'LineWidth',1.4); hold(ax,'on');
stairs(ax,time,double(all(isfinite(filtered),1)),'b-','LineWidth',1.2);
ylim(ax,[-.1 1.1]); yticks(ax,[0 1]); grid(ax,'on');
xlabel(ax,'Time, s'); ylabel(ax,'Complete finite position');
title(ax,'Availability: warmup, missing bearings and hold');
legend(ax,'WLLS','Filtered XYZ','Location','best');
exportgraphics(f,fullfile(folder,file),'Resolution',140);
if showFigures, drawnow; end
end

function plot_states(folder,file,showFigures,time,active,states,mainCount,altCount)
visibility='off'; if showFigures, visibility='on'; end
f=figure('Visible',visibility,'Color','w','Position',[90 80 1200 900], ...
    'Name','Integration: filter2win actual states','NumberTitle','off');
cleanup=onCleanup(@() close_owned(f,showFigures));
ax=subplot(3,1,1,'Parent',f); stairs(ax,time,active.','LineWidth',1.2);
grid(ax,'on'); yticks(ax,[0 1 2]); ylim(ax,[-.1 2.1]);
ylabel(ax,'0 none, 1 A, 2 B'); title(ax,'Active physical window for each coordinate');
legend(ax,'X','Y','Z','Location','eastoutside');
ax=subplot(3,1,2,'Parent',f); stairs(ax,time,states.','LineWidth',1.2);
grid(ax,'on'); yticks(ax,[0:8 10:15]); ylabel(ax,'FILTER_STATUS','Interpreter','none');
title(ax,'Executed filter states; events and reasons are saved in CSV');
legend(ax,'X','Y','Z','Location','eastoutside');
ax=subplot(3,1,3,'Parent',f); hold(ax,'on'); colors=lines(3);
for axis=1:3
    stairs(ax,time,mainCount(axis,:),'-','Color',colors(axis,:),'LineWidth',1.2);
    stairs(ax,time,altCount(axis,:),'--','Color',colors(axis,:),'LineWidth',1.2);
end
grid(ax,'on'); xlabel(ax,'Time, s'); ylabel(ax,'Retained solver observations');
title(ax,'FIFO memory: solid A, dashed B');
legend(ax,'A-X','B-X','A-Y','B-Y','A-Z','B-Z','Location','eastoutside');
exportgraphics(f,fullfile(folder,file),'Resolution',140);
if showFigures, drawnow; end
end

function close_owned(f,showFigures)
if ~showFigures && isgraphics(f), close(f); end
end
