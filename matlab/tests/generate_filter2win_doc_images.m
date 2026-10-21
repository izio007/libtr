function generate_filter2win_doc_images(out,showFigures)
% Actual filter output; optional live figures use the same data as the PNGs.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1, out=fullfile(root,'runtime'); end
if nargin<2, showFigures=false; end
validateattributes(showFigures,{'logical'},{'scalar'});
visibility='off'; if showFigures, visibility='on'; end
if ~isfolder(out), mkdir(out); end
oldpath=path; state=rng;
cleanup=onCleanup(@() restore(oldpath,state));
addpath(fullfile(root,'matlab','function'), ...
    fullfile(root,'matlab','tests','support'));
[spec,cfg]=filter2win_observation_config;
rng(spec.seed,spec.rng_algorithm);
[t,truth,measured,filtered,power]=filter2win_scenario;
save(fullfile(out,'filter2win_doc_data.mat'), ...
    't','truth','measured','filtered','power');
f=figure('Visible',visibility,'Color','w','Position',[100 100 1100 550], ...
    'Name','filter2win trajectory','NumberTitle','off');
if ~showFigures, trajectoryCleanup=onCleanup(@() close(f)); end
ax=axes('Parent',f);
plot(ax,t,truth,'k-','LineWidth',1.5); hold(ax,'on');
plot(ax,t,measured,'r.');
plot(ax,t,filtered,'b-','LineWidth',1.5);
grid(ax,'on');
xlabel(ax,'Time, s'); ylabel(ax,'X, km');
title(ax,sprintf('filter2win: actual kernel output, seed %d',spec.seed));
legend(ax,'Reference','Measurements','Filter output','Location','best');
exportgraphics(f,fullfile(out,'filter2win_trajectory.png'),'Resolution',150);
if showFigures, drawnow; end

window=figure('Visible',visibility,'Color','w','Position',[120 120 1100 550], ...
    'Name','filter2win alternative window','NumberTitle','off');
if ~showFigures, windowCleanup=onCleanup(@() close(window)); end
ax=axes('Parent',window);
stairs(ax,t,power,'b-','LineWidth',1.5); grid(ax,'on');
xlabel(ax,'Time, s'); ylabel(ax,'Alternative window count');
title(ax,'filter2win: actual alternative window occupancy');
exportgraphics(window,fullfile(out,'filter2win_window.png'),'Resolution',150);
if showFigures, drawnow; end
assert(numel(t)==spec.expected_samples && all(isfinite(power)));
assert(all(power>=0 & power<=cfg.alt.capacity));
fid=fopen(fullfile(out,'filter2win_image_metrics.txt'),'w');
assert(fid~=-1);
fileCleanup=onCleanup(@() fclose(fid));
fprintf(fid,'seed=%d\nsamples=%d\nfinite_output=%d\nmax_window=%g\n', ...
    spec.seed,numel(t),sum(isfinite(filtered)),max(power));
fprintf('filter2win PNG snapshots: SUCCESS\n');
end

function restore(oldpath,state)
path(oldpath); rng(state);
end
