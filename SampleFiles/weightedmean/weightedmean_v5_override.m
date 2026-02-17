function [m, ci] = weightedmean(x, w, dim, opts)
% weightedmean  Compute the weighted mean of an array.
%
% Computes the mean of the elements of an array, optionally weighted,
% along a specified dimension.  Supports arithmetic, harmonic, and
% geometric means.
%
% ## Syntax
%
% `m = weightedmean(x)` computes the arithmetic mean of the elements of
% `x`, using uniform weights.
%
% `m = weightedmean(x, w)` uses the weights in `w`.  `w` must be the
% same size as `x`.
%
% `m = weightedmean(x, w, dim)` operates along dimension `dim` instead
% of the default first non-singleton dimension.
%
% `m = weightedmean(x, Method="harmonic")` computes the harmonic mean,
% which is appropriate when averaging rates or ratios.
%
% `___ = weightedmean(___, Name=Value)` specifies options using one or
% more name-value arguments.  For example,
% `weightedmean(x, Normalize=false)` skips weight normalization.
%
% `[m, ci] = weightedmean(___)` also returns a confidence interval `ci`
% based on the weighted standard deviation.
%
% ## Examples
%
% ### Basic weighted mean
%
% ```matlab
% x = [4 7 3 9 1];
% m = weightedmean(x)                       % uniform: 4.8
% m = weightedmean(x, [1 2 1 2 1])          % weighted: 5.7143
% ```
%
% ### Harmonic mean for averaging rates
%
% ```matlab
% speeds = [60 40];                               % km/h out and back
% avg = weightedmean(speeds, Method="harmonic")   % 48 km/h
% ```
%
% ## Tips
%
% - Use `Method="harmonic"` when averaging rates or ratios (e.g., speeds
%   or prices per unit).
% - Set `Normalize=false` when your weights are pre-normalized
%   probabilities.
% - The confidence interval assumes approximately normal data.  For
%   skewed distributions, consider bootstrap methods instead.
%
% See also mean, sum

arguments
    x        double                                                                                                   % Input data
    w        double                                                         = []                                      % Weights (same size as x)
    dim (1,1) double {mustBeNonnegative, mustBeInteger}                     = 0                                       % Dimension (0 = auto)
    opts.Method     (1,1) string {mustBeMember(opts.Method, ["arithmetic", "harmonic", "geometric"])} = "arithmetic"  % Averaging method
    opts.NanFlag    (1,1) string {mustBeMember(opts.NanFlag, ["omitnan", "includenan"])}              = "omitnan"     % NaN handling
    opts.Normalize  (1,1) logical                                           = true                                    % Normalize weights to sum to 1
    opts.Confidence (1,1) double {mustBeInRange(opts.Confidence, 0, 1)}     = 0.95                                    % Confidence level for interval
end

% Resolve dimension: 0 means first non-singleton (like mean)
if dim == 0
    dim = find(size(x) > 1, 1, "first");
    if isempty(dim), dim = 1; end
end

% Default to uniform weights
if isempty(w)
    w = ones(size(x));
end

% Normalize weights along operating dimension
if opts.Normalize
    w = w ./ sum(w, dim, opts.NanFlag);
end

% Compute weighted mean
switch opts.Method
    case "arithmetic"
        m = sum(w .* x, dim, opts.NanFlag);
    case "harmonic"
        m = 1 ./ sum(w ./ x, dim, opts.NanFlag);
    case "geometric"
        m = exp(sum(w .* log(x), dim, opts.NanFlag));
end

% Confidence interval from weighted standard deviation
if nargout > 1
    wsd = sqrt(sum(w .* (x - m).^2, dim, opts.NanFlag));
    z = sqrt(2) * erfinv(opts.Confidence);
    ci = cat(dim, m - z * wsd, m + z * wsd);
end

end
