function unit_test_mock_covariance
% Independent geometric oracle for mock_theory sections 2 and 3.
P=[-10 10 0;0 0 10;0 0 0];
x=[2;3;8]; va=[1;2;3]*1e-6; vb=[3;2;1]*1e-6;
d=x-P; h=hypot(d(1,:),d(2,:)); r2=sum(d.^2,1);
a=atan2(d(2,:),d(1,:)).'; b=atan2(d(3,:),h).';
% Different assembly: stacked whitened Jacobian, not kernel accumulation.
J=zeros(6,3);
for i=1:3
    J(2*i-1,:)=[-d(2,i)/h(i)^2,d(1,i)/h(i)^2,0]/sqrt(va(i));
    J(2*i,:)=[-d(1,i)*d(3,i)/h(i), ...
        -d(2,i)*d(3,i)/h(i),h(i)]/r2(i)/sqrt(vb(i));
end
[status,K,V,S]=mock_covariance(P,a,b,va,vb,x);
assert(status==0 && all(isfinite(K(:))));
assert(norm((J.'*J)*K-eye(3),'fro')<1e-10);
assert(norm(K*V-V*S,'fro')/norm(K,'fro')<1e-12);
assert(norm(V.'*V-eye(3),'fro')<1e-12);
assert(norm(K-V*S*V.','fro')/norm(K,'fro')<1e-12);
assert(all(diag(S)>0));
% Section 2.3: angles reconstruct the selected representatives, not signs.
psi=atan2(V(2,:),V(1,:));
theta=atan2(V(3,:),hypot(V(1,:),V(2,:)));
directions=[cos(theta).*cos(psi);cos(theta).*sin(psi);sin(theta)];
assert(norm(directions-V,'fro')<1e-12);
axesLength=sqrt(diag(S));
assert(norm(V*diag(axesLength.^2)*V.'-K,'fro')/norm(K,'fro')<1e-12);
[shortStatus,shortK,shortV,shortS]=mock_covariance(P(:,1),a(1),b(1),va(1),vb(1),x);
assert(shortStatus==1 && all(isnan([shortK(:);shortV(:);shortS(:)])));
% Central differences of the measurement map: independent gradient check.
step=1e-4; Jfd=zeros(6,3);
for k=1:3
    delta=zeros(3,1); delta(k)=step;
    dp=x+delta-P; dm=x-delta-P;
    ap=atan2(dp(2,:),dp(1,:)); am=atan2(dm(2,:),dm(1,:));
    bp=atan2(dp(3,:),hypot(dp(1,:),dp(2,:)));
    bm=atan2(dm(3,:),hypot(dm(1,:),dm(2,:)));
    Jfd(1:2:end,k)=atan2(sin(ap-am),cos(ap-am)).'/(2*step)./sqrt(va);
    Jfd(2:2:end,k)=(bp-bm).'/(2*step)./sqrt(vb);
end
assert(norm(J-Jfd,'fro')/norm(J,'fro')<1e-7);
% Sign changes preserve the spectral reconstruction.
W=V*diag([-1 1 -1]);
assert(norm(K-W*S*W.','fro')/norm(K,'fro')<1e-12);
% Exact zenith is a contract failure, not a fabricated finite gradient.
for z=[0 8]
    [status,K,V,S]=mock_covariance(P,a,b,va,vb,[P(1:2,1);z]);
    assert(status==2 && all(isnan([K(:);V(:);S(:)])));
end
% Sub-millimetre nonzero horizontal distance: no clipping is permitted.
x=[P(1,1)+1e-4;P(2,1);8];
[status,K]=mock_covariance(P,a,b,va,vb,x);
assert(status==0);
d=x-P; h=hypot(d(1,:),d(2,:)); r2=sum(d.^2,1);
for i=1:3
    J(2*i-1,:)=[-d(2,i)/h(i)^2,d(1,i)/h(i)^2,0]/sqrt(va(i));
    J(2*i,:)=[-d(1,i)*d(3,i)/h(i), ...
        -d(2,i)*d(3,i)/h(i),h(i)]/r2(i)/sqrt(vb(i));
end
assert(norm(K-(J.'*J)\eye(3),'fro')/norm(K,'fro')<1e-10);
% Four equatorial posts give a repeated horizontal eigenspace.
P=[1 -1 0 0;0 0 1 -1;0 0 0 0];
[status,K,V,S]=mock_covariance(P,zeros(4,1),zeros(4,1),ones(4,1),ones(4,1),zeros(3,1));
assert(status==0 && norm(K-diag([.5 .5 .25]),'fro')<1e-12);
indices=abs(diag(S)-.5)<1e-12;
assert(sum(indices)==2);
U=V(:,indices);
assert(norm(U*U.'-diag([1 1 0]),'fro')<1e-12);
Q=[cos(.3) -sin(.3);sin(.3) cos(.3)];
assert(norm((U*Q)*(U*Q).'-U*U.','fro')<1e-12);
end