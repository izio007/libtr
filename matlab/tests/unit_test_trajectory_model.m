function unit_test_trajectory_model
setup_test_paths;
clear test_model_step test_model_result test_trajectory_init;
time=[0 0.2 1.7];
truth=[2 3 4;3 4 5;4 5 6];
P0=[-10 10 0 0;0 0 -10 10;0 0 0 0];
P=repmat(P0,1,1,3); P(:,:,2)=P0+1; P(:,:,3)=P0+2;
a=zeros(4,3); b=a; v=ones(4,1)*1e-6;
for j=1:3
    d=truth(:,j)-P(:,:,j);
    a(:,j)=atan2(d(2,:),d(1,:)).';
    b(:,j)=atan2(d(3,:),hypot(d(1,:),d(2,:))).';
end
for solver={@lls_position,@wlls_position,@gn_position,@gnp_position}
    m=test_trajectory_init(solver{1},time,P,a,b,v,v,truth);
    assert(isnan(m.current_time)); other=m;
    reject(@() test_model_result(m),'libtr:testmodel:Incomplete');
    for j=1:3
        m=test_model_step(m);
        assert(m.current_time==time(j) && other.cursor==0);
        [s,x]=solver{1}(P(:,:,j),a(:,j),b(:,j),v,v);
        assert(m.result.statuses(j)==s && isequaln(m.result.samples(:,j),x));
    end
    r=test_model_result(m);
    assert(max(abs(r.samples(:)-truth(:)))<1e-8);
    assert(r.metrics.rmse<1e-8 && strcmp(r.metrics.scope,'conditional_trajectory_error'));
    c=test_trajectory_init(solver{1},time,P0,a,b,v,v,truth);
    d=test_trajectory_init(solver{1},time,repmat(P0,1,1,3),a,b,v,v,truth);
    for j=1:3, c=test_model_step(c); d=test_model_step(d); end
    assert(isequaln(test_model_result(c),test_model_result(d)));
end
for bad={[0 0 1],[0 NaN 2],[2 1 0]}
    reject(@() test_trajectory_init(@lls_position,bad{1},P,a,b,v,v,truth),'libtr:testmodel:Time');
end
reject(@() test_trajectory_init(@lls_position,time,P,a,b,v,v,truth(:,1)), ...
    'libtr:testmodel:Truth');
m=test_trajectory_init(@refuse,time,P,a,b,v,v,truth);
m=test_model_step(m); copy=m;
for j=2:3, m=test_model_step(m); copy=test_model_step(copy); end
r=test_model_result(m);
assert(isequaln(r,test_model_result(copy)) && r.metrics.failure_fraction==1);
assert(isnan(r.metrics.rmse) && ~any(r.contract_violations));
unit_test_model_lifecycle;
fprintf('Trajectory replay, four direct solver references and lifecycle: PASS\n');
end
function [s,x]=refuse(varargin)
s=2; x=NaN(3,1);
end
function reject(action,id)
try, action(); catch e, assert(strcmp(e.identifier,id)); return; end
error('libtr:test:MissingError','Expected %s',id);
end