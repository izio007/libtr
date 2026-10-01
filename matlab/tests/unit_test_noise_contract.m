function unit_test_noise_contract
old=rng; cleanup=onCleanup(@() rng(old));
P=[-1 0 0;0 -1 0;0 0 -1];
[a,b]=service_add_noise_ox(P,0,0,0,0,42);
assert(isequal(size(a),[1 3]) && isequal(size(b),[1 3]));
assert(max(abs(a-[0 pi/2 0]))<1e-14);
assert(max(abs(b-[0 0 pi/2]))<1e-14);
[a1,b1]=service_add_noise_ox(P,0,0,0,1,42);
[a2,b2]=service_add_noise_ox(P,0,0,0,1,42);
assert(isequal(a1,a2) && isequal(b1,b2));
[a2,b2]=service_add_noise_ox(P,0,0,0,2,42);
assert(max(abs((a2-a)-2*(a1-a)))<1e-14);
assert(max(abs((b2-b)-2*(b1-b)))<1e-14);
end