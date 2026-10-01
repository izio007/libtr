function unit_test_mapping_validity
setup_test_paths;
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
folder=tempname(fullfile(root,'runtime')); mkdir(folder);
r=struct('samples',[1 -1 100;0 0 100;0 0 100],'statuses',[0 0 0], ...
    'contract_violations',logical([0 0 1]),'valid',logical([1 1 0]));
r.metrics=service_ensemble_metrics(r.samples,[0 0 2],zeros(3,1));
assert(isequal(test_result_valid_mask(r),logical([1 1 0])));
bad=r; bad.valid(3)=true; rejects(bad);
bad=r; bad.metrics.successful=3; rejects(bad);
bad=r; bad.valid=double(bad.valid); rejects(bad);
bad=r; bad.valid=bad.valid.'; rejects(bad);
rejects(rmfield(r,'valid'));
for field={'samples','statuses','metrics','contract_violations'}
    rejects(rmfield(r,field{1}));
end
rejects([]); rejects([r r]);
bad=r; bad.samples={1}; rejects(bad);
bad=r; bad.samples=complex(r.samples,ones(size(r.samples))); rejects(bad);
bad=r; bad.statuses=[0 NaN 2]; rejects(bad);
bad=r; bad.statuses=[0 0.5 2]; rejects(bad);
bad=r; bad.metrics=[]; rejects(bad);
bad=r; bad.metrics=struct; rejects(bad);
bad=r; bad.metrics.successful='2'; rejects(bad);
% Synthetic records exercise rendering, not estimator acceptance.
r.contract_violations=false(1,3); r.statuses=[0 0 2];
r.truth=zeros(3,1); r.passed=true; r.point=1;
r.reference_status=0; r.reference_spectrum=diag([1 2 3]); r.reference_axes=eye(3);
methods={'lls_position','wlls_position','gn_position','gnp_position'};
records={}; posts=zeros(3,2);
for g=1:5
    save(fullfile(folder,sprintf('tis_inputs_%d_1.mat',g)),'posts');
    for m=1:4
        r.geometry=g; r.method=methods{m}; records{end+1}=r; %#ok<AGROW>
    end
end
summary=struct('failures',0); save(fullfile(folder,'tis_ensemble.mat'),'records','summary');
a=generate_tis_mapping_images(folder); b=generate_tis_spectral_images(folder);
assert(a.passed && b.execution_passed && numel(a.files)==5 && numel(b.files)==5);
fprintf('CLOUD-VALID-001/002 PASS, synthetic rendering only: %s\n',folder);
end
function rejects(r)
caught=false;
try
    test_result_valid_mask(r);
catch e
    caught=strcmp(e.identifier,'libtr:result:Validity');
end
assert(caught);
end