function unit_test_dynamic_rng
setup_test_paths;
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
before=rng; cleanup=onCleanup(@() rng(before));
base=tempname(fullfile(root,'runtime')); mkdir(base);
scenarios=tis_trajectory_scenarios; cfg=scenarios{1};
cfg.Trajectory.Points=2;
file=fullfile(base,'input.mat'); save(file,'cfg');
folder=fullfile(base,'output');
report=generate_tis_dynamic_passport(file,folder,2);
assert(isequal(rng,before));
previous=engine_rng_init(cfg.Hardware.Random_Seed);
rng(cfg.Hardware.Random_Seed,'twister');
for n=1:numel(report.counts)
    for k=1:2
        d=load(fullfile(folder,sprintf('cell_%d_%d.mat',n,k)));
        assert(isequal(d.initial,previous)); previous=d.next;
        delta=d.truth-d.P;
        a=atan2(delta(2,:),delta(1,:)).';
        b=atan2(delta(3,:),hypot(delta(1,:),delta(2,:))).';
        expectedA=a+d.sigma*randn(size(d.P,2),2);
        expectedB=b+d.sigma*randn(size(d.P,2),2);
        assert(isequal(d.alpha,expectedA) && isequal(d.beta,expectedB));
        for m=1:numel(d.results)
            r=d.results{m};
            expected=r.statuses==0 & all(isfinite(r.samples),1) & ~r.contract_violations;
            assert(isequal(r.valid,expected));
            assert(sum(r.valid)==r.metrics.successful);
            assert(sum(r.valid)==report.records{n,k}.successful(m));
        end
    end
end
assert(numel(report.files)==4);
for k=1:numel(report.files)
    image=imread(fullfile(folder,report.files{k})); assert(~isempty(image));
end
fprintf('DYNAMIC-RNG-001/002 and DYNAMIC-VALID-001 PASS; %s\n',folder);
end