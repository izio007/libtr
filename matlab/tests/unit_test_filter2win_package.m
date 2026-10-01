function unit_test_filter2win_package
% Registered transport adapter. Only the package is on path during acceptance.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
configFile = fullfile(root, 'matlab', 'tests', 'configs', 'filter2win_package_case.json');
config = jsondecode(fileread(configFile));
package = fullfile(root, config.package_relative_root);
assert(isfolder(package), 'libtr:package:Missing', 'Build and extract the package first');
oldPath = path;
oldFolder = pwd;
cleanup = onCleanup(@() restore(oldPath, oldFolder));
restoredefaultpath;
entries = strsplit(path, pathsep);
for k = 1:numel(entries)
    if ~startsWith(lower(entries{k}), lower([matlabroot filesep]))
        rmpath(entries{k});
    end
end
cd(package);
addpath(fullfile(package, 'matlab', 'function'), fullfile(package, 'matlab', 'tests'));
clear filter2win fifo_double unit_test_filter2win unit_test_fifo_double;
rehash path;
run_filter2win_package;
end

function restore(oldPath, oldFolder)
path(oldPath);
cd(oldFolder);
end