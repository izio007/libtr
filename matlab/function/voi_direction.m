function [code, u, info] = voi_direction(a, b, C)
%VOI_DIRECTION Convert signed plane angles into a common-frame unit ray.
%   a is the signed angle to the receiver xz plane; b is the signed
%   angle to its xy plane. Both are radians in [-pi/2, pi/2]. C maps
%   receiver coordinates to the common Cartesian frame. Only the strict
%   forward branch is admitted. A numerical boundary strip is rejected,
%   rather than converted into an artificial forward-looking direction.
%
%   code = 1: accepted; 0: known invalid/inadmissible; -1: missing input.
%   Failure leaves u = NaN(3,1). info.u_receiver is diagnostic only.
%   alpha/beta describe the COMMON frame; a_back/b_back describe the
%   RECEIVER frame. alpha is NaN for an exactly vertical common-frame ray.
%   No normalization repairs inconsistent angles or an invalid rotation.

    code = 0;
    u = NaN(3, 1);
    info = struct('reason', 'INVALID_INPUT', 'd', NaN, ...
                  'u_receiver', NaN(3, 1), 'alpha', NaN, 'beta', NaN, ...
                  'a_back', NaN, 'b_back', NaN);

    if nargin < 3
        code = -1;
        info.reason = 'MISSING_INPUT';
        return;
    end
    if isempty(a) || isempty(b) || isempty(C)
        code = -1;
        info.reason = 'MISSING_INPUT';
        return;
    end
    if ~isa(a, 'double') || ~isreal(a) || ~isscalar(a) || ~isfinite(a) || ...
       ~isa(b, 'double') || ~isreal(b) || ~isscalar(b) || ~isfinite(b) || ...
       abs(a) > pi / 2 || abs(b) > pi / 2
        info.reason = 'INVALID_ANGLES';
        return;
    end
    if ~isa(C, 'double') || ~isreal(C) || ~isequal(size(C), [3, 3]) || ...
       any(~isfinite(C(:)))
        info.reason = 'INVALID_ROTATION';
        return;
    end

    d_tol = 32 * eps;
    frame_tol = 1e-10;
    % A proper rotation cannot have an entry larger than one. This cheap
    % bound also prevents overflow in C'*C for a malformed finite matrix.
    if any(abs(C(:)) > 1 + frame_tol) || ...
       norm(C' * C - eye(3), 'fro') > frame_tol || ...
       abs(det(C) - 1) > frame_tol
        info.reason = 'INVALID_ROTATION';
        return;
    end

    uy = sin(a);
    uz = sin(b);
    d = 1 - uy * uy - uz * uz;
    info.d = d;
    info.u_receiver = [NaN; uy; uz];
    if d < -d_tol
        info.reason = 'INCOMPATIBLE_ANGLES';
        return;
    end
    if d <= d_tol
        % |d| <= d_tol is geometrically a boundary to roundoff accuracy.
        % The diagnostic x=0 is not an admitted output and is not normalized.
        info.u_receiver = [0; uy; uz];
        info.reason = 'BOUNDARY';
        return;
    end

    u_receiver = [sqrt(d); uy; uz];
    u_candidate = C * u_receiver;
    if any(~isfinite(u_candidate))
        info.reason = 'NUMERIC_FAILURE';
        return;
    end
    info.u_receiver = u_receiver;
    info.a_back = atan2(uy, hypot(u_receiver(1), uz));
    info.b_back = atan2(uz, hypot(u_receiver(1), uy));
    horizontal = hypot(u_candidate(1), u_candidate(2));
    if horizontal > 0
        info.alpha = atan2(u_candidate(2), u_candidate(1));
    end
    info.beta = atan2(u_candidate(3), horizontal);
    info.reason = 'OK';
    u = u_candidate;
    code = 1;
end
