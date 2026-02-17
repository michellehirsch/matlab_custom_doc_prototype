function [m, ci] = weightedmean(x, w, dim, opts)
% weightedmean  Compute the weighted mean of an array.
%
% M = weightedmean(X) computes the arithmetic mean of the elements of X,
% using uniform weights.
%
% M = weightedmean(X, W) uses the weights in W.  W must be the same size
% as X.
%
% M = weightedmean(X, W, DIM) operates along dimension DIM instead of
% the default first non-singleton dimension.
%
% [M, CI] = weightedmean(...) also returns a confidence interval CI
% based on the weighted standard deviation.
%
% X is the input data.  It can be a vector, matrix, or N-D array of type
% double.
%
% W specifies the weights and must be the same size as X.  If omitted or
% empty, uniform weights are used.  By default, weights are normalized to
% sum to 1 along the operating dimension.
%
% DIM is the dimension to operate along.  Must be a nonnegative integer.
% 0 (default) uses the first non-singleton dimension.
%
% Method controls the type of mean:  "arithmetic" (default), "harmonic",
% or "geometric".
%
% NanFlag controls how NaN values are treated:  "omitnan" (default)
% excludes them, "includenan" propagates them.
%
% Normalize is a logical flag controlling whether weights are normalized
% to sum to 1.  Default is true.
%
% Confidence sets the confidence level for the interval returned in CI.
% Must be between 0 and 1.  Default is 0.95.
%
% Example
%   x = [4 7 3 9 1];
%   m = weightedmean(x)
%   m = weightedmean(x, [1 2 1 2 1])
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
