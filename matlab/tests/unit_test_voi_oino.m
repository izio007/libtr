function status = unit_test_voi_oino()
%UNIT_TEST_VOI_OINO Analytic finite-sample OINO invariants on irregular times.
%  This file does not run automatically when the installer is applied.
status = 1;
t = [0; 0.2; 0.65; 1.1; 2.2];
F = [ones(numel(t),1), t];
G = [1; -1; 1; -1; 1];
theta = [0.1; 0.03];
eta = 0.02;
y = F * theta + G * eta;
sc = [0.7; 1.2; 0.9; 1.7; 1.1];
R = toeplitz(0.3 .^ (0:(numel(t)-1)));
Sigma = diag(sc) * R * diag(sc) * 1e-4;
L = [1, 0; 0.5, 1]; % value at 0.5 s, and its first derivative
[rc, out] = voi_oino_linear(t, y, F, G, Sigma, L, 1e8);
expect(rc == 0 && out.available && strcmp(out.reason,'OK'), 'valid OINO');
near(out.estimate, L.' * theta, 2e-12, 'nuisance invariance');
near(F.' * out.weights, L, 2e-12, 'useful reproduction');
near(G.' * out.weights, zeros(1,2), 2e-12, 'nuisance rejection');
near(out.covariance, out.weights.' * Sigma * out.weights, ...
    2e-12, 'covariance identity');

% Two identical functionals from the same observations have FULL covariance.
L2 = [1, 1; 0.5, 0.5];
[rc, twice] = voi_oino_linear(t, y, F, G, Sigma, L2, 1e8);
expect(rc == 0, 'two estimates from identical underlying observations');
near(twice.covariance(1,2), twice.covariance(1,1), ...
    2e-12, 'overlapping observations are not independent');
expect(twice.covariance(1,1) > 0, 'positive variance');

% At the first epoch only a constant, nuisance-free sample is identifiable.
[rc, first] = voi_oino_linear(0, -pi/6, 1, zeros(1,0), ...
    0.01^2, 1, 1e8);
expect(rc == 0, 'n=1 constant model');
near(first.estimate, -pi/6, 2e-12, 'first-epoch value');
near(first.covariance, 0.01^2, 2e-12, 'first-epoch covariance');

% Duplicated useful and nuisance columns make invariance impossible.
[rc, bad] = voi_oino_linear(t, y, F, F(:,1), Sigma, L, 1e8);
expect(rc == 1 && strcmp(bad.reason,'NONIDENTIFIABLE_BASES'), ...
       'useful/nuisance inseparability');

% A singular covariance cannot support the declared optimality theorem.
[rc, bad] = voi_oino_linear(t, y, F, G, zeros(numel(t)), L, 1e8);
expect(rc == 1 && strcmp(bad.reason,'NONPOSITIVE_COVARIANCE'), ...
       'singular covariance refused');

% A user-selected finite conditioning limit can refuse a valid-rank model.
[rc, bad] = voi_oino_linear(t, y, F, G, Sigma, L, 1.000001);
expect(rc == 1 && strcmp(bad.reason,'ILL_CONDITIONED_BASES'), ...
       'conditioning criterion');

% No invented observation is introduced to bridge a time gap.
[rc, ~] = voi_oino_linear([0;2;1;3;4], y, F, G, Sigma, L, 1e8);
expect(rc == 1, 'invalid time order refused');
status = 0;
end

function expect(condition, name)
if ~isscalar(condition) || ~condition
    error('VOI:OINO:Check', '%s', name);
end
end

function near(actual, expected, tolerance, name)
if ~isequal(size(actual),size(expected)) || ...
        any(~isfinite(actual(:))) || any(~isfinite(expected(:))) || ...
        max(abs(actual(:)-expected(:))) > tolerance
    error('VOI:OINO:Numeric', '%s', name);
end
end
