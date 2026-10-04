function unit_test_filter2win_isolation
% Execute the merged source closure outside libtr, on the existing host.
% The copied inputs and calculated evidence remain in the pipeline job folder.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
spec=jsondecode(fileread(fullfile(root,'matlab','tests','configs','filter2win_isolation.json')));
folder=pwd; oldpath=path;
cleanup=onCleanup(@() restore(folder,oldpath));
package=fullfile(folder,'isolated_filter2win');
assert(~isfolder(package),'libtr:f2w:Isolation','Refusing to overwrite an existing copy');
mkdir(package);
for k=1:numel(spec.files)
    target=fullfile(package,spec.files{k});
    parent=fileparts(target);
    if ~isfolder(parent), mkdir(parent); end
    copyfile(fullfile(root,spec.files{k}),target);
end
restoredefaultpath;
entries=strsplit(path,pathsep);
for k=1:numel(entries)
    if ~startsWith(lower(entries{k}),lower([matlabroot filesep]))
        rmpath(entries{k});
    end
end
cd(package);
addpath(fullfile(package,'matlab','function'),fullfile(package,'matlab','tests'), ...
    fullfile(package,'matlab','tests','support'));
rehash path;
resolved=struct();
for k=1:numel(spec.files)
    [~,name,extension]=fileparts(spec.files{k});
    if strcmp(extension,'.m')
        actual=which(name);
        assert(strcmpi(actual,fullfile(package,spec.files{k})), ...
            'libtr:f2w:Isolation','Unexpected resolution: %s',actual);
        assert(numel(which(name,'-all'))==1,'libtr:f2w:Isolation','Duplicate function: %s',name);
        resolved.(name)=actual;
    end
end
for k=1:numel(spec.forbidden_functions)
    assert(isempty(which(spec.forbidden_functions{k})),'libtr:f2w:Isolation','External dependency visible');
end
for k=1:numel(spec.checks)
    feval(spec.checks{k});
end
for k=1:numel(spec.artifacts)
    info=dir(fullfile(package,spec.artifacts{k}));
    assert(~isempty(info) && info.bytes>0,'libtr:f2w:Isolation','Missing artifact');
end
actual_path=path; actual_cwd=pwd; host_pid=feature('getpid');
save(fullfile(folder,'filter2win_isolation.mat'),'resolved','actual_path','actual_cwd','host_pid','spec');
end

function restore(folder,oldpath)
cd(folder);
path(oldpath);
end