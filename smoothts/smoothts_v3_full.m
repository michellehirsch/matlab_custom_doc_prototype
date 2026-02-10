function y = smoothts(x, opts)
% smoothts  Smooth a time series using a moving window.
%
% Applies a windowed smoothing operation to the input time series `x`.
% Three smoothing methods are available: simple moving average,
% exponential smoothing, and Gaussian-weighted smoothing.
%
% If `x` is a matrix, each column is smoothed independently.
%
% ## Syntax
%
% ```matlab
% y = smoothts(x)
% y = smoothts(x, Method=method)
% y = smoothts(x, Method=method, Window=w)
% y = smoothts(x, Method="gaussian", Window=w, Sigma=s)
% ```
%
% ## Input Arguments
%
% **x** — Input time series. Specify as a numeric vector or matrix.
% If `x` is a matrix, each column is treated as an independent time
% series and smoothed separately. `NaN` values are excluded from
% window calculations (nanmean behavior).
%
% **opts.Method** — Smoothing method. Specify as one of:
%
%   - `"moving"` *(default)* — Simple moving average. Each output
%     sample is the unweighted mean of the samples within the window.
%   - `"exponential"` — Exponential smoothing. Recent samples are
%     weighted more heavily using a decay factor derived from the
%     window size: $\alpha = 2 / (w + 1)$.
%   - `"gaussian"` — Gaussian-weighted smoothing. Samples are
%     weighted by a Gaussian kernel centered on the current sample.
%     The kernel width is controlled by `Sigma`.
%
% **opts.Window** — Window size. Specify as a positive odd integer.
% The window is centered on the current sample, extending
% `floor(Window/2)` samples in each direction. At signal boundaries,
% the window shrinks so that the output is the same length as the
% input. Default is `5`.
%
% **opts.Sigma** — Standard deviation of the Gaussian kernel, in
% samples. Only used when `Method` is `"gaussian"`. Default is
% `Window/4`, which places approximately 95% of the kernel weight
% within the window.
%
% ## Output Arguments
%
% **y** — Smoothed time series, returned as a numeric array the same
% size as `x`.
%
% ## Examples
%
% ### Smooth a noisy sine wave
%
% ```matlab
% t = linspace(0, 2*pi, 200);
% x = sin(t) + 0.5*randn(size(t));
% y = smoothts(x);
% plot(t, x, '.', t, y, 'LineWidth', 2)
% legend('Noisy', 'Smoothed')
% ```
%
% ### Compare smoothing methods
%
% ```matlab
% t = linspace(0, 2*pi, 200);
% x = sin(t) + 0.5*randn(size(t));
% y1 = smoothts(x, Method="moving", Window=15);
% y2 = smoothts(x, Method="exponential", Window=15);
% y3 = smoothts(x, Method="gaussian", Window=15);
% plot(t, x, '.', t, y1, t, y2, t, y3, 'LineWidth', 2)
% legend('Noisy', 'Moving', 'Exponential', 'Gaussian')
% ```
%
% ### Smooth columns of a matrix
%
% ```matlab
% data = cumsum(randn(100, 3));
% smoothed = smoothts(data, Window=11);
% plot(smoothed)
% ```
%
% ## Algorithms
%
% **Moving average.** The output at index $i$ is:
%
% $$y_i = \frac{1}{|W_i|} \sum_{j \in W_i} x_j$$
%
% where $W_i$ is the set of indices within the window centered on $i$.
%
% **Exponential smoothing.** Uses the recurrence:
%
% $$y_i = \alpha \, x_i + (1 - \alpha) \, y_{i-1}, \quad y_1 = x_1$$
%
% with smoothing factor $\alpha = 2 / (w + 1)$.
%
% **Gaussian smoothing.** Convolves the signal with a normalized Gaussian
% kernel $g$ of length `Window`:
%
% $$g_k = \frac{1}{Z} \exp\!\left(-\frac{k^2}{2\sigma^2}\right)$$
%
% where $Z$ is the normalizing constant ensuring $\sum g_k = 1$.
%
% ## Tips
%
% - Increasing `Window` produces smoother output but introduces more lag
%   and reduces sensitivity to rapid changes.
% - For real-time or streaming applications, `"exponential"` is the most
%   efficient method since it requires only the previous output value.
% - To smooth irregularly sampled data, consider resampling to a uniform
%   grid first with `resample` or `interp1`.
%
% > [!NOTE]
% > Edge effects are handled by shrinking the window at signal
% > boundaries. This avoids padding artifacts but means the first
% > and last few samples are smoothed with fewer points.
%
% ## References
%
% 1. Hyndman, R.J. & Athanasopoulos, G. (2021). _Forecasting:
%    Principles and Practice_, 3rd ed., OTexts.
%    [https://otexts.com/fpp3/](https://otexts.com/fpp3/)
%
% 2. Smith, S.W. (1997). _The Scientist and Engineer's Guide to
%    Digital Signal Processing_, Ch. 15: Moving Average Filters.
%
% See also movmean, smoothdata, filter

arguments
    x               (:,:) double         % Input time series
    opts.Method     (1,1) string ...
                    {mustBeMember(opts.Method, ...
                    ["moving","exponential","gaussian"])} ...
                                = "moving"    % Smoothing method
    opts.Window     (1,1) double ...
                    {mustBePositive, mustBeInteger, ...
                    mustBeOdd} = 5            % Window size (odd integer)
    opts.Sigma      (1,1) double ...
                    {mustBePositive} = NaN    % Gaussian kernel sigma
end

% Default sigma based on window
if isnan(opts.Sigma)
    opts.Sigma = opts.Window / 4;
end

[nRows, nCols] = size(x);
y = zeros(size(x));
half = floor(opts.Window / 2);

for col = 1:nCols
    switch opts.Method
        case "moving"
            for i = 1:nRows
                lo = max(1, i - half);
                hi = min(nRows, i + half);
                y(i, col) = mean(x(lo:hi, col), 'omitnan');
            end
        case "exponential"
            alpha = 2 / (opts.Window + 1);
            y(1, col) = x(1, col);
            for i = 2:nRows
                y(i, col) = alpha * x(i, col) + (1 - alpha) * y(i-1, col);
            end
        case "gaussian"
            kernel = exp(-0.5 * ((-half:half) / opts.Sigma).^2);
            kernel = kernel / sum(kernel);
            y(:, col) = conv(x(:, col), kernel, 'same');
    end
end
end
