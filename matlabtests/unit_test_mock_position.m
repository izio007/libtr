function unit_test_mock_position
% mock_theory 1.2: flat calls and independent ray-projector equations.
P=[-20000 20000 20000 -20000;-20000 -20000 20000 20000;0 0 0 0];
for x={[1200;2300;4000],[1000;450000;8000],[-5000;-12000;3000]}
    truth=x{1}; d=truth-P; lengths=sqrt(sum(d.^2,1)); u=d./lengths;
    a=atan2(d(2,:),d(1,:)).'; b=atan2(d(3,:),hypot(d(1,:),d(2,:))).';
    [status,estimate]=mock_position(P,a,b,ones(4,1),ones(4,1));
    assert(status==0);
    A=zeros(3); rhs=zeros(3,1);
    for i=1:4
        projector=eye(3)-u(:,i)*u(:,i).';
        A=A+projector; rhs=rhs+projector*P(:,i);
    end
    tolerance=100*eps/rcond(A);
    assert(norm(estimate-truth)/norm(truth)<tolerance);
    assert(norm(A*estimate-rhs)/(norm(A)*norm(estimate)+norm(rhs))<1e-12);
end
[status,x]=mock_position(P(:,1),0,0,1,1);
assert(status==1 && all(isnan(x)));
[status,x]=mock_position(P,zeros(4,1),zeros(4,1),ones(4,1),ones(4,1));
assert(status==2 && all(isnan(x)));
end