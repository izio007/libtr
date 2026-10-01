function unit_test_gpu_environment
% Explicit hardware check through the existing TCP unit endpoint.
info=struct('pid',feature('getpid'),'matlab',version,'state','NOT_RUN');
try
    d=gpuDevice;
    info.name=d.Name; info.memory=d.TotalMemory;
    x=gpuArray(double([1 2 3]));
    assert(isequal(gather(x.*x),[1 4 9]));
    wait(d); info.state='PASS';
catch err
    info.state='FAILED'; info.error=err.message;
    service_pipeline_write_json(fullfile(pwd,'gpu_environment.json'),info);
    rethrow(err);
end
service_pipeline_write_json(fullfile(pwd,'gpu_environment.json'),info);
disp(info);
end