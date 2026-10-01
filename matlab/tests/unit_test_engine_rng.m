function unit_test_engine_rng
setup_test_paths;
before=rng;
a=engine_rng_init(812); b=engine_rng_init(27);
[x,a1]=engine_rng_normal(a,4,5);
[~,b1]=engine_rng_normal(b,2,8);
[y,a2]=engine_rng_normal(a1,4,5);
[xx,aa1]=engine_rng_normal(a,4,5);
[yy,aa2]=engine_rng_normal(aa1,4,5);
assert(isequal(x,xx) && isequal(y,yy) && isequal(a2,aa2));
[bb,bb1]=engine_rng_normal(b,2,8);
[bbb,bbb1]=engine_rng_normal(b,2,8);
assert(isequal(bb,bbb) && isequal(b1,bb1) && isequal(bb1,bbb1));
s=RandStream('mt19937ar','Seed',812,'NormalTransform','Ziggurat');
assert(isequal(x,randn(s,4,5)) && isequal(y,randn(s,4,5)));
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
file=[tempname(fullfile(root,'runtime')) '.mat'];
save(file,'a1'); saved=load(file);
[z,az]=engine_rng_normal(saved.a1,4,5);
assert(isequal(z,y) && isequal(az,a2));
bad=a; bad.state=0;
try
    engine_rng_normal(bad,1,2);
    error('libtr:test:FalsePass','Invalid state accepted');
catch ex
    assert(strcmp(ex.identifier,'libtr:rng:Context'));
end
P=[-1 0;0 -1;0 0];
[~,alpha,beta,~,next]=service_sample_bearings(P,zeros(3,1),0.1,2,5,a);
assert(isequal(alpha,[0;pi/2;0;pi/2]+0.1*x));
assert(isequal(beta,0.1*y) && isequal(next,a2));
[n1,n2,nc]=service_add_noise_ox(P,0,0,0,1,a);
[m1,m2,mc]=service_add_noise_ox(P,0,0,0,1,a);
assert(isequal(n1,m1) && isequal(n2,m2) && isequal(nc,mc));
assert(isequal(rng,before),'Global RNG changed');
fprintf('Explicit RNG isolation, snapshot, continuation, oracle and refusal PASS\n');
end