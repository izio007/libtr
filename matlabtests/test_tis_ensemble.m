function summary = test_tis_ensemble(folder,N,enforceAcceptance)
setup_test_paths;
% Five independent geometry families, persisted evidence before acceptance.
if nargin<2, N=64; end
if nargin<3, enforceAcceptance=true; end
validateattributes(N,{'double'},{'scalar','integer','>=',2});
state=rng; cleanup=onCleanup(@() rng(state)); rng(1729,'twister');
P=[-5000 5000 -5000 5000;-5000 -5000 5000 5000;0 0 0 0];
stations={P,P,P(:,1:2),P,repmat(P,1,4)};
targets={[-2000 0 2000;1000 -1000 2000;1000 3000 6000], ...
    [10000 -30000 -180000 160000;15000 15000 -15000 -15000;3000 3000 3000 3000], ...
    [0 30000 160000;15000 15000 15000;3000 3000 3000], ...
    [1000 30000 160000;15000 15000 15000;0 0 0], ...
    [1000 30000 160000;15000 15000 15000;3000 3000 3000]};
methods={@lls_position,@wlls_position,@gn_position,@gnp_position};
sigma=0.015*pi/180; records={}; failures=0;
for g=1:5
    posts=stations{g}; M=size(posts,2); variance=repmat(sigma^2,M,1);
    fig=figure('Visible','off'); closer=onCleanup(@() close(fig));
    tiledlayout(fig,2,2);
    for m=1:4
        ax=nexttile; hold(ax,'on'); grid(ax,'on');
        view(ax,3);
        title(ax,sprintf('%s, geometry %d',func2str(methods{m}),g),'Interpreter','none');
        xlabel(ax,'East error (m)'); ylabel(ax,'North error (m)'); zlabel(ax,'Up error (m)');
    end
    % Reuse measurements, never another method's estimates.
    for t=1:size(targets{g},2)
        truth=targets{g}(:,t); d=truth-posts;
        a=atan2(d(2,:),d(1,:)).'; b=atan2(d(3,:),hypot(d(1,:),d(2,:))).';
        aa=a+sigma*randn(M,N); bb=b+sigma*randn(M,N);
        [sm,xmock]=mock_position(posts,a,b,variance,variance);
        [sk,Kref,Vref,Sref]=mock_covariance(posts,a,b,variance,variance,truth);
        for m=1:4
            r=service_run_ensemble(methods{m},posts,aa,bb,variance,variance,truth);
            r.geometry=g; r.point=t; r.method=func2str(methods{m});
            r.truth=truth; r.mock_status=sm; r.mock_delta=norm(xmock-truth);
            r.reference_status=sk; r.reference_covariance=Kref;
            r.reference_axes=Vref; r.reference_spectrum=Sref;
            r.observations_per_trial=M;
            r.physical_posts=size(unique(posts.','rows'),1);
            r.passed=sm==0 && sk==0 && all(isfinite(Kref(:))) && ...
                r.mock_delta<1e-3 && r.metrics.failure_fraction==0 && ~any(r.contract_violations);
            try
                mm=r.metrics;
                assert(mm.successful>=2 && all(isfinite(mm.covariance(:))));
                V=mm.axes; S=diag(mm.eigenvalues);
                [s,reconstructed]=matmul3(V,S,V.');
                expected=zeros(3);
                for i=1:3
                    for j=1:3
                        for k=1:3
                            expected(i,j)=expected(i,j)+V(i,k)*S(k,k)*V(j,k);
                        end
                    end
                end
                tol=1e-10*max(1,norm(mm.covariance,'fro'));
                assert(s==0 && norm(reconstructed-expected,'fro')<=tol);
                assert(norm(reconstructed-mm.covariance,'fro')<=tol);
                assert(norm(V.'*V-eye(3),'fro')<1e-10);
                identity=norm(mm.bias)^2+(mm.successful-1)/mm.successful*trace(mm.covariance);
                assert(abs(mm.rmse^2-identity)<=1e-10*max(1,identity));
            catch exception
                r.passed=false; r.validation_error=exception.message;
            end
            failures=failures+~r.passed; records{end+1}=r; %#ok<AGROW>
            ax=nexttile(m); cloud=r.samples-truth;
            scatter3(ax,cloud(1,:),cloud(2,:),cloud(3,:),8,'.');
            mu=r.metrics.bias;
            plot3(ax,mu(1),mu(2),mu(3),'kx','MarkerSize',10);
            for k=1:3
                v=r.metrics.axes(:,k)*r.metrics.semiaxes(k);
                ends=[mu-v mu+v];
                plot3(ax,ends(1,:),ends(2,:),ends(3,:),'k-');
            end
        end
        save(fullfile(folder,sprintf('tis_inputs_%d_%d.mat',g,t)), ...
            'posts','truth','aa','bb','variance');
        fprintf('Geometry %d point %d: %d trials per method complete\n',g,t,N);
        drawnow;
    end
    exportgraphics(fig,fullfile(folder,sprintf('tis_geometry_%d.png',g)));
    clear closer;
end
summary=struct('records',numel(records),'failures',failures,'seed',1729, ...
    'ensemble_size',N,'geometries',5,'conditional_metrics',true);
save(fullfile(folder,'tis_ensemble.mat'),'records','summary');
service_pipeline_write_json(fullfile(folder,'tis_ensemble.json'),struct('summary',summary,'records',{records}));
if enforceAcceptance
    assert(failures==0,'libtr:test:Ensemble','%d ensemble cases failed; see tis_ensemble.json',failures);
end
end