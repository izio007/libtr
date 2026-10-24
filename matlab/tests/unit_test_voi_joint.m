function status = unit_test_voi_joint()
%UNIT_TEST_VOI_JOINT Independent ideal 3-D curve, OINO provenance, C2 hold.
% Run explicitly with MATLAB Desktop / existing run_tests('unit').
% This test is provided but has NOT been executed by the installer.
status=1;
cfg=struct('R0',1000,'Lmin',1,'kappa_max',1e12, ...
    'residual_max',Inf,'time_start',0,'time_end',240,'age_max',Inf, ...
    'capacity',64,'allow_geometric_fallback',false, ...
    'max_iters',30,'max_backtracks',18,'step_tol',1e-9, ...
    'cost_rel_tol',1e-13,'H',12);
X=[900;100;70];
times=[0;11;30;55;80;130;180;240];
n=numel(times);
bearings=repmat(struct('t_obs',0,'a',0,'b',0, ...
    'origin',zeros(3,1),'C',eye(3)),1,n);
O=zeros(3,n);C=zeros(3,3,n);a=zeros(n,1);b=zeros(n,1);
for i=1:n
    t=times(i);
    origin=[90*cos(.03*t);75*sin(.04*t);20*sin(.02*t)];
    angle=.11*sin(t/20);
    Q=[cos(angle),-sin(angle),0;sin(angle),cos(angle),0;0,0,1];
    v=Q'*(X-origin)/norm(X-origin);
    expect(v(1)>0,'forward bearing on a curved path');
    a(i)=asin(v(2)); b(i)=asin(v(3));
    bearings(i).t_obs=t;
    bearings(i).a=a(i);
    bearings(i).b=b(i);
    bearings(i).origin=origin;
    bearings(i).C=Q;
    O(:,i)=origin;C(:,:,i)=Q;
end
sig=.005;
idx=(0:2*n-1);
Sigma=sig^2*toeplitz(0.15.^idx);

% First tick must report a prior (not a measured range) and clamped cubic.
[rc,first]=voi_joint_snapshot(cfg,0,bearings(1),Sigma(1:2,1:2));
expect(rc==0 && first.basis==1 && first.available,'first observation');
expect(~first.observed && strcmp(first.quality,'HYPOTHESIS'), ...
    'not an invented range');
near(first.point,O(:,1)+cfg.R0*unit(X-O(:,1)),1e-10,'prior');
near(first.coeff(:,2:4),zeros(3,3),0,'clamped first model');

% Independent geometric truth: a constant target observed on a 3-D curve.
[accepted,p,report]=voi_joint_position(times,a,b,O,C,Sigma,cfg);
expect(accepted==1 && strcmp(report.reason,'OK'), ...
    'joint angular GLS available');
near(p,X,2e-5,'exact 3D point');
expect(norm(report.K_local-report.K_local','fro')<1e-8, ...
    'local covariance symmetry');
expect(all(eig(report.K_local)>0),'positive local covariance');

% Multiplying a covariance by 4 cannot improve its local information.
[accepted,p4,report4]=voi_joint_position(times,a,b,O,C,4*Sigma,cfg);
expect(accepted==1,'same geometry with enlarged covariance');
near(p4,p,2e-5,'same noiseless target');
near(report4.K_local,4*report.K_local, ...
    max(1,norm(report.K_local,'fro'))*1e-7,'covariance scaling');

[rc,final]=voi_joint_snapshot(cfg,240,bearings,Sigma);
expect(rc==0 && final.basis==2 && final.observed && ...
    final.finalized,'final weighted coordinate model');
near(final.point,X,2e-5,'final position');
near(final.coeff(:,2:4),zeros(3,3),0,'stationary clamped cubic');

% Full physical loss of range observability despite multiple time samples.
bad=bearings(1);
bad(2)=bad(1);
bad(2).t_obs=4;
[rc,degenerate]=voi_joint_snapshot(cfg,5,bad,eye(4)*sig^2);
expect(rc==0 && degenerate.basis==1 && ~degenerate.observed, ...
    'repeated pose cannot create a baseline');

% Non-SPD covariance cannot be disguised as a meaningful error estimate.
[rc,refused]=voi_joint_snapshot(cfg,240,bearings,zeros(2*n));
expect(rc==0 && refused.basis==1 && ...
    strcmp(refused.status,'FINAL_APRIORI'), ...
    'invalid covariance never claimed weighted');

% The correction begins at the old point, with no artificial jump.
context=struct();
[rc,context,step0]=voi_joint_step(cfg,context,0,bearings(1),Sigma(1:2,1:2));
expect(rc==0 && step0.correction.ready,'correction initialized');
[rc,context,step1]=voi_joint_step(cfg,context,11,bearings(1:2),Sigma(1:4,1:4));
expect(rc==0 && step1.basis==2 && step1.correction.ready, ...
    'refined target accepted');
near(step1.correction.position,step0.point,1e-9, ...
    'no jump when the correction is replanned');
old_point=step1.point;
[rc,context,step2]=voi_joint_step(cfg,context,12,bearings(1:2),zeros(4));
expect(rc==0 && step2.basis==2 && ...
    strcmp(step2.status,'HOLD_LAST_OBSERVED'), ...
    'bad covariance preserves accepted estimate');
near(step2.point,old_point,0,'no fallback to R0');
[rc,~,after_gap]=voi_joint_step(cfg,context,13,bearings(1:2),zeros(4));
expect(rc==0 && after_gap.correction.ready,'hold correction continues');

% OINO functionals from shared samples must retain cross-window covariance.
raw=struct();
raw.sample_id=(1:12)';
raw.t_obs=kron((0:5)',ones(2,1));
raw.y=zeros(12,1);
raw.y(1:2:12)=-.20+.01*(0:5)';
raw.y(2:2:12)=-.15+.02*(0:5)';
raw.Sigma=.01^2*toeplitz(.2.^(0:11));
windows=repmat(struct('t_target',0,'origin',zeros(3,1), ...
    'C',eye(3),'a',struct(),'b',struct()),1,2);
for i=1:2
    ta=1.5+2*(i-1);
    windows(i).t_target=ta;
    windows(i).origin=[50*i;5;0];
    if i==1
        ia=[1;3;5;7]; ib=[2;4;6;8];
    else
        ia=[5;7;9;11]; ib=[6;8;10;12];
    end
    windows(i).a=build_window(ia,raw.t_obs,ta);
    windows(i).b=build_window(ib,raw.t_obs,ta);
end
[rc,prepared]=voi_oino_prepare(raw,windows,1e9,false);
expect(rc==0 && prepared.available && prepared.count==2, ...
    'OINO preparation with shared raw observations');
near(prepared.bearings(1).a,-.185,2e-12,'prepared a at 1.5');
near(prepared.bearings(1).b,-.12,2e-12,'prepared b at 1.5');
near(prepared.Sigma,prepared.weights'*raw.Sigma*prepared.weights, ...
    1e-12,'joint covariance by common raw weights');
expect(abs(prepared.Sigma(1,3))>0, ...
    'nonzero cross-window covariance kept');

status=0;
end

function w=build_window(indices,times,t_target)
t=times(indices);
w=struct('idx',indices,'F',[ones(numel(indices),1),t], ...
    'G',zeros(numel(indices),0),'L',[1;t_target]);
end
function v=unit(v)
v=v/norm(v);
end
function expect(pred,name)
if ~isscalar(pred) || ~pred
    error('voi:joint:test','%s',name);
end
end
function near(a,b,tol,name)
if ~isequal(size(a),size(b)) || any(~isfinite(a(:))) || ...
        any(~isfinite(b(:))) || max(abs(a(:)-b(:)))>tol
    error('voi:joint:test_numeric','%s',name);
end
end
