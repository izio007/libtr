function generate_filter2win_doc_images(out)
% GENERATE_FILTER2WIN_DOC_IMAGES Снимки фактического исполнения filter2win.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin == 0, out = fullfile(root, 'runtime'); end
if ~exist(out, 'dir'), mkdir(out); end
oldpath = path;
state = rng;
cleanup = onCleanup(@() restore(oldpath, state));
addpath(fullfile(root,'matlab','function'), ...
    fullfile(root,'matlab','tests','support'));
[spec,cfg]=filter2win_observation_config;
rng(spec.seed,spec.rng_algorithm);
[t, truth, measured, filtered, power] = filter2win_scenario;
save(fullfile(out,'filter2win_doc_data.mat'), ...
    't','truth','measured','filtered','power');
f = figure('Visible','off','Color','w','Position',[100 100 1100 550]);
figureCleanup = onCleanup(@() close(f));
plot(t,truth,'k-','LineWidth',1.5); hold on;
plot(t,measured,'r.');
plot(t,filtered,'b-','LineWidth',1.5);
grid on;
xlabel('Time, s'); ylabel('X, km');
title(sprintf('filter2win: actual kernel output, seed %d',spec.seed));
legend('Reference','Measurements','Filter output','Location','best');
exportgraphics(f,fullfile(out,'filter2win_trajectory.png'),'Resolution',150);
clf(f);
stairs(t,power,'b-','LineWidth',1.5); grid on;
xlabel('Time, s'); ylabel('Alternative window count');
title('filter2win: actual alternative window occupancy');
exportgraphics(f,fullfile(out,'filter2win_window.png'),'Resolution',150);
assert(numel(t)==spec.expected_samples && all(isfinite(power)));
assert(all(power >= 0 & power <= cfg.alt.capacity));
fid = fopen(fullfile(out,'filter2win_image_metrics.txt'),'w');
assert(fid ~= -1);
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid,'seed=%d\nsamples=%d\nfinite_output=%d\nmax_window=%g\n', ...
    spec.seed,numel(t),sum(isfinite(filtered)),max(power));
fprintf('filter2win PNG snapshots: SUCCESS\n');
end

function restore(oldpath, state)
path(oldpath);
rng(state);
end