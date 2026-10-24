function [rc, out] = voi_correction_eval(ctx, t)
%VOI_CORRECTION_EVAL Read a correction signal without changing its context.
%   Queries may precede last_tick, but never start_time of the retained
%   transition. Future evaluation is mathematical evaluation of the current
%   plan; it does not assert that no later accepted point will replace it.
%
%   coeff(:,:,i) describes displacement from position_origin in powers of
%   z=(t-time_origin(i))/time_scale(i). time_scale contains actual seconds.
%   The first two output derivatives describe the correction signal, not
%   the physical velocity and acceleration of the stationary target.
%
%   Consistency is checked in LOCAL metres: residuals contain position,
%   velocity*total_duration, acceleration*total_duration^2. The tolerance
%   is 512*eps(max(1,max(abs(target-position_origin)))); it is independent
%   of global coordinate magnitude and is not a measurement-accuracy claim.

    rc = 1;
    out = correction_error('INVALID_API');
    if nargin ~= 2
        return;
    end
    if ~isa(t, 'double') || ~isreal(t) || ~isscalar(t) || ~isfinite(t)
        out.reason = 'INVALID_TIME';
        return;
    end
    fields = {'schema_version', 'H', 'last_tick', 'ready', 'target', ...
              'start_time', 'end_time', 'knots', 'position_origin', 'coeff'};
    if ~isstruct(ctx) || ~isscalar(ctx) || ~all(isfield(ctx, fields))
        out.reason = 'INVALID_CONTEXT';
        return;
    end
    if ~finite_scalar(ctx.schema_version) || ctx.schema_version ~= 1 || ...
       ~finite_scalar(ctx.H) || ctx.H <= 0 || ...
       ~finite_scalar(ctx.last_tick) || ~finite_scalar(ctx.start_time) || ...
       ~finite_scalar(ctx.end_time) || ctx.end_time < ctx.start_time || ...
       ctx.last_tick < ctx.start_time || ...
       ~islogical(ctx.ready) || ~isscalar(ctx.ready) || ...
       ~real_shape(ctx.target, [3, 1]) || ...
       ~real_shape(ctx.position_origin, [3, 1]) || ...
       ~real_shape(ctx.knots, [1, 4]) || any(~isfinite(ctx.knots)) || ...
       ~real_shape(ctx.coeff, [3, 4, 3]) || ...
       ctx.knots(1) ~= ctx.start_time || ctx.knots(4) ~= ctx.end_time
        out.reason = 'INVALID_CONTEXT';
        return;
    end
    if t < ctx.start_time
        out.reason = 'TIME_BEFORE_TRANSITION';
        return;
    end
    if ~ctx.ready
        if ~all(isnan(ctx.target)) || ~all(isnan(ctx.position_origin)) || ...
           ~all(isnan(ctx.coeff(:))) || any(ctx.knots ~= ctx.start_time)
            out.reason = 'INVALID_CONTEXT';
            return;
        end
        out = copy_representation(out, ctx);
        out.status = 'UNAVAILABLE';
        out.reason = 'NO_TARGET';
        rc = 0;
        return;
    end
    if any(~isfinite(ctx.target)) || any(~isfinite(ctx.position_origin)) || ...
       any(~isfinite(ctx.coeff(:)))
        out.reason = 'INVALID_CONTEXT';
        return;
    end

    widths = diff(ctx.knots);
    if ctx.end_time == ctx.start_time
        if any(ctx.knots ~= ctx.start_time) || ...
           ~isequal(ctx.position_origin, ctx.target) || any(ctx.coeff(:) ~= 0)
            out.reason = 'INVALID_CONTEXT';
            return;
        end
        join_error = zeros(3, 1);
        endpoint_error = zeros(3, 1);
        tolerance = 512 * eps(1);
    else
        duration = ctx.end_time - ctx.start_time;
        if any(~isfinite(widths)) || any(widths <= 0) || ...
           ~isfinite(duration) || duration <= 0 || ...
           ctx.end_time ~= ctx.start_time + ctx.H || ...
           any(ctx.coeff(:, 1, 1) ~= 0)
            out.reason = 'INVALID_CONTEXT';
            return;
        end
        delta = ctx.target - ctx.position_origin;
        if any(~isfinite(delta))
            out.reason = 'NUMERIC_FAILURE';
            return;
        end
        tolerance = 512 * eps(max(1, max(abs(delta))));
        join_error = zeros(3, 1);
        endpoint_error = zeros(3, 1);
        for i = 1:3
            c = ctx.coeff(:, :, i);
            ratio = duration / widths(i);
            finish = ((c(:, 4) + c(:, 3)) + c(:, 2)) + c(:, 1);
            finish_v = (c(:, 2) + 2 * c(:, 3) + 3 * c(:, 4)) * ratio;
            finish_a = (2 * c(:, 3) + 6 * c(:, 4)) * ratio * ratio;
            % Finite polynomial coefficients alone do not guarantee finite
            % derivatives when a supplied duration is extremely small.
            v_coeff = [c(:, 2) / widths(i), ...
                       2 * (c(:, 3) / widths(i)), 3 * (c(:, 4) / widths(i))];
            a_coeff = [2 * ((c(:, 3) / widths(i)) / widths(i)), ...
                       6 * ((c(:, 4) / widths(i)) / widths(i))];
            if any(~isfinite(finish)) || any(~isfinite(finish_v)) || ...
               any(~isfinite(finish_a)) || any(~isfinite(v_coeff(:))) || ...
               any(~isfinite(a_coeff(:)))
                out.reason = 'NUMERIC_FAILURE';
                return;
            end
            if i < 3
                next = ctx.coeff(:, :, i + 1);
                next_ratio = duration / widths(i + 1);
                start_v = next(:, 2) * next_ratio;
                start_a = 2 * next(:, 3) * next_ratio * next_ratio;
                join_error = max(join_error, ...
                    [max(abs(finish - next(:, 1))); ...
                     max(abs(finish_v - start_v)); max(abs(finish_a - start_a))]);
            else
                endpoint_error = [max(abs(finish - delta)); ...
                                  max(abs(finish_v)); max(abs(finish_a))];
            end
        end
        if any(~isfinite(join_error)) || any(~isfinite(endpoint_error))
            out.reason = 'NUMERIC_FAILURE';
            return;
        end
        if any(join_error > tolerance)
            out.reason = 'JOIN_RESIDUAL';
            return;
        end
        if any(endpoint_error > tolerance)
            out.reason = 'ENDPOINT_RESIDUAL';
            return;
        end
    end

    out = copy_representation(out, ctx);
    out.ready = true;
    out.join_residual = join_error;
    out.endpoint_residual = endpoint_error;
    out.consistency_tolerance = tolerance;
    if t >= ctx.end_time
        % Only roundoff-sized endpoint residues may reach this branch;
        % substantial mismatch was rejected before terminal holding.
        out.position = ctx.target;
        out.velocity = zeros(3, 1);
        out.acceleration = zeros(3, 1);
        out.status = 'HOLD_TARGET';
    else
        piece = 1 + (t >= ctx.knots(2)) + (t >= ctx.knots(3));
        width = widths(piece);
        z = (t - ctx.knots(piece)) / width;
        c = ctx.coeff(:, :, piece);
        local_position = ((c(:, 4) * z + c(:, 3)) * z + c(:, 2)) * z + c(:, 1);
        velocity = ((3 * (c(:, 4) / width)) * z + 2 * (c(:, 3) / width)) * z ...
                   + c(:, 2) / width;
        acceleration = (6 * ((c(:, 4) / width) / width)) * z ...
                       + 2 * ((c(:, 3) / width) / width);
        position = ctx.position_origin + local_position;
        if any(~isfinite(position)) || any(~isfinite(velocity)) || ...
           any(~isfinite(acceleration))
            out = correction_error('NUMERIC_FAILURE');
            return;
        end
        out.position = position;
        out.velocity = velocity;
        out.acceleration = acceleration;
        out.transitioning = true;
        out.status = 'TRANSITIONING';
    end
    out.reason = 'OK';
    rc = 0;
end

function result = finite_scalar(value)
    result = isa(value, 'double') && isreal(value) && isscalar(value) && isfinite(value);
end

function result = real_shape(value, shape)
    result = isa(value, 'double') && isreal(value) && isequal(size(value), shape);
end

function out = copy_representation(out, ctx)
    out.target = ctx.target;
    out.knots = ctx.knots;
    out.coeff = ctx.coeff;
    out.position_origin = ctx.position_origin;
    out.time_origin = ctx.knots(1:3);
    out.time_scale = diff(ctx.knots);
    out.correction_end = ctx.end_time;
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
