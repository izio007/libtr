function report = run_mock_traceability(folder)
setup_test_paths;
% Standalone mock traceability runner; no estimator implementation is duplicated.
root=fileparts(fileparts(mfilename('fullpath')));
if nargin==0
    folder=tempname(fullfile(root,'runtime'));
end
assert(~isfolder(folder),'libtr:trace:Exists','Use a new output folder');
mkdir(folder);
previous=path; cleanup=onCleanup(@() path(previous));
addpath(fullfile(root,'matlab'),fullfile(root,'matlab','engine'));
tests={'unit_test_mock_position','unit_test_mock_covariance'};
sections={'1.2: ray/projector equations and ideal position', ...
    '2.2, 2.3, 3: gradients, Fisher, spectrum, zenith'};
results=cell(1,2);
for k=1:2
    item=struct('test',tests{k},'scope',sections{k},'passed',false,'error','');
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
report=struct('tests',{results},'passed',all(cellfun(@(r) r.passed,results)), ...
    'complete_contract_coverage',false,'source','docs/mock_theory.md', ...
    'limitations',{{'Status 1 and invalid-input domain are not fully specified in TXT.', ...
    'Bias evidence belongs to Monte Carlo experiments, not ideal mock.', ...
    'Historical research statements are not current acceptance evidence.'}});
% Flat covariance call, followed by a visualization of its actual eigenvectors.
P=[-20000 20000 0 0;0 0 -20000 20000;200 200 200 200];
truth=[0;160000;10000]; d=truth-P;
a=atan2(d(2,:),d(1,:)).'; b=atan2(d(3,:),hypot(d(1,:),d(2,:))).';
variance=ones(4,1)*(pi/180)^2;
[status,K,V,S]=mock_covariance(P,a,b,variance,variance,truth);
report.geometry_status=status;
report.passed=report.passed && status==0;
if status==0
    [sx,sy,sz]=sphere(32);
    ellipsoid=V*diag(sqrt(diag(S)))*[sx(:).';sy(:).';sz(:).'];
    fig=figure('Visible','off'); closer=onCleanup(@() close(fig));
    surf(reshape(ellipsoid(1,:),size(sx)),reshape(ellipsoid(2,:),size(sy)), ...
        reshape(ellipsoid(3,:),size(sz)),'EdgeColor','none');
    axis equal; grid on; xlabel('Delta X (m)'); ylabel('Delta Y (m)'); zlabel('Delta Z (m)');
    title('Mock covariance: one-standard-deviation ellipsoid about truth');
    exportgraphics(fig,fullfile(folder,'mock_spectrum.png')); clear closer;
end
save(fullfile(folder,'mock_traceability.mat'),'P','truth','a','b','variance','status','K','V','S');
service_pipeline_write_json(fullfile(folder,'report.json'),report);
disp(report);
assert(report.passed,'libtr:trace:Failed','Traceability checks failed; inspect report.json');
end