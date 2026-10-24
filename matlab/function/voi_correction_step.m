function [rc, ctx, out] = voi_correction_step(H, ctx, t, target)
%VOI_CORRECTION_STEP Retarget a continuous C2 cubic coordinate signal.
%   [rc,ctx,out] = voi_correction_step(H,ctx,t,target), initially ctx=struct().
%   target=[] means no new accepted point. The first point initializes a
%   constant signal immediately; a later DIFFERENT point creates three
%   cubic pieces, preserving the old position and its first two derivatives.
%   H is an explicit positive transition horizon, fixed for the context.
%
%   The signal is a correction of published coordinates, not target motion.
%   Equal targets never extend a transition. Missing targets continue it.
%   Every completed step requires strictly increasing t. Any API/numerical
%   failure returns rc=1 and leaves the input ctx exactly unchanged.
%
%   Coefficients are LOCAL DISPLACEMENTS from position_origin, in powers
%   of z=(t-knots(i))/(knots(i+1)-knots(i)), not in powers of raw seconds.
%   The four absolute knots must be finite and strictly distinguishable.
%   Their representable spacings are used in the solve and in evaluation.

    rc = 1;
    if nargin < 2
        ctx = [];
    end
    out = correction_error('INVALID_API');
    if nargin ~= 4
        return;
    end
    if ~isa(H, 'double') || ~isreal(H) || ~isscalar(H) || ~isfinite(H) || H <= 0
        out.reason = 'INVALID_H';
        return;
    end
    if ~isa(t, 'double') || ~isreal(t) || ~isscalar(t) || ~isfinite(t)
        out.reason = 'INVALID_TIME';
        return;
    end
    missing_target = isa(target, 'double') && isreal(target) && isempty(target);
    if ~missing_target && (~isa(target, 'double') || ~isreal(target) || ...
                           ~isequal(size(target), [3, 1]) || any(~isfinite(target)))
        out.reason = 'INVALID_TARGET';
        return;
    end
    if ~isstruct(ctx) || ~isscalar(ctx)
        out.reason = 'INVALID_CONTEXT';
        return;
    end

    if isempty(fieldnames(ctx))
        candidate = struct('schema_version', 1, 'H', H, 'last_tick', t, ...
            'ready', false, 'target', NaN(3, 1), 'start_time', t, 'end_time', t, ...
            'knots', repmat(t, 1, 4), 'position_origin', NaN(3, 1), ...
            'coeff', NaN(3, 4, 3));
        current = correction_error('NO_TARGET');
    else
        [old_rc, current] = voi_correction_eval(ctx, t);
        if old_rc ~= 0
            out = current;
            return;
        end
        if H ~= ctx.H
            out.reason = 'H_CHANGED';
            return;
        end
        if t <= ctx.last_tick
            out.reason = 'TIME_NOT_INCREASING';
            return;
        end
        candidate = ctx;
        candidate.last_tick = t;
    end

    if ~missing_target && ~candidate.ready
        % There is no earlier spatial point from which to invent a motion.
        candidate.ready = true;
        candidate.target = target;
        candidate.position_origin = target;
        candidate.start_time = t;
        candidate.end_time = t;
        candidate.knots = repmat(t, 1, 4);
        candidate.coeff = zeros(3, 4, 3);
    elseif ~missing_target && ~isequal(target, candidate.target)
        knots = t + [0, H / 3, 2 * (H / 3), H];
        widths = diff(knots);
        duration = knots(4) - knots(1);
        if any(~isfinite(knots)) || any(~isfinite(widths)) || ...
           any(widths <= 0) || ~isfinite(duration) || duration <= 0
            out.reason = 'UNREPRESENTABLE_TIME_GRID';
            return;
        end

        % V and A are derivatives with respect to normalized total time.
        % Reuse the old normalized jet rather than dividing by a possibly
        % huge duration and multiplying it back: H is unchanged, so the
        % ratio of the new duration to an old piece width stays moderate.
        V = zeros(3, 1);
        A = zeros(3, 1);
        if current.transitioning
            piece = 1 + (t >= candidate.knots(2)) + (t >= candidate.knots(3));
            old_width = candidate.knots(piece + 1) - candidate.knots(piece);
            z = (t - candidate.knots(piece)) / old_width;
            c = candidate.coeff(:, :, piece);
            scale_ratio = duration / old_width;
            V = (c(:, 2) + z * (2 * c(:, 3) + z * (3 * c(:, 4)))) * scale_ratio;
            A = (2 * c(:, 3) + z * (6 * c(:, 4))) * scale_ratio * scale_ratio;
        end
        delta = target - current.position;
        if any(~isfinite(V)) || any(~isfinite(A)) || any(~isfinite(delta))
            out.reason = 'NUMERIC_FAILURE';
            return;
        end

        % Constant normalized third derivatives on the three pieces.
        % Each column gives its integrated effect on final acceleration,
        % velocity, and position. Actual representable widths are used,
        % so a large absolute clock does not introduce unaccounted jumps.
        r = widths / duration;
        remaining = (knots(4) - knots(1:3)) / duration;
        M = [r; ...
             r .* (remaining - r / 2); ...
             r .* (remaining.^2 / 2 - remaining .* r / 2 + r.^2 / 6)];
        rhs = [-A'; (-V - A)'; (delta - V - A / 2)'];
        if any(~isfinite(M(:))) || any(~isfinite(rhs(:)))
            out.reason = 'NUMERIC_FAILURE';
            return;
        end
        try
            J = (M \ rhs)';
        catch
            out.reason = 'NUMERIC_FAILURE';
            return;
        end
        if any(~isfinite(J(:)))
            out.reason = 'NUMERIC_FAILURE';
            return;
        end
        coeff = zeros(3, 4, 3);
        q = zeros(3, 1);
        for i = 1:3
            ri = r(i);
            c = [q, V * ri, (A * ri) * (ri / 2), ...
                 ((J(:, i) * ri) * ri) * (ri / 6)];
            coeff(:, :, i) = c;
            q = ((c(:, 4) + c(:, 3)) + c(:, 2)) + c(:, 1);
            V = (c(:, 2) + 2 * c(:, 3) + 3 * c(:, 4)) / ri;
            A = ((2 * c(:, 3) + 6 * c(:, 4)) / ri) / ri;
        end
        if any(~isfinite(coeff(:)))
            out.reason = 'NONFINITE_COEFFICIENTS';
            return;
        end
        candidate.target = target;
        candidate.position_origin = current.position;
        candidate.start_time = t;
        candidate.end_time = knots(4);
        candidate.knots = knots;
        candidate.coeff = coeff;
    end

    % This also verifies all joins and the terminal jet before allowing a
    % constant terminal hold. A large endpoint mismatch is never concealed
    % by setting terminal derivatives to zero.
    [eval_rc, evaluated] = voi_correction_eval(candidate, t);
    if eval_rc ~= 0
        out = evaluated;
        return;
    end
    ctx = candidate;
    out = evaluated;
    rc = 0;
end

function out = correction_error(reason)
    out = struct('ready', false, 'transitioning', false, ...
        'position', NaN(3, 1), 'velocity', NaN(3, 1), 'acceleration', NaN(3, 1), ...
        'target', NaN(3, 1), 'knots', NaN(1, 4), 'coeff', NaN(3, 4, 3), ...
        'position_origin', NaN(3, 1), 'time_origin', NaN(1, 3), ...
        'time_scale', NaN(1, 3), 'correction_end', NaN, 'status', 'ERROR', ...
        'reason', reason, 'join_residual', NaN(3, 1), ...
        'endpoint_residual', NaN(3, 1), 'consistency_tolerance', NaN);
end
