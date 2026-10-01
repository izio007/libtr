function [P,a,b,v] = test_sample_bearings(stations,truth,sigma,repeats,runs)
% Legacy scenario RNG policy is confined to the test composition, not engine.
s=RandStream.getGlobalStream;
assert(strcmp(s.Type,'mt19937ar') && strcmp(s.NormalTransform,'Ziggurat') && ...
    ~s.Antithetic && s.FullPrecision,'libtr:test:RNG','Expected default twister');
c=engine_rng_init(0); c.state=s.State;
[P,a,b,v,next]=service_sample_bearings(stations,truth,sigma,repeats,runs,c);
s.State=next.state;
end