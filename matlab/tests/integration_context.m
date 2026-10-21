function result = integration_context(folder,showFigures,indices)
% Full configured TIS trajectories and central-point ensembles, no unit calls.
setup_test_paths;
if nargin<2, showFigures=false; end
scenarios=tis_trajectory_scenarios;
if nargin<3, indices=1:numel(scenarios); end
validateattributes(indices,{'double'},{'vector','integer','positive','<=',numel(scenarios)});
if ~isfolder(folder), mkdir(folder); end
scenarios=scenarios(indices);
for k=1:numel(scenarios)
    cfg=scenarios{k};
    save(fullfile(folder,tis_context_filename(cfg)),'cfg');
end
result=generate_context_test_images(folder,folder,showFigures,scenarios);
assert(result.failures==0,'libtr:integration:Context', ...
    '%d TIS trajectory cases failed; see context_images.json',result.failures);
end
