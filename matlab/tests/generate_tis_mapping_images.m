function report = generate_tis_mapping_images(folder)
setup_test_paths;
% Plot saved Cartesian solutions, never recompute or fabricate estimates.
data=load(fullfile(folder,'tis_ensemble.mat'),'records','summary');
assert(data.summary.failures==0,'libtr:mapping:Prerequisite','Integration failed');
files=cell(1,5);
for g=1:5
    fig=figure('Visible','off','Position',[50 50 1200 900]);
    closer=onCleanup(@() close(fig)); tiledlayout(fig,2,2);
    methods={'lls_position','wlls_position','gn_position','gnp_position'};
    for m=1:4
        ax=nexttile; hold(ax,'on'); grid(ax,'on'); axis(ax,'equal');
        title(ax,methods{m},'Interpreter','none');
        xlabel(ax,'East (km)'); ylabel(ax,'North (km)');
        selected=cellfun(@(r) r.geometry==g && strcmp(r.method,methods{m}),data.records);
        records=data.records(selected); assert(~isempty(records));
        for k=1:numel(records)
            r=records{k};
            inputs=load(fullfile(folder,sprintf('tis_inputs_%d_%d.mat',g,r.point)),'posts');
            valid=test_result_valid_mask(r);
            assert(sum(valid)==r.metrics.successful && r.passed);
            scatter(ax,r.samples(1,valid)/1000,r.samples(2,valid)/1000,8,'.');
            plot(ax,r.truth(1)/1000,r.truth(2)/1000,'kx','MarkerSize',10);
            plot(ax,inputs.posts(1,:)/1000,inputs.posts(2,:)/1000,'kv','MarkerSize',7);
        end
    end
    sgtitle(sprintf('Geometry %d: actual Monte Carlo estimates, truth (x), posts (v)',g));
    assert(numel(findall(fig,'Type','axes'))==4);
    files{g}=sprintf('tis_map_%d.png',g);
    filename=fullfile(folder,files{g}); exportgraphics(fig,filename); clear closer;
    image=imread(filename); assert(~isempty(image) && size(image,1)>1 && size(image,2)>1);
end
report=struct('passed',true,'files',{files},'geometries',5, ...
    'source','tis_ensemble.mat','coordinate_units','km','projection','ENU XY');
service_pipeline_write_json(fullfile(folder,'mapping_images.json'),report);
end