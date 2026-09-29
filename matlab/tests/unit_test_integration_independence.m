function unit_test_integration_independence
setup_test_paths;
% Regression: truth is for scoring only; WLLS weights use preliminary LLS.
P=[-5000 5000 -4000 6000;-3000 -2000 4000 5000;0 100 200 300];
x=[1200;160000;3000]; d=x-P;
a=atan2(d(2,:),d(1,:)).'+[.002;-.001;.003;-.002];
b=atan2(d(3,:),hypot(d(1,:),d(2,:))).'+[.001;.002;-.001;-.002];
va=[1;2;3;4]*1e-5; vb=flipud(va);
H=zeros(8,3); z=zeros(8,1);
for i=1:4
    rows=[sin(a(i)) -cos(a(i)) 0; ...
        -cos(a(i))*sin(b(i)) -sin(a(i))*sin(b(i)) cos(b(i))];
    H(2*i-1:2*i,:)=rows; z(2*i-1:2*i)=rows*P(:,i);
end
% Independent rectangular least-squares reference, not lls_position output.
initial=H\z;
rho=sqrt(sum((initial-P).^2,1)).';
weights=zeros(8,1); weights(1:2:end)=1./(sqrt(va).*rho);
weights(2:2:end)=1./(sqrt(vb).*rho);
reference=(H.*weights)\(z.*weights);
[s,estimate]=wlls_position(P,a,b,va,vb);
assert(s==0 && norm(estimate-reference)<1e-8*max(1,norm(reference)));
methods={@lls_position,@wlls_position,@gn_position,@gnp_position};
for k=1:4
    first=service_run_ensemble(methods{k},P,[a a],[b b],va,vb,x);
    second=service_run_ensemble(methods{k},P,[a a],[b b],va,vb,x+[100;200;300]);
    assert(~any(first.contract_violations) && ~any(second.contract_violations));
    assert(isequaln(first.samples,second.samples) && isequaln(first.statuses,second.statuses));
end
% Shifted, rotated anisotropic cloud: covariance must not include Bias.
Q=[cos(.4) -sin(.4) 0;sin(.4) cos(.4) 0;0 0 1];
D=diag([2 5 9]); mu=[100;200;300];
cloud=mu+Q*D*[eye(3) -eye(3)];
m=service_ensemble_metrics(cloud,zeros(1,6),zeros(3,1));
K=2/5*Q*D^2*Q.';
assert(norm(m.bias-mu)<1e-12 && norm(m.covariance-K,'fro')<1e-11);
assert(norm(m.axes*diag(m.semiaxes.^2)*m.axes.'-K,'fro')<1e-11);
directions=[cos(m.theta).*cos(m.psi);cos(m.theta).*sin(m.psi);sin(m.theta)];
assert(norm(directions-m.axes,'fro')<1e-12);
assert(abs(m.rmse^2-(norm(mu)^2+5/6*trace(K)))<1e-8);
end