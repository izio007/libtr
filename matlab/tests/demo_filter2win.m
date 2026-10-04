function demo_filter2win(output_dir)
% Random plateau levels/onset times and irregular timestamps are test inputs.
% Run after integration through the project's registered MATLAB executor.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1, output_dir=fullfile(root,'runtime','demo'); end
if ~isfolder(output_dir), mkdir(output_dir); end
oldpath=path; oldrng=rng;
cleanup=onCleanup(@() restore(oldpath,oldrng));
addpath(fullfile(root,'matlab','function'),fullfile(root,'matlab','tests','support'));
cfg=filter2win_config(fullfile(root,'matlab','tests','configs','filter2win_config.json'));
spec=jsondecode(fileread(fullfile(root,'matlab','tests','configs','filter2win_demo_scenario.json')));
rng(spec.seed,'twister');
dt=spec.dt_range(1)+diff(spec.dt_range)*rand(1,spec.samples);
time=cumsum(dt);
base=spec.level_range(1)+diff(spec.level_range)*rand;
height=spec.jump_range(1)+diff(spec.jump_range)*rand;
onset=spec.onset_fraction(1)+diff(spec.onset_fraction)*rand;
duration=spec.duration_fraction(1)+diff(spec.duration_fraction)*rand;
start_time=time(1)+onset*(time(end)-time(1));
end_time=start_time+duration*(time(end)-time(1));
expected_level=base*ones(size(time));
expected_level(time>=start_time & time<=end_time)=base+height;
measured=expected_level+spec.noise_std*randn(size(time));
missing=rand(size(time))<spec.missing_probability;
measured(missing)=NaN;
ctx=struct(); output=NaN(size(time)); status=zeros(size(time)); records=cell(size(time));
fid=fopen(fullfile(output_dir,'FILTER_STATUS_debug.log'),'w','n','UTF-8');
assert(fid~=-1); file_cleanup=onCleanup(@() fclose(fid));
for k=1:numel(time)
    [rc,ctx,d]=filter2win(cfg,ctx,time(k),measured(k),missing(k));
    fprintf(fid,'%s\n',filter2win_debug_line(d));
    assert(rc==0,'libtr:demo:Refused','Step refused: %s',d.reason);
    output(k)=ctx.X_FILTERED_OUTPUT; status(k)=ctx.FILTER_STATUS; records{k}=d;
end
save(fullfile(output_dir,'filter2win_demo.mat'), ...
    'cfg','spec','time','expected_level','measured','output','status','records');
f=figure('Visible','off','Color','w','Position',[100 100 1200 750]);
figure_cleanup=onCleanup(@() close(f));
subplot(2,1,1);
plot(time,expected_level,'k--'); hold on; plot(time,measured,'r.');
plot(time,output,'b-','LineWidth',1.5); grid on;
xlabel('Time, s'); ylabel('Scalar coordinate');
title(sprintf('Random plateau levels/times, irregular sampling; seed %d',spec.seed));
legend('Input plateau model','Measurements','Filter output','Location','best');
subplot(2,1,2); stairs(time,status,'LineWidth',1.2); grid on;
xlabel('Time, s'); ylabel('FILTER_STATUS'); yticks(0:16);
exportgraphics(f,fullfile(output_dir,'filter2win_demo.png'),'Resolution',150);
end

function restore(oldpath,oldrng)
path(oldpath); rng(oldrng);
end
