function [code, p, info] = voi_position(origins, directions, Lmin, kappa_max, residual_max)
%VOI_POSITION Equal-weight 3-D projector least squares for a stationary point.
%   Columns are origins and unit directions in one Cartesian frame (metres).
%   Length errors above unit_tol are refused. Accepted directions are
%   divided by their computed length before forming orthoprojectors;
%   this removes only admissible representation error, never invalid data.
%   Solve H*x = rhs by explicit economy QR, with P_i = I-u_i*u_i'.
%   SVD of H supplies rank and cond(A), A=H'*H, but never a pseudoinverse,
%   a truncated solution, or an artificial regularization of missing range.
%
%   The equations minimize distances to the supporting LINES. Acceptance
%   additionally requires strictly positive directed ranges on ALL rays.
%   The residual policy applies to the actual returned finite coordinates.
%   A refusal always returns code=0 and p=NaN(3,1). Numerical diagnostics
%   remain available when they can be computed without solving the system.

    code = 0;
    p = NaN(3, 1);
    info = struct('reason', 'INVALID_INPUT', 'L', NaN, ...
                  'condition_A', NaN, 'lambda_min', NaN, 'lambda_max', NaN, ...
                  'rms_residual', NaN, 'min_range', NaN, 'count', 0);

    if nargin < 5
        return;
    end
    if ~isa(origins, 'double') || ~isreal(origins) || ~ismatrix(origins) || ...
       size(origins, 1) ~= 3 || any(~isfinite(origins(:))) || ...
       ~isa(directions, 'double') || ~isreal(directions) || ...
       ~isequal(size(directions), size(origins)) || ...
       any(~isfinite(directions(:))) || ...
       ~isa(Lmin, 'double') || ~isreal(Lmin) || ~isscalar(Lmin) || ...
       ~isfinite(Lmin) || Lmin < 0 || ...
       ~isa(kappa_max, 'double') || ~isreal(kappa_max) || ...
       ~isscalar(kappa_max) || ~isfinite(kappa_max) || kappa_max <= 1 || ...
       ~isa(residual_max, 'double') || ~isreal(residual_max) || ...
       ~isscalar(residual_max) || isnan(residual_max) || residual_max < 0
        return;
    end
    n = size(origins, 2);
    info.count = n;
    unit_tol = 1e-10;
    lengths = hypot(hypot(directions(1, :), directions(2, :)), directions(3, :));
    if any(abs(lengths - 1) > unit_tol)
        return;
    end
    if n == 0
        info.L = 0;
        info.condition_A = Inf;
        info.lambda_min = 0;
        info.lambda_max = 0;
        info.reason = 'INSUFFICIENT_RAYS';
        return;
    end
    unit_directions = bsxfun(@rdivide, directions, lengths);

    H = zeros(3 * n, 3);
    for i = 1:n
        rows = (3 * i - 2):(3 * i);
        ui = unit_directions(:, i);
        H(rows, :) = eye(3) - ui * ui';
    end
    try
        singular_values = svd(H, 0);
    catch
        info.reason = 'NUMERIC_FAILURE';
        return;
    end
    if numel(singular_values) ~= 3 || any(~isfinite(singular_values))
        info.reason = 'NUMERIC_FAILURE';
        return;
    end
    smax = singular_values(1);
    smin = singular_values(3);
    info.lambda_min = smin * smin;
    info.lambda_max = smax * smax;
    if smin == 0
        info.condition_A = Inf;
    else
        info.condition_A = (smax / smin)^2;
    end
    rank_tol = max(size(H)) * eps(smax);
    if smin <= rank_tol
        % Infinity denotes numerical rank deficiency; lambda_min retains
        % its computed value rather than pretending an exact arithmetic zero.
        info.condition_A = Inf;
    end

    % This is a history-wide baseline, not displacement from the first
    % origin to the latest one: returning to an old origin preserves it.
    L = 0;
    for i = 2:n
        for j = 1:(i - 1)
            separation = origins(:, i) - origins(:, j);
            if any(~isfinite(separation))
                info.reason = 'NUMERIC_FAILURE';
                return;
            end
            distance = hypot(hypot(separation(1), separation(2)), separation(3));
            if ~isfinite(distance)
                info.reason = 'NUMERIC_FAILURE';
                return;
            end
            L = max(L, distance);
        end
    end
    info.L = L;
    if n < 2
        info.reason = 'INSUFFICIENT_RAYS';
        return;
    end
    if smin <= rank_tol
        info.reason = 'SINGULAR_GEOMETRY';
        return;
    end
    if L <= Lmin
        info.reason = 'INSUFFICIENT_BASELINE';
        return;
    end
    if ~isfinite(info.condition_A) || info.condition_A >= kappa_max
        info.reason = 'ILL_CONDITIONED';
        return;
    end

    % The reference is the arithmetic centroid. Evaluate it through offsets
    % from one supplied origin, so large common translations neither enter
    % the projector right-hand side nor cause overflow in sum(origins).
    anchor = origins(:, 1);
    local_origins = bsxfun(@minus, origins, anchor);
    if any(~isfinite(local_origins(:)))
        info.reason = 'NUMERIC_FAILURE';
        return;
    end
    reference_offset = sum(local_origins / n, 2);
    centered = bsxfun(@minus, local_origins, reference_offset);
    if any(~isfinite(reference_offset)) || any(~isfinite(centered(:)))
        info.reason = 'NUMERIC_FAILURE';
        return;
    end
    rhs = zeros(3 * n, 1);
    for i = 1:n
        rows = (3 * i - 2):(3 * i);
        rhs(rows) = H(rows, :) * centered(:, i);
    end
    if any(~isfinite(rhs))
        info.reason = 'NUMERIC_FAILURE';
        return;
    end
    try
        [Q, R] = qr(H, 0);
        centered_solution = R \ (Q' * rhs);
    catch
        info.reason = 'NUMERIC_FAILURE';
        return;
    end
    p_candidate = anchor + (reference_offset + centered_solution);
    if any(~isfinite(centered_solution)) || any(~isfinite(p_candidate))
        info.reason = 'NUMERIC_FAILURE';
        return;
    end

    residuals = zeros(3 * n, 1);
    ranges = zeros(1, n);
    for i = 1:n
        rows = (3 * i - 2):(3 * i);
        delta = p_candidate - origins(:, i);
        if any(~isfinite(delta))
            info.reason = 'NUMERIC_FAILURE';
            return;
        end
        ranges(i) = unit_directions(:, i)' * delta;
        residuals(rows) = H(rows, :) * delta;
    end
    if any(~isfinite(ranges)) || any(~isfinite(residuals))
        info.reason = 'NUMERIC_FAILURE';
        return;
    end
    info.min_range = min(ranges);
    % Divide before taking the norm to avoid a representable RMS being
    % rejected solely because the unscaled stacked norm would overflow.
    info.rms_residual = norm(residuals / sqrt(n), 2);
    if ~isfinite(info.rms_residual)
        info.reason = 'NUMERIC_FAILURE';
        return;
    end
    if info.min_range <= 0
        info.reason = 'NONPOSITIVE_RANGE';
        return;
    end
    if info.rms_residual > residual_max
        info.reason = 'RESIDUAL_LIMIT';
        return;
    end

    p = p_candidate;
    code = 1;
    info.reason = 'OK';
end
