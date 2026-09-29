function report=run_service_relocation_checks(folder)
% Focused relocation checks; no whole-library or document export pipeline.
assert(~isfolder(folder),'Choose a new result directory');
mkdir(folder);
previous=path; cleanup=onCleanup(@() path(previous));
setup_test_paths;
tests={'unit_test_production_isolation','unit_test_engine_isolation', ...
    'unit_test_ensemble_metrics','unit_test_integration_independence', ...
    'unit_test_graphical_experiments','unit_test_pipeline', ...
    'unit_test_document_profile','unit_test_mock_position','unit_test_mock_covariance'};
results=cell(size(tests));
for k=1:numel(tests)
    item=struct('name',tests{k},'passed',false,'error','');
    output='';
    try
        output=evalc('feval(tests{k});');
        item.passed=true;
    catch exception
        item.error=getReport(exception,'extended','hyperlinks','off');
    end
    fid=fopen(fullfile(folder,[tests{k} '.log']),'w','n','UTF-8');
    assert(fid~=-1); fprintf(fid,'%s\n%s',output,item.error); fclose(fid);
    results{k}=item;
end
report=struct('passed',all(cellfun(@(x)x.passed,results)),'tests',{results});
service_pipeline_write_json(fullfile(folder,'report.json'),report);
assert(report.passed,'libtr:relocation:Failed','Inspect relocation report');
end