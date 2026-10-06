function unit_test_filter_plot_path
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; state=rng; cleanup=onCleanup(@() restore(old,state));
restoredefaultpath;
addpath(fullfile(root,'matlab','tests'));
clear generate_filter2win_doc_images filter2win;
before=path; randomBefore=rng;
folder=fullfile(pwd,'filter_plot');
assert(~isfolder(folder),'libtr:f2w:Plot','Refusing to overwrite previous plot evidence');
generate_filter2win_doc_images(folder);
assert(strcmp(before,path) && isequal(randomBefore,rng));
for name={'filter2win_doc_data.mat','filter2win_trajectory.png', ...
        'filter2win_window.png','filter2win_image_metrics.txt'}
    file=dir(fullfile(folder,name{1}));
    assert(numel(file)==1 && file.bytes>0);
end
data=load(fullfile(folder,'filter2win_doc_data.mat'));
addpath(fullfile(root,'matlab','function'));
addpath(fullfile(root,'matlab','tests','support'));
[spec,cfg]=filter2win_observation_config;
assert(numel(data.t)==spec.expected_samples && any(isnan(data.measured)));
ctx=struct('X_MAIN_REF',spec.initial_reference);
actual=zeros(numel(data.t),1); power=actual;
for k=1:numel(data.t)
    [status,ctx]=filter2win(cfg,ctx,data.t(k),data.measured(k),isnan(data.measured(k)));
    assert(status==0);
    actual(k)=ctx.X_FILTERED_OUTPUT; power(k)=ctx.W_ALT_POWER_OUTPUT;
end
assert(isequaln(actual,data.filtered) && isequal(power,data.power));
fprintf('Filter plot clean path, state restoration and replay: PASS; %s\n',folder);
end

function restore(old,state)
path(old); rng(state);
end
