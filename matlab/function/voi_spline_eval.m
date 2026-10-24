function [position, velocity, acceleration] = voi_spline_eval(coeff, time_origin, tau)
%VOI_SPLINE_EVAL Evaluate a vector cubic and its first two derivatives.
%   coeff is a finite real double 3-by-4 matrix in ascending powers of
%   (tau-time_origin): constant, linear, quadratic, cubic. tau may be a
%   scalar, row vector, or column vector. Outputs are 3-by-numel(tau).
%   This function performs polynomial arithmetic only. It does not choose
%   a validity interval, an extrapolation policy, or any target dynamics.

    if nargin ~= 3 || ~isa(coeff, 'double') || ~isreal(coeff) || ...
       ~isequal(size(coeff), [3, 4]) || any(~isfinite(coeff(:))) || ...
       ~isa(time_origin, 'double') || ~isreal(time_origin) || ...
       ~isscalar(time_origin) || ~isfinite(time_origin) || ...
       ~isa(tau, 'double') || ~isreal(tau) || ~isvector(tau) || ...
       isempty(tau) || any(~isfinite(tau(:)))
        error('voi_spline_eval:InvalidInput', ...
              'Expected finite real double coeff(3,4), scalar time_origin, and nonempty vector tau.');
    end
    dt = reshape(tau, 1, []) - time_origin;
    if any(~isfinite(dt))
        error('voi_spline_eval:NumericFailure', 'The time offset is not representable.');
    end
    cubic_dt = bsxfun(@times, coeff(:, 4), dt);
    position = bsxfun(@plus, cubic_dt, coeff(:, 3));
    position = bsxfun(@plus, bsxfun(@times, position, dt), coeff(:, 2));
    position = bsxfun(@plus, bsxfun(@times, position, dt), coeff(:, 1));
    velocity = bsxfun(@plus, 3 * cubic_dt, 2 * coeff(:, 3));
    velocity = bsxfun(@plus, bsxfun(@times, velocity, dt), coeff(:, 2));
    acceleration = bsxfun(@plus, 6 * cubic_dt, 2 * coeff(:, 3));
    if any(~isfinite(position(:))) || any(~isfinite(velocity(:))) || ...
       any(~isfinite(acceleration(:)))
        error('voi_spline_eval:NumericFailure', 'Polynomial evaluation overflowed.');
    end
end
