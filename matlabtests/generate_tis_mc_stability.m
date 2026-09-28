function report = generate_tis_mc_stability(folder,runs,range)
% Independent mode B: increasing Monte Carlo prefixes, one bearing per post.
if nargin<2, runs=5000; end
if nargin<3, range=450000; end
report=generate_tis_static_passport(folder,runs,1,range,'B');
end