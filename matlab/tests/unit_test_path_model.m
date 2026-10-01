function unit_test_path_model
setup_test_paths;
clear test_model_result service_run_path;
saved=rng; cleanup=onCleanup(@() rng(saved));
scenarios=tis_trajectory_scenarios;
for c=1:numel(scenarios)
    cfg=scenarios{c}; p=linspace(0,1,7);
    truth=[cfg.Trajectory.X_limits(1)+diff(cfg.Trajectory.X_limits)*p; ...
        cfg.Trajectory.Y_center_true*ones(size(p)); ...
        cfg.Trajectory.Z_base+cfg.Trajectory.Z_amplitude*sin(pi*p)];
    P=[cfg.Stations.X_anchors;cfg.Stations.Y_anchors;cfg.Stations.Z_anchors];
    sigma=cfg.Hardware.D_Error_Degree*pi/180; v=ones(4,1)*sigma^2;
    a=zeros(4,7); b=a;
    for k=1:4
        d=truth-P(:,k); a(k,:)=atan2(d(2,:),d(1,:));
        b(k,:)=atan2(d(3,:),hypot(d(1,:),d(2,:)));
    end
    rng(cfg.Hardware.Random_Seed,'twister');
    a=a+sigma*randn(size(a)); b=b+sigma*randn(size(b));
    for name=cfg.Methods.Solvers
        solver=str2func(name{1}); x=NaN(3,7); status=NaN(1,7);
        for k=1:7, [status(k),x(:,k)]=solver(P,a(:,k),b(:,k),v,v); end
        r=service_run_path(solver,p,P,a,b,v,v,truth);
        assert(isequaln(x,r.samples) && isequaln(status,r.statuses));
        assert(isequal(r.parameter,p) && ~isfield(r,'time'));
        assert(~any(r.contract_violations));
    end
end
r=service_run_path(@refuse,p,P,a,b,v,v,truth);
assert(r.metrics.failure_fraction==1 && isnan(r.metrics.rmse));
try
    service_run_path(@refuse,zeros(size(p)),P,a,b,v,v,truth);
    error('libtr:test:MissingValidation','Parameter accepted');
catch e
    assert(~strcmp(e.identifier,'libtr:test:MissingValidation'));
end
unit_test_filter_model;
fprintf('Geometric path: near/far, four methods, refusal and lifecycle regressions PASS\n');
end
function [s,x]=refuse(varargin)
s=2; x=NaN(3,1);
end