function report=generate_tis_spectral_images(folder)
setup_test_paths;
% Compare saved empirical clouds and independent truth-based Fisher references.
data=load(fullfile(folder,'tis_ensemble.mat'),'records','summary');
methods={'lls_position','wlls_position','gn_position','gnp_position'};
files=cell(1,5); comparisons={};
for g=1:5
    fig=figure('Visible','off','Position',[30 30 1600 1100]);
    cleanup=onCleanup(@() close(fig)); tiledlayout(fig,4,4);
    for m=1:4
        selected=cellfun(@(r) r.geometry==g && strcmp(r.method,methods{m}),data.records);
        records=data.records(selected);
        for panel=1:4
            ax(panel)=nexttile((m-1)*4+panel); %#ok<AGROW>
            hold(ax(panel),'on'); grid(ax(panel),'on');
        end
        view(ax(1),3);
        title(ax(1),methods{m},'Interpreter','none');
        xlabel(ax(1),'East error (m)'); ylabel(ax(1),'North error (m)'); zlabel(ax(1),'Up error (m)');
        title(ax(2),'Semiaxes: empirical / Fisher'); ylabel(ax(2),'Length (m)');
        title(ax(3),'Azimuth: sign-aligned axes'); ylabel(ax(3),'Degrees');
        title(ax(4),'Elevation: sign-aligned axes'); ylabel(ax(4),'Degrees');
        colors=lines(3);
        for t=1:numel(records)
            r=records{t}; valid=test_result_valid_mask(r);
            assert(sum(valid)==r.metrics.successful);
            cloud=r.samples(:,valid)-r.truth;
            scatter3(ax(1),cloud(1,:),cloud(2,:),cloud(3,:),2,'.','HandleVisibility','off');
            plot3(ax(1),0,0,0,'rx','HandleVisibility','off');
            if r.metrics.successful<2 || r.reference_status~=0, continue; end
            [se,ie]=sort(r.metrics.eigenvalues,'descend');
            [sr,ir]=sort(diag(r.reference_spectrum),'descend');
            if any(se<0) || any(sr<0), continue; end
            Ve=r.metrics.axes(:,ie); Vr=r.reference_axes(:,ir);
            % Eigenvector signs are arbitrary; align before angle comparison.
            for j=1:3
                if dot(Ve(:,j),Vr(:,j))<0, Ve(:,j)=-Ve(:,j); end
            end
            pe=atan2d(Ve(2,:),Ve(1,:)); pr=atan2d(Vr(2,:),Vr(1,:));
            te=atan2d(Ve(3,:),hypot(Ve(1,:),Ve(2,:)));
            tr=atan2d(Vr(3,:),hypot(Vr(1,:),Vr(2,:)));
            % Repeated eigenvalues identify a subspace, not unique directions.
            gapsE=abs(diff(se)); gapsR=abs(diff(sr));
            ambiguous=false(1,3);
            for j=1:2
                if gapsE(j)<=1e-10*max(se) || gapsR(j)<=1e-10*max(sr)
                    ambiguous(j:j+1)=true;
                end
            end
            pe(ambiguous)=NaN; pr(ambiguous)=NaN;
            te(ambiguous)=NaN; tr(ambiguous)=NaN;
            comparisons{end+1}=struct('geometry',g,'point',r.point,'method',r.method, ...
                'empirical_semiaxes',sqrt(se),'reference_semiaxes',sqrt(sr), ...
                'empirical_psi',pe,'reference_psi',pr,'empirical_theta',te, ...
                'reference_theta',tr,'ambiguous_axes',ambiguous, ...
                'failure_fraction',r.metrics.failure_fraction); %#ok<AGROW>
            for j=1:3
                e=r.metrics.bias+[-1 1].*(Ve(:,j)*sqrt(se(j)));
                ref=[-1 1].*(Vr(:,j)*sqrt(sr(j)));
                plot3(ax(1),e(1,:),e(2,:),e(3,:),'-','Color',colors(j,:),'HandleVisibility','off');
                plot3(ax(1),ref(1,:),ref(2,:),ref(3,:),'--','Color',colors(j,:),'HandleVisibility','off');
                plot(ax(2),t,sqrt(se(j)),'o','Color',colors(j,:));
                plot(ax(2),t,sqrt(sr(j)),'x','Color',colors(j,:));
                plot(ax(3),t,pe(j),'o','Color',colors(j,:)); plot(ax(3),t,pr(j),'x','Color',colors(j,:));
                plot(ax(4),t,te(j),'o','Color',colors(j,:)); plot(ax(4),t,tr(j),'x','Color',colors(j,:));
            end
        end
        for panel=2:4, xlabel(ax(panel),'Trajectory sample'); end
    end
    sgtitle(sprintf('Family %d; conditional on success; o empirical, x Fisher; axes sorted by variance',g));
    assert(numel(findall(fig,'Type','axes'))==16);
    files{g}=sprintf('tis_spectrum_%d.png',g);
    exportgraphics(fig,fullfile(folder,files{g})); clear cleanup;
    image=imread(fullfile(folder,files{g})); assert(~isempty(image));
end
report=struct('execution_passed',true,'acceptance_passed',data.summary.failures==0, ...
    'files',{files},'comparisons',{comparisons});
service_pipeline_write_json(fullfile(folder,'spectral_images.json'),report);
end