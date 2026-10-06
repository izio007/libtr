function run_filter2win_package
% Test and render the extracted package without any project-specific paths.
package = fileparts(fileparts(fileparts(mfilename('fullpath'))));
config = jsondecode(fileread(fullfile(package, 'matlab', 'tests', ...
    'configs', 'filter2win_package_case.json')));
addpath(fullfile(package,'matlab','tests','support'));
config.filter=filter2win_config(fullfile(package,'matlab','tests','configs',config.filter_config));
output = fullfile(package, 'results');
if ~isfolder(output)
    mkdir(output);
end
report = struct('package_version', config.package_version, 'status', 'NOT_RUN', ...
    'matlab', version, 'pid', feature('getpid'), 'cwd', pwd, 'path', path, ...
    'checks', {{}}, 'visual_review', 'NOT_RUN', ...
    'new_server', strcmp(getenv('FILTER2WIN_FRESH_HOST'), '1'));
clock = tic;
try
    for name = reshape(config.production_functions,1,[])
        resolved = which(name{1});
        expected = fullfile(package, 'matlab', 'function', [name{1} '.m']);
        assert(strcmpi(resolved, expected), 'libtr:package:Path', 'Wrong function: %s', resolved);
        report.checks{end+1} = struct('id', ['path_' name{1}], 'status', 'PASS');
    end
    for k = 1:numel(config.forbidden_functions)
        assert(isempty(which(config.forbidden_functions{k})), ...
            'libtr:package:Dependency', 'Forbidden function is accessible');
    end
    entries = strsplit(path, pathsep);
    for k = 1:numel(entries)
        allowed = startsWith(lower(entries{k}), lower([matlabroot filesep])) || ...
            startsWith(lower(entries{k}), lower([package filesep]));
        assert(allowed, 'libtr:package:ExternalPath', 'External path: %s', entries{k});
    end
    report.checks{end+1} = struct('id', 'path_isolation', 'status', 'PASS');
    for k = 1:numel(config.checks)
        feval(config.checks{k});
        report.checks{end+1} = struct('id', config.checks{k}, 'status', 'PASS');
    end
    demo_filter2win(output);
    report.checks{end+1} = struct('id', 'filter2win_demo', 'status', 'PASS');
    generatePlots(config, output);
    report.checks{end+1} = struct('id', 'plots', 'status', 'PASS');
    for k = 1:numel(config.documents)
        name = config.documents{k};
        source = fullfile(package, 'docs', 'liveeditor', [name '_theory.m']);
        pdf = fullfile(package, 'docs', [name '.pdf']);
        mlx = fullfile(package, 'docs', 'liveeditor', [name '_theory.mlx']);
        % R2025a conversion API; verify the result, never relabel a text file.
        model=matlab.internal.livecode.FileModel.convertFileToLiveCode(source, mlx);
        assert(~isempty(model),'libtr:package:MLX','Live Code conversion failed');
        assert(isfile(mlx), 'libtr:package:MLX', 'MLX conversion failed');
        container=java.util.zip.ZipFile(mlx);
        containerCleanup=onCleanup(@() container.close());
        assert(~isempty(container.getEntry('matlab/document.xml')), ...
            'libtr:package:MLX','Not a binary Live Code container');
        clear containerCleanup;
        % PDF is rendered from the same generated HTML by the release builder.
        % MLX conversion remains MATLAB-native and independent of the CEF editor.
        handle=fopen(pdf,'r');
        assert(handle~=-1,'libtr:package:PDF','Missing rendered PDF');
        signature=fread(handle,5,'*char')'; fclose(handle);
        assert(strcmp(signature,'%PDF-'),'libtr:package:PDF','Invalid PDF signature');
        metadata = dir(pdf);
        assert(~isempty(metadata) && metadata.bytes > 0, 'libtr:package:PDF', 'PDF export failed');
        report.checks{end+1} = struct('id', ['documents_' name], 'status', 'PASS');
    end
    report.status = 'PASS';
catch exception
    report.status = 'FAILED';
    report.failure_reason = exception.message;
    report.stack = exception.stack;
    report.seconds = toc(clock);
    writeReport(fullfile(output, 'matlab_results.json'), report);
    rethrow(exception);
end
report.seconds = toc(clock);
writeReport(fullfile(output, 'matlab_results.json'), report);
end

function generatePlots(config, output)
time = config.time(:);
measurement = config.measurement(:);
reference = config.reference(:);
missing = config.missing(:);
filtered = NaN(size(time));
power = zeros(size(time));
state = struct();
for k = 1:numel(time)
    [status, state] = filter2win(config.filter, state, time(k), measurement(k), missing(k));
    assert(status == 0, 'libtr:package:Scenario', 'Filter refused sample %d', k);
    filtered(k) = state.X_FILTERED_OUTPUT;
    power(k) = state.FILTER_STATE.alt.count;
end
save(fullfile(output, 'plot_data.mat'), 'time', 'measurement', 'reference', 'missing', 'filtered', 'power');
fig = figure('Visible', 'off', 'Color', 'w');
cleanup = onCleanup(@() close(fig));
displayMeasurement = measurement;
displayMeasurement(missing) = NaN;
plot(time, reference, 'k--', time, displayMeasurement, 'r.', time, filtered, 'b-o');
grid on;
xlabel('Time, s'); ylabel('Scalar coordinate');
legend('Reference', 'Measurement', 'Filter', 'Location', 'best');
title(['filter2win ' config.package_version ' — synthetic scalar sequence']);
exportgraphics(fig, fullfile(output, 'trajectory.png'), 'Resolution', 150);
clf(fig);
subplot(2, 1, 1); stairs(time, power); grid on;
ylabel('Alternative count');
title(['filter2win ' config.package_version ' — window and availability']);
subplot(2, 1, 2); stairs(time, double(isfinite(filtered))); grid on;
xlabel('Time, s'); ylabel('Finite output');
exportgraphics(fig, fullfile(output, 'window.png'), 'Resolution', 150);
end

function writeReport(file, report)
handle = fopen(file, 'w', 'n', 'UTF-8');
assert(handle ~= -1, 'libtr:package:IO', 'Cannot write report');
cleanup = onCleanup(@() fclose(handle));
fprintf(handle, '%s\n', jsonencode(report));
end