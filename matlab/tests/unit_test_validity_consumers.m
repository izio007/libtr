function unit_test_validity_consumers
setup_test_paths;
clear tis_experiment_cell generate_context_test_images;
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=rng; cleanup=onCleanup(@() rng(old)); rng(812,'twister');
file=[tempname(fullfile(root,'runtime')) '.mat'];
truth=[1000;30000;3000];
record=tis_experiment_cell([-5000 5000 0 0;0 0 -5000 5000;0 0 0 0], ...
    truth,0.001,1,8,file);
d=load(file);
for k=1:numel(d.results)
    r=d.results{k};
    assert(record.successful(k)==sum(r.valid));
    assert(record.successful(k)==r.metrics.successful);
    if any(r.valid)
        e=r.samples(:,r.valid)-truth;
        assert(isequaln(record.axis_rmse(:,k),sqrt(mean(e.^2,2))));
        assert(isequaln(record.max_miss(k),max(sqrt(sum(e.^2,1)))));
    end
end
unit_test_result_validity;
unit_test_context_engine;
fprintf('Validity consumers and full reduced context generation PASS; %s\n',file);
end