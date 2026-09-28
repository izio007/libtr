# Two graphical experiments

These scenarios do not change any estimator. Four independent calls use LLS,
WLLS, Cartesian GN and polar GNP. WLLS retains its internal LLS initialization;
the output of one independently tested method never initializes another.

## Statistical contract

An ensemble consists of R independent solutions at identical truth and geometry.
Bias = mean(estimates) - truth. Axis RMSE is sqrt(mean(error.^2)); spatial
RMSE is sqrt(mean(sum(error.^2))). Axis standard deviation is computed about
the empirical mean using denominator successful-1. Max Miss is the largest
Euclidean error among successful solutions. All statistics exclude failed
solutions and are explicitly conditional on success; failure fractions and
contract violations are saved, never replaced with zero error.

The CRLB reference is mock_covariance from docs/mock_theory.txt, evaluated at
truth with ideal bearings and the actual measurement variances. The historical
lls3d_fisher_crlb.m is absent. sqrt(diag(K)) is a standard-deviation reference,
not a universal lower bound on biased-estimator RMSE.

## Dynamic experiment

generate_tis_dynamic_passport(contextFile, outputFolder, runs) uses all trajectory
points of the input context. Default runs=32 per point and station count; this
is a diagnostic ensemble, not the heavy 5000-run static experiment.
Counts are unique(round(logspace(log10(4),log10(124),20))). At each count the
whole station curve is sampled, rather than taking a prefix of one flank.
All four methods receive the same saved observations.

Each method has exactly four axes: truth/stations/ensemble cloud; centered
axis standard deviations with faint CRLB and bold spatial RMSE versus trajectory
coordinate; pooled spatial RMSE and Max Miss versus station count; Bias Y
versus trajectory coordinate for all counts (to expose both flanks).
The first two panels use the configured Fixed_N_Index. Physical station count
changes in this experiment; repeated measurements are not substituted for it.

## Static experiment

generate_tis_static_passport(outputFolder, runs, repeats, range) defaults to
5000 runs, repeats=[1 2 4 8 16 31], range=450000 metres, truth=[0;range;10000],
and four cross stations at (+/-20000,0,200), (0,+/-20000,200) metres.
Independent Gaussian angular noise has standard deviation 2 degrees per
channel. A repetition count k means 4*k independent bearing pairs, NOT k
Monte Carlo solutions and NOT extra physical stations. Coordinates repeat;
angles are never averaged and their variances are never divided by k.

Each of four method figures has exactly three vertically arranged axes: spatial cloud and geometry;
spatial RMSE versus repeats per physical station; Y histograms for each repeat
count, with truth marked. All finite estimates are plotted, with no forced
0..40 km clipping. Collapse of LLS/WLLS and accurate nonlinear solutions are
hypotheses to observe, not imposed acceptance results.

### Independent modes A and B

Mode A is the existing generate_tis_static_passport call: each repeat count
uses a fresh ensemble, not prefixes of another measurement packet. Its RMSE
reference is sqrt(trace(K_CRLB)); convergence to that reference is not asserted
for biased estimators or ensembles conditioned on successful solutions.

Mode B is generate_tis_mc_stability(outputFolder, runs, range), with defaults
5000 and 450000 m. It uses its own seed (1338 versus 1337), a new output folder,
and exactly one observation per physical post. For prefix K, let s_K be the
number of successful solutions among the first K trials. The conditional RMSE
is sqrt(sum of squared spatial errors over those successes / s_K), undefined
when s_K=0. Failed trials remain in the denominator K of the failure fraction,
but never enter the error sum as zero-error observations. The plotted RMSE has
NaN gaps at failed trials; prefix MAT files retain both the conditional statistic
and the plotted curve, success counts and cumulative failure fractions.
Stabilization is diagnostic, not proof of representativeness or finite moments.
Each mode produces four independent figures with three vertical panels.

## Execution and evidence

Run functions with matlab/, matlabengine/, matlabtests/ on MATLAB path. Output
folders must be new. MAT files retain observations, estimates, statuses and
metrics for every cell. JSON reports separate execution, contract violations,
numerical failures and PNG counts. Failed numerical trials make the report
passed=false, but do not prevent independent methods or figures from completing.
Reduced regression runs are not acceptance of full statistical experiments.
These functions are explicit opt-in scenarios: ordinary png/all jobs are not
silently expanded to hundreds of thousands of additional solver calls.

## Recorded validation

The regression unit test passed in runtime/passport_smoke.log. The full dynamic
run in runtime/passport_dynamic_full_01 completed 300 trajectory points, 20
station counts and 32 trials per cell: passed=true. Four PNGs were exported;
each figure asserts exactly four axes before export.

The static run in runtime/passport_static_5000_01 completed 5000 trials for each
of six repeat counts [1 2 4 8 16 31] at Y=450000 m. Four PNGs were exported;
each figure asserts exactly three axes. Its report is passed=false with seven
method/repetition cells containing numerical failures. This is not acceptance
of guaranteed nonlinear convergence. Original observations and failed statuses
remain available in the cell MAT files. Both runs used a separate clean MATLAB
process because the TCP endpoint has no dedicated actions for these scenarios.
Document translation and Live Editor export were not run for this change.

Independent A/B validation: runtime/modes_A_5000_01 and runtime/modes_B_5000_01
contain the complete 5000-trial experiments with seeds 1337 and 1338. Each
contains four PNGs with three vertical axes. Mode A has seven method/repetition
cells with failures; mode B has two. At one observation per post, mode B records
GN failure fraction 0.0386 and GNP 0.173; LLS and WLLS have no numerical failures.
Both reports correctly retain passed=false. Successful rendering and regression
tests do not establish estimator convergence or statistical sufficiency.