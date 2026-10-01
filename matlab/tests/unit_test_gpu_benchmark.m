function unit_test_gpu_benchmark
old=rng; cleanup=onCleanup(@() rng(old)); rng(1729,'twister');
d=gpuDevice;
report=struct('device',d.Name,'memory',d.TotalMemory,'matlab',version, ...
    'pid',feature('getpid'),'precision','double','scope','bearing geometry only');
records=cell(1,4); sizes=[1000 10000 100000 1000000];
for k=1:numel(sizes)
    N=sizes(k); x=randn(3,N)*30000;
    reference=angles(x); g=gpuArray(x); y=gather(angles(g));
    assert(max(abs(y(:)-reference(:)))<=1e-12);
    transferred(x); wait(d);
    times=zeros(7,3);
    for j=1:7
        order=1:3; if mod(j,2)==0, order=3:-1:1; end
        for mode=order
            wait(d); t=tic;
            if mode==1
                y=angles(x);
            elseif mode==2
                y=transferred(x);
            else
                yg=angles(g); wait(d);
            end
            times(j,mode)=toc(t);
        end
    end
    y=gather(yg); error=max(abs(y(:)-reference(:)));
    med=median(times,1);
    records{k}=struct('N',N,'seconds',times,'median_seconds',med, ...
        'speedup_total',med(1)/med(2),'speedup_resident',med(1)/med(3), ...
        'max_error_rad',error);
    assert(error<=1e-12 && all(times(:)>0));
    fprintf('N=%d CPU=%.6g GPU_total=%.6g GPU_resident=%.6g speedup=%.3f resident=%.3f error=%.3g\n', ...
        N,med,med(1)/med(2),med(1)/med(3),error);
    clear g yg;
end
report.records=records;
service_pipeline_write_json(fullfile(pwd,'gpu_benchmark.json'),report);
end
function y=angles(x)
y=[atan2(x(2,:),x(1,:));atan2(x(3,:),hypot(x(1,:),x(2,:)))];
end
function y=transferred(x)
y=gather(angles(gpuArray(x)));
end