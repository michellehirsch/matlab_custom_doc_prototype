function [m, ci] = weightedmean_v5_argdoc(x, w, dim, opts)
% weightedmean  Compute the weighted mean of an array.
%
% `M = weightedmean(X)` computes the arithmetic mean of the elements of
% `X`, using uniform weights.
%
% `M = weightedmean(X, W)` uses the weights in `W`.  `W` must be the
% same size as `X`.
%
% `M = weightedmean(X, W, DIM)` operates along dimension `DIM` instead
% of the default first non-singleton dimension.
%
% `[M, CI] = weightedmean(...)` also returns a confidence interval `CI`
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
    % Input data, specified as a vector, matrix, or N-D array.
    x        double                                                                                        % Input data

    % Weights, specified as an array the same size as `x`.  If omitted
    % or empty, uniform weights are used.  By default, weights are
    % normalized to sum to 1 along the operating dimension.
    w        double                                                         = []                            % Weights (same size as x)

    % Dimension to operate along, specified as a nonnegative integer.
    % `0` (default) uses the first non-singleton dimension.
    dim (1,1) double {mustBeNonnegative, mustBeInteger}                     = 0                             % Dimension (0 = auto)

    % Averaging method.  `"arithmetic"` (default) computes the standard
    % weighted mean, `"harmonic"` is appropriate for averaging rates or
    % ratios, and `"geometric"` is appropriate for growth factors.
    opts.Method     (1,1) string {mustBeMember(opts.Method, ["arithmetic", "harmonic", "geometric"])} = "arithmetic"  % Averaging method

    % NaN handling.  `"omitnan"` (default) excludes NaN values from the
    % computation; `"includenan"` propagates them.
    opts.NanFlag    (1,1) string {mustBeMember(opts.NanFlag, ["omitnan", "includenan"])}              = "omitnan"     % NaN handling

    % Normalize weights flag.  When `true` (default), weights are
    % normalized to sum to 1.  Set to `false` when your weights are
    % pre-normalized probabilities.
    opts.Normalize  (1,1) logical                                           = true                          % Normalize weights to sum to 1

    % Confidence level for the interval returned in the second output
    % `CI`.  Must be between 0 and 1.
    opts.Confidence (1,1) double {mustBeInRange(opts.Confidence, 0, 1)}     = 0.95                          % Confidence level for interval
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
