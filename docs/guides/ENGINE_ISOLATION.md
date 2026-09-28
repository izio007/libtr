# Engine isolation audit

Common numerical services must not select a scenario by name, distance or test
identifier. Pipeline orchestration is an explicit exception: selecting tests
is its responsibility, not a numerical policy of the kernels.

Six scenario functions were moved unchanged from matlabengine to matlabtests:
service_generate_static_context, service_init_geometry_30km,
service_init_geometry_160km, service_init_geometry_unit,
service_init_geometry_criteria, service_run_multi_criteria_bench.
Names and existing signatures are preserved. Callers that formerly added only
matlabengine must now add matlabtests to use these scenario functions. The
pipeline already adds both directories. The filename-based legacy dispatcher
is retained only in the scenario layer, not presented as a general calculator.

service_ideal_mock_position now generates exact bearings with atan2 and hypot
and calls mock_position. The old 1e-3 horizontal-distance floor and duplicate
normal-equation implementation were removed. The adapter is not an independent
oracle; independence is supplied by unit_test_mock_position's ray projectors.
For fewer than two posts its status changes from 2 to the kernel's status 1.
There is no distance cutoff at 450 km; matrix conditioning controls rejection.

Validation in runtime/engine_isolation.log used a fresh MATLAB batch process:
unit_test_engine_isolation, unit_test_mock_position and unit_test_pipeline all
completed successfully. The isolation test removes matlabtests from the search
path during adapter calls. The dispatcher test verifies environment generation,
state restoration, cancellation and invalid actions after relocation.
No document gate or Live Editor export was run. The TCP protocol cannot select
this exact subset; a clean batch process avoided an unrelated full unit run.

Remaining scope: service_calc_crlb_trajectory still clips negative diagonal
entries with max(...,0). Its output and failure contracts need separate review;
this change does not certify every engine service as free from numerical
patches. No mathematical passport or kernel was changed. A full runtime mapping
regression and reloading the long-lived TCP worker remain unverified here.