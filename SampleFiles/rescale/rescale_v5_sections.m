function y = rescale_v5_sections(x, a, b)
% rescale  Rescale data to a specified range.
%
% Linearly rescales the elements of `x` so that they span the target
% range $[a, b]$. The minimum value of `x` maps to `a` and the maximum
% maps to `b`. Values between are linearly interpolated.
%
% ## Output Arguments
%
% `y` — Rescaled data, returned as an array the same size as `x`
% with values in the range $[a, b]$.
%
% ## Examples
%
% ### Rescale to default range [0, 1]
%
% ```matlab
% x = [1 2 3 4 5];
% y = rescale(x)
% ```
%
% ### Rescale to a custom range
%
% ```matlab
% x = [1 2 3 4 5];
% y = rescale(x, -1, 1)
% ```
%
% ### Rescale columns of a matrix independently
%
% ```matlab
% M = rand(5, 3) * 100;
% Y = zeros(size(M));
% for k = 1:size(M, 2)
%     Y(:,k) = rescale(M(:,k));
% end
% ```
%
% ## Tips
%
% - For data with outliers, consider clipping before rescaling:
%   `x = max(min(x, upper), lower)` before calling `rescale`.
% - To rescale each column of a matrix independently, loop over
%   columns or use `normalize(x, 'range')` from Statistics and
%   Machine Learning Toolbox.
%
% ## Algorithms
%
% The transformation applied is:
%
% $$y = a + \frac{x - \min(x)}{\max(x) - \min(x)} \cdot (b - a)$$
%
% This is a standard affine rescaling (min-max normalization).
%
% See also normalize, mapminmax

arguments
    % Input data, specified as a vector, matrix, or N-D array. All
    % elements participate in determining the min and max used for
    % scaling. If all elements of `x` are equal, the output contains
    % `NaN` values due to division by zero; consider adding a guard if
    % this case may arise.
    x        double              % Input data array

    % Lower bound of the target range.
    a (1,1)  double = 0          % Lower bound of target range

    % Upper bound of the target range. If `b < a`, the output is
    % reversed (maximum of `x` maps to `a`).
    b (1,1)  double = 1          % Upper bound of target range
end
y = a + (x - min(x(:))) ./ (max(x(:)) - min(x(:))) * (b - a);
end
