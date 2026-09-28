function unit_test_filter2win
% Independent arithmetic and state-transition checks of the scalar contract.
c=struct('N',4,'S',3,'R_MAX',2,'R_ALT_MAX',1, ...
    'T_PROLONGATION_MAX',3,'T_TIMEOUT_CLEAR',10);
s=struct('X_MAIN_REF',0);
s=step(c,s,0,0); s=step(c,s,1,2); assert(s.X_FILTERED_OUTPUT==1);
s=step(c,s,2,30); assert(s.X_FILTERED_OUTPUT==1 && ~s.ACCEPTED);
s=step(c,s,3,1); assert(s.X_FILTERED_OUTPUT==1 && s.W_ALT_POWER_OUTPUT==0);
% False initial hypothesis and switching on precisely the third candidate.
s=struct('X_MAIN_REF',100);
s=step(c,s,0,9); s=step(c,s,1,10); assert(~s.REACQUIRED);
s=step(c,s,2,11); assert(s.REACQUIRED && s.X_FILTERED_OUTPUT==10);
s=step(c,s,3,100); s=step(c,s,4,100); s=step(c,s,5,100);
assert(s.REACQUIRED && s.X_FILTERED_OUTPUT==100);
% Whole-window compactness; an incompatible sample starts a new hypothesis.
s=struct('X_MAIN_REF',0);
s=step(c,s,0,10); s=step(c,s,1,10); s=step(c,s,2,30);
assert(~s.REACQUIRED && s.W_ALT_POWER_OUTPUT==1);
% Hold and alternative expiry are independent and include exact boundaries.
s=struct('X_MAIN_REF',0); s=step(c,s,0,10);
s=step(c,s,3,NaN); assert(s.X_FILTERED_OUTPUT==0 && s.W_ALT_POWER_OUTPUT==1);
s=step(c,s,4,NaN); assert(isnan(s.X_FILTERED_OUTPUT) && s.W_ALT_POWER_OUTPUT==1);
s=step(c,s,10,NaN); assert(s.W_ALT_POWER_OUTPUT==1);
s=step(c,s,11,NaN); assert(s.W_ALT_POWER_OUTPUT==0);
% Expired main samples cannot bias the first new accepted observation.
s=struct('X_MAIN_REF',0); s=step(c,s,0,0); s=step(c,s,11,2);
assert(s.X_FILTERED_OUTPUT==2);
old=s; [st,s]=filter2win(c,s,11,1,false); assert(st==1 && isequaln(s,old));
[st,s]=filter2win(c,s,12,Inf,false); assert(st==1 && isequaln(s,old));
bad=c; bad.S=1; [st,s]=filter2win(bad,s,12,0,false); assert(st==1 && isequaln(s,old));
% Known velocity is applied consistently to both windows.
v=c; v.V=2; s=struct('X_MAIN_REF',0);
for t=0:20, s=step(v,s,t,2*t); assert(s.X_FILTERED_OUTPUT==2*t); end
% Gaussian noise, fixed seed, no hidden truth input or scenario switch.
state=rng; cleanup=onCleanup(@() rng(state)); rng(7301,'twister');
n=c; n.N=20; n.R_MAX=8; n.S=6;
x=randn(1,5000); y=zeros(size(x)); s=struct('X_MAIN_REF',0);
for t=1:numel(x), s=step(n,s,t,x(t)); y(t)=s.X_FILTERED_OUTPUT; end
assert(all(isfinite(y)) && sqrt(mean(y(100:end).^2))<0.4*sqrt(mean(x(100:end).^2)));
fprintf('filter2win contract and Gaussian noise: PASS; RMSE in=%g out=%g\n', ...
    sqrt(mean(x(100:end).^2)),sqrt(mean(y(100:end).^2)));
end

function s=step(c,s,t,x)
[status,s]=filter2win(c,s,double(t),double(x),isnan(x));
assert(status==0);
end