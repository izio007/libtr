function [rc, out] = voi_oino_linear(t_obs, y, F, G, Sigma, L, kappa_max)
%VOI_OINO_LINEAR Invariant minimum-variance linear functional estimate.
%  One finite window; no Gaussian assumption, re-timing or hidden iteration.
%
%  y = F*theta + G*eta + epsilon; E[epsilon]=0, Cov(epsilon)=Sigma.
%  F: n-by-p useful basis; G: n-by-q nuisance basis (n-by-0 allowed).
%  L: p-by-r; desired characteristic is L.'*theta (r-by-1).
%  Times t_obs are the actual timestamps for the rows of F/G/y, seconds.
%  Repeated epochs are allowed for different measured channels. The caller
%  must construct F and G at THOSE times and keep raw-observation IDs.
%
%  Minimize W.'*Sigma*W subject to F.'*W=L and G.'*W=0. Return
%  estimate=W.'*y; covariance=W.'*Sigma*W; weights W (n-by-r).
%  Whitening, orthogonal nuisance removal, and QR solve this problem
%  without fitting nuisance coefficients or inverting normal equations.
%  The achieved invariance/unbiasedness is conditional on the exact linear
%  model, full combined rank, centred noise and KNOWN SPD covariance.
%
%  A covariance of multiple outputs from overlapping windows must use
%  W1.'*Sigma_12*W2 on their common raw sample space. Treating such
%  outputs as statistically independent is not justified by this function.
%  The geometric voi_position remains unweighted and does not consume this
%  covariance. This function alone is not an integrated statistical TIS.
%
%  rc=0 and out.available=true on success; rc=1 otherwise. Pure function.

rc = 1;
out = struct('available', false, 'reason', 'INVALID_API', ...
    'estimate', NaN, 'covariance', NaN, 'weights', NaN, ...
    'condition', NaN, 'constraint_residual', NaN, ...
    'sample_count', 0, 'useful_rank', 0, 'nuisance_rank', 0);
if nargin ~= 7
    return;
end
if ~real_double(t_obs) || ~iscolumn(t_obs) || isempty(t_obs) || ...
        ~real_double(y) || ~iscolumn(y) || ...
        ~real_double(F) || ~ismatrix(F) || ...
        ~real_double(G) || ~ismatrix(G) || ...
        ~real_double(Sigma) || ~ismatrix(Sigma) || ...
        ~real_double(L) || ~ismatrix(L) || ...
        ~isa(kappa_max, 'double') || ~isreal(kappa_max) || ...
        ~isscalar(kappa_max) || ~isfinite(kappa_max) || kappa_max <= 1
    out.reason = 'INVALID_INPUT';
    return;
end
n = numel(y);
p = size(F, 2);
q = size(G, 2);
r = size(L, 2);
out.sample_count = n;
out.useful_rank = p;
out.nuisance_rank = q;
if ~isequal(size(t_obs), [n, 1]) || any(diff(t_obs) < 0) || ...
        p < 1 || r < 1 || n < p + q || ...
        ~isequal(size(F), [n, p]) || ...
        ~isequal(size(G), [n, q]) || ...
        ~isequal(size(Sigma), [n, n]) || ...
        ~isequal(size(L), [p, r])
    out.reason = 'INVALID_DIMENSIONS_OR_TIMES';
    return;
end

% The caller supplies the full covariance of the raw window. Positivity,
% not normality, is required by the whitening step.
scale = norm(Sigma, 'fro');
if ~isfinite(scale) || scale <= 0
    out.reason = 'NONPOSITIVE_COVARIANCE';
    return;
end
if norm(Sigma - Sigma.', 'fro') > 64 * n * eps(scale)
    out.reason = 'NONSYMMETRIC_COVARIANCE';
    return;
end
Sigma = (Sigma + Sigma.') / 2;
try
    [Rcov, chol_info] = chol(Sigma);
catch
    out.reason = 'INVALID_COVARIANCE';
    return;
end
if chol_info ~= 0 || any(~isfinite(Rcov(:)))
    out.reason = 'NONPOSITIVE_COVARIANCE';
    return;
end

A = [F, G];
B = [L; zeros(q, r)];
try
    Aw = Rcov.' \ A;
    sv = svd(Aw, 0);
catch
    out.reason = 'NUMERIC_FAILURE';
    return;
end
if numel(sv) ~= p + q || any(~isfinite(sv)) || ...
        sv(1) <= 0 || any(~isfinite(Aw(:)))
    out.reason = 'NUMERIC_FAILURE';
    return;
end
rank_tolerance = max(size(Aw)) * eps(sv(1));
if sv(end) <= rank_tolerance
    out.condition = Inf;
    out.reason = 'NONIDENTIFIABLE_BASES';
    return;
end
out.condition = sv(1) / sv(end);
if ~isfinite(out.condition) || out.condition >= kappa_max
    out.reason = 'ILL_CONDITIONED_BASES';
    return;
end
try
    Gw = Aw(:, p + 1:end);
    Fw = Aw(:, 1:p);
    if q == 0
        Qn = zeros(n, 0);
    else
        [Qn, ~] = qr(Gw, 0);
    end
    % Orthogonalize the useful basis against the nuisance subspace.
    % Neither nuisance coefficients nor an n-by-n projector are formed.
    Fres = Fw - Qn * (Qn.' * Fw);
    [Q, R] = qr(Fres, 0);
    Z = R.' \ L;
    W = Rcov \ (Q * Z);
    estimated = W.' * y;
    estimated_covariance = Z.' * Z;
    estimated_covariance = (estimated_covariance + ...
        estimated_covariance.') / 2;
    discrepancy = A.' * W - B;
    constraint_residual = norm(discrepancy, 'fro');
catch
    out.reason = 'NUMERIC_FAILURE';
    return;
end
if any(~isfinite(W(:))) || any(~isfinite(estimated(:))) || ...
        any(~isfinite(estimated_covariance(:))) || ...
        ~isfinite(constraint_residual)
    out.reason = 'NUMERIC_FAILURE';
    return;
end
% This is a numerical round-off check, not a statistical error bound.
residual_scale = max([1, norm(A, 'fro') * norm(W, 'fro'), ...
                     norm(B, 'fro')]);
if constraint_residual > 256 * max(size(A)) * eps(residual_scale)
    out.reason = 'CONSTRAINT_NUMERIC_FAILURE';
    out.constraint_residual = constraint_residual;
    return;
end
out.available = true;
out.reason = 'OK';
out.estimate = estimated;
out.covariance = estimated_covariance;
out.weights = W;
out.constraint_residual = constraint_residual;
rc = 0;
end

function ok = real_double(x)
    ok = isa(x, 'double') && isreal(x) && ~issparse(x) && ...
         all(isfinite(x(:)));
end
