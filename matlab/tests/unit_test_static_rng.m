function unit_test_static_rng
setup_test_paths;
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
before=rng; cleanup=onCleanup(@() rng(before));
folder=tempname(fullfile(root,'runtime'));
report=generate_tis_static_passport(folder,2,[1 2],30000,'A');
assert(isequal(rng,before));
assert(numel(report.files)==4);
previous=engine_rng_init(1337);
rng(1337,'twister');
for repeat=[1 2]
    d=load(fullfile(folder,sprintf('repeat_%d.mat',repeat)));
    assert(isequal(d.initial,previous)); previous=d.next;
    delta=d.truth-d.P;
    a=atan2(delta(2,:),delta(1,:)).';
    b=atan2(delta(3,:),hypot(delta(1,:),delta(2,:))).';
    expectedA=a+d.sigma*randn(size(d.P,2),2);
    expectedB=b+d.sigma*randn(size(d.P,2),2);
    assert(isequal(d.alpha,expectedA) && isequal(d.beta,expectedB));
    for m=1:numel(d.results)
        valid=test_result_valid_mask(d.results{m});
        assert(sum(valid)==d.record.successful(m));
    end
end
for k=1:numel(report.files)
    image=imread(fullfile(folder,report.files{k})); assert(~isempty(image));
end
fprintf('STATIC-RNG-001/002 PASS; %s\n',folder);
end