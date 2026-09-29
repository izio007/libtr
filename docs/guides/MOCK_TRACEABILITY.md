# Mock traceability: current scope

SSOT: docs/mock_theory.txt. No kernel or mathematical source was changed.
Research limitations: docs/tis_research_theory.txt. Run run_mock_traceability directly.
Historical success claims are explicitly not current acceptance evidence.

| Source | Implementation | Independent check |
|---|---|---|
| 1.2, H_init and b_init | mock_position, row assembly | unit_test_mock_position: ray projectors I-u*u', ideal truth, normal-equation residual |
| 1.2, normal equations | mock_position, backslash solve | same test: conditioning-scaled forward error and residual |
| 2.2, displacements and ranges | mock_covariance | unit_test_mock_covariance: independent measurement map |
| 2.2, angular gradients | mock_covariance | central differences of atan2 with wrapped azimuth differences |
| 2.2, Fisher sum and 2.3 inverse | mock_covariance | stacked whitened Jacobian, information-times-covariance identity |
| 2.3, eigenpairs and axes | mock_covariance | eigen residual, orthogonality, reconstruction, positive eigenvalues |
| 2.3, angles and semiaxes | output interpretation | reconstruction from atan2 angles and squared semiaxes |
| 3, zenith | mock_covariance | exact zenith: status 2 and NaN in all three outputs; nonzero sub-millimetre offset is not clipped |
| 3, nonunique eigenvectors | mock_covariance | sign invariance and repeated-eigenspace projector, including rotated basis |

The backslash solve implements the stated nonsingular normal equations without
forming an explicit inverse. The position test uses a backward residual and a
conditioning-scaled forward-error tolerance; algebraic equivalence alone is not
used as finite-precision evidence. Internal rows are not publicly exposed:
projector tests verify their observable combined operator, not each internal
assignment separately. No claim of exhaustive coverage is made.

## Remaining gaps requiring a contract decision

- Status 1 (fewer than two posts) is implemented and tested but not explicitly
  specified in the TXT interface. Invalid-input contracts are incomplete.
- Section 3 mentions a determinant reaching machine zero, whereas the actual
  predicate is reciprocal condition number. Range alone is not the predicate.
- Ideal mock does not establish noisy-estimator Bias. The existing dynamic and
  static graphical experiments are separate evidence; their numeric results
  are not hard-coded as expected values in the research overview.
- Internal stage observability and a formula-by-formula exhaustive inventory
  remain pending. Current tests do not prove 100 percent contract coverage.

## Validation

runtime/mock_traceability_01/report.json records both mock tests passing and
geometry_status=0. The actual covariance produces mock_spectrum.png and the
inputs and spectral outputs are saved in mock_traceability.mat. Each new run
uses a new folder. The targeted validation used a clean MATLAB batch process:
the TCP protocol has no dedicated action for this scenario. No document gate
or Live Editor export was run. Whole-file execution/rendering of historical
The historical def.m was not validated; run_mock_traceability was executed directly. The research overview now resides in docs/tis_research_theory.txt.