function unit_test_context_engine
setup_test_paths;
clear generate_context_test_images service_run_path test_model_result;
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
folder=tempname(fullfile(root,'runtime')); mkdir(folder);
inputs=fullfile(folder,'inputs'); mkdir(inputs);
out=fullfile(folder,'output');
scenarios=tis_trajectory_scenarios;
for c=1:numel(scenarios)
    cfg=scenarios{c}; cfg.Trajectory.Points=7; cfg.Hardware.N_Monte_Carlo=8;
    save(fullfile(inputs,tis_context_filename(cfg)),'cfg');
end
before=rng;
summary=generate_context_test_images(inputs,out);
assert(isequal(before,rng));
assert(summary.png_count==10 && numel(summary.reports)==8);
failed=0;
for c=1:numel(scenarios)
    name=erase(erase(tis_context_filename(scenarios{c}),'context_'),'.mat');
    d=load(fullfile(out,['context_' name '_inputs.mat']));
    assert(numel(d.t)==7 && size(d.aa,2)==8);
    for method=scenarios{c}.Methods.Solvers
        r=load(fullfile(out,['context_' name '_' method{1} '.mat']));
        solver=str2func(method{1});
        for k=1:7
            [s,x]=solver(d.P,d.alpha(:,k),d.beta(:,k),d.variance,d.variance);
            assert(isequaln(s,r.statuses(k)) && isequaln(x,r.trajectory(:,k)));
        end
        for k=1:8
            [s,x]=solver(d.P,d.aa(:,k),d.bb(:,k),d.variance,d.variance);
            assert(isequaln(s,r.ensemble.statuses(k)) && isequaln(x,r.ensemble.samples(:,k)));
        end
        assert(isequaln(r.pathResult.samples,r.trajectory));
        assert(isequaln(r.pathResult.statuses,r.statuses));
        assert(isequal(r.pathResult.parameter,d.t) && ~isfield(r.pathResult,'time'));
        assert(~any(r.pathResult.contract_violations) && ~any(r.ensemble.contract_violations));
        failed=failed+~r.report.passed;
    end
end
assert(summary.failures==failed);
json=jsondecode(fileread(fullfile(out,'context_images.json')));
assert(json.png_count==10 && json.failures==failed);
for k=1:numel(summary.files)
    info=imfinfo(fullfile(out,summary.files{k}));
    assert(strcmpi(info.Format,'png') && info.Width>0 && info.Height>0);
end
fprintf('Context integration PASS; scenario failure reports=%d; artifacts: %s\n',failed,out);
end