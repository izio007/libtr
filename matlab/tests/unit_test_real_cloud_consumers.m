function unit_test_real_cloud_consumers
setup_test_paths;
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
folder=tempname(fullfile(root,'runtime')); mkdir(folder);
before=rng;
summary=test_tis_ensemble(folder,8,false);
assert(isequal(rng,before));
file=fullfile(folder,'tis_ensemble.mat'); original=bytes(file);
d=load(file);
assert(numel(d.records)==64 && summary.records==64);
for k=1:numel(d.records)
    test_result_valid_mask(d.records{k});
end
assert(summary.failures==sum(cellfun(@(r) ~r.passed,d.records)));
spectral=generate_tis_spectral_images(folder);
assert(spectral.execution_passed && spectral.acceptance_passed==(summary.failures==0));
assert(numel(spectral.files)==5);
if summary.failures==0
    mapping=generate_tis_mapping_images(folder);
    assert(mapping.passed && numel(mapping.files)==5);
else
    caught=false;
    try
        generate_tis_mapping_images(folder);
    catch e
        caught=strcmp(e.identifier,'libtr:mapping:Prerequisite');
    end
    assert(caught);
end
assert(isequal(original,bytes(file)));
fprintf('CLOUD-VALID-003 PASS; mathematical failed records=%d/64; %s\n', ...
    summary.failures,folder);
end
function data=bytes(file)
fid=fopen(file,'rb'); assert(fid>=0); cleanup=onCleanup(@() fclose(fid));
data=fread(fid,Inf,'*uint8');
end