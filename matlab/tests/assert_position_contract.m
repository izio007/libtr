function assert_position_contract(solver)
% Exact truth and explicit refusals, independent of engine contexts.
P=[-5000 5000 -5000 5000;-5000 -5000 5000 5000;0 0 0 0];
x=[1200;15000;3000]; d=x-P;
a=atan2(d(2,:),d(1,:)).'; b=atan2(d(3,:),hypot(d(1,:),d(2,:))).';
v=ones(4,1)*1e-6;
[s,y]=solver(P,a,b,v,v);
assert(s==0 && all(isfinite(y)) && norm(y-x)<1e-5, ...
    'libtr:test:Position','Unexpected failure on exact nondegenerate geometry');
[s,y]=solver(P(:,1),a(1),b(1),v(1),v(1));
assert(s==1 && isequal(size(y),[3 1]) && all(isnan(y)));
[s,y]=solver(zeros(3,2),zeros(2,1),zeros(2,1),ones(2,1),ones(2,1));
assert(s==2 && isequal(size(y),[3 1]) && all(isnan(y)));
end