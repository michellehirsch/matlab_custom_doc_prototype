function M = mean(A, dim, opts)
% mean  Average or mean value.
%
% Computes the mean of the elements of an array along a specified
% dimension, with options for weighted averaging, output type control,
% and missing-value handling.
%
% ## Syntax
%
% `M = mean(A)` returns the mean along the first dimension whose size
% does not equal 1.
%
% `M = mean(A, dim)` returns the mean along dimension `dim`.
%
% `M = mean(A, dim, OutType=t)` specifies the output data type.
%
% `M = mean(A, dim, Weights=W)` computes a weighted mean.
%
% ## Output Arguments
%
% `M` — Mean values, returned as a scalar, vector, matrix, or
% multidimensional array.  The size of `M` is the same as `A` except
% along the operating dimension, where it is 1.  For example, if `A` is
% a 3-by-4 matrix and `dim` is 1, then `M` is a 1-by-4 row vector of
% column means.
%
% ## Examples
%
% ### Column means of a matrix
%
% ```matlab
% A = magic(4);
% M = mean(A)
% ```
%
% ### Row means
%
% ```matlab
% A = magic(4);
% M = mean(A, 2)
% ```
%
% ### Weighted mean
%
% ```matlab
% x = [3 5 7 9];
% w = [1 2 2 1];
% M = mean(x, Weights=w)     % 5.6667
% ```
%
% ### Single-precision output
%
% ```matlab
% A = magic(4);
% M = mean(A, OutType="single")
% class(M)   % 'single'
% ```
%
% ## Algorithms
%
% **Unweighted mean:**
%
% $$M = \frac{1}{N}\sum_{i=1}^{N} A_i$$
%
% **Weighted mean:**
%
% $$M_w = \frac{\sum_{i=1}^{N} w_i \, A_i}{\sum_{i=1}^{N} w_i}$$
%
% ## Tips
%
% - For integer input, the default output type is `double`.  Use
%   `OutType="native"` to keep the result in the original integer type,
%   but be aware of overflow and limited precision for large sums.
% - When `MissingFlag` is `"omitmissing"` and all values along the
%   operating dimension are `NaN`, the result is `NaN`.
% - `Weights` are not required to sum to 1; the function normalizes
%   them internally.
%
% See also median, sum, var

arguments
    % Input array, specified as a vector, matrix, or multidimensional
    % array.  `A` can be of any numeric type (`single`, `double`,
    % `int8` through `int64`, `uint8` through `uint32`), or `logical`.
    % For scalar input, `mean` returns the value itself.  For an empty
    % 0-by-0 input, `mean` returns `NaN`.  If `A` is a matrix, `mean`
    % treats the columns as vectors and returns a row vector of column
    % means.  If `A` is a multidimensional array, `mean` operates along
    % the first array dimension whose size does not equal 1.
    A               double                                    % Input array

    % Dimension to operate along, specified as a positive integer
    % scalar.  If `dim` is 1, `mean` returns a row vector containing
    % the mean of each column.  If `dim` is 2, `mean` returns a column
    % vector containing the mean of each row.  If `dim` is greater than
    % `ndims(A)`, or if `size(A, dim)` is 1, then `mean` returns `A`
    % itself because there is only one element along that dimension and
    % the mean of a single element is the element.
    %
    % For a multidimensional array, choosing the correct `dim` is
    % essential: for a 4-D array of size 2-by-3-by-4-by-5, setting
    % `dim = 3` produces a 2-by-3-by-1-by-5 result.
    dim      (1,1)  double {mustBePositive, mustBeInteger} = 1 % Dimension to operate along

    % Output data type, specified as `"default"`, `"double"`, or
    % `"native"`.
    %
    %   - `"default"` — The output is `double` unless the input is
    %     `single`, in which case the output is `single`.  This is the
    %     most common choice and avoids precision loss for integer
    %     inputs.
    %   - `"double"` — The output is always `double`, regardless of
    %     input type.
    %   - `"native"` — The output has the same data type as the input.
    %     For `logical` input the output is `double`.  Use with caution
    %     for integer types because large sums can overflow the integer
    %     range.
    opts.OutType    (1,1) string ...
                    {mustBeMember(opts.OutType, ...
                    ["default","double","native"])} ...
                                = "default"                    % Output data type

    % Missing-value treatment, specified as `"includemissing"` or
    % `"omitmissing"`.
    %
    %   - `"includemissing"` *(default)* — `NaN` values in the input
    %     propagate to the output.  Any window that contains at least
    %     one `NaN` produces a `NaN` result.
    %   - `"omitmissing"` — `NaN` values are excluded before computing
    %     the mean.  The denominator is reduced accordingly so that the
    %     result reflects only the non-missing data.  If every element
    %     along the operating dimension is `NaN`, the result is `NaN`.
    %
    % For `datetime` inputs, missing values are `NaT` rather than
    % `NaN`, and the equivalent flags are `"includenat"` /
    % `"omitnat"`.
    opts.MissingFlag (1,1) string ...
                    {mustBeMember(opts.MissingFlag, ...
                    ["includemissing","omitmissing"])} ...
                                = "includemissing"             % Missing-value handling

    % Weights, specified as a numeric vector, matrix, or
    % multidimensional array of nonnegative values.  When `Weights` is
    % a vector, its length must match `size(A, dim)` — the number of
    % elements along the operating dimension.  When `Weights` is an
    % array, its size must match `size(A)`.  Elements with larger
    % weights contribute more to the mean.  Weights do not need to sum
    % to 1; the function normalizes internally by dividing by
    % `sum(W)`.  Zero-weight elements are effectively excluded from the
    % average.  If `Weights` is empty (the default), a standard
    % unweighted mean is computed.
    opts.Weights    double {mustBeNonnegative} = []             % Weighting scheme
end

% --- Compute ---------------------------------------------------------

[nRows, nCols] = size(A);

% Handle weights
if isempty(opts.Weights)
    w = ones(size(A));
else
    w = opts.Weights;
end

% Mask NaN if requested
if opts.MissingFlag == "omitmissing"
    mask = ~isnan(A);
    A(~mask) = 0;
    w = w .* mask;
end

% Weighted mean
wsum = sum(w .* A, dim);
M = wsum ./ sum(w, dim);

% Cast output type
switch opts.OutType
    case "double"
        M = double(M);
    case "native"
        M = cast(M, "like", A);
end

end
