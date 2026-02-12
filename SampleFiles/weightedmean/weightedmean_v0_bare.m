function [m, ci] = weightedmean(x, w, dim, opts)

arguments
    x        double
    w        double                                                         = []
    dim (1,1) double {mustBeNonnegative, mustBeInteger}                     = 0
    opts.Method     (1,1) string {mustBeMember(opts.Method, ["arithmetic", "harmonic", "geometric"])} = "arithmetic"
    opts.NanFlag    (1,1) string {mustBeMember(opts.NanFlag, ["omitnan", "includenan"])}              = "omitnan"
    opts.Normalize  (1,1) logical                                           = true
    opts.Confidence (1,1) double {mustBeInRange(opts.Confidence, 0, 1)}     = 0.95
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
