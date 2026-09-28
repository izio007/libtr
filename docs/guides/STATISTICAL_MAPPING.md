# Statistical mapping pipeline

Submit JSON Lines action `mapping` using the existing pipeline client. This is
an opt-in chain: mapping_unit -> environment -> mapping_integration -> mapping_png.
It never schedules the document gate, Live Editor, or heavy graphical passports.
Failed prerequisites block subsequent stages; execution success alone is not
acceptance. Unit scope is the nine explicit dependencies listed in the runner.

Integration reuses test_tis_ensemble: five geometries, four independent methods,
64 trials per case, 64 method/point cases. Inputs, statuses, exceptions, Bias,
conditional RMSE, covariance and spectral metrics are persisted. Expected
degenerate failures are tested by the unit contracts; these integration cases
require zero numerical failures.

generate_tis_mapping_images reads tis_ensemble.mat and saved post coordinates,
without sampling or solving again. Five tis_map_N.png files show ENU XY in km:
actual Cartesian estimates, truth marked x and physical posts marked v. Four
panels correspond to LLS/WLLS/GN/GNP. These are local-coordinate maps, not a
geographic basemap. Every exported PNG is decoded with imread before success.
Existing tis_geometry_N.png figures additionally show error clouds and axes.

Validation: runtime/pipeline/mapping_recovery_01/report.json records four passed
stages, nine passed unit tests and zero failures across 64 ensemble cases.
The test used a clean TCP worker on port 5556; the existing worker on 5555 was
not terminated. Restart tcpserver5555.m normally to activate the new action on
5555. A pending visual document audit is unrelated to numerical completion;
this action reports visual_review=not_requested, not approved.

The environment stage saves standard contexts; the integration stage uses its
own explicit five-geometry inputs, not a full trajectory from those contexts.
Heavy 300-point dynamic and 5000-run static passports remain separate opt-in
experiments and are not claimed as executed by this action.