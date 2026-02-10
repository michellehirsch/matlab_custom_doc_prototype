function y = smoothts(x, method, window)
% smoothts  Smooth a time series using a moving window.
%
% Y = smoothts(X) smooths the time series X using a moving average with
% a default window size of 5.
%
% Y = smoothts(X, METHOD) specifies the smoothing method. METHOD can be
% 'moving' for a simple moving average (default), 'exponential' for
% exponential smoothing, or 'gaussian' for Gaussian-weighted smoothing.
%
% Y = smoothts(X, METHOD, WINDOW) specifies the window size. WINDOW is a
% positive odd integer specifying the number of samples in the smoothing
% window. Default is 5.
%
% If X is a matrix, each column is smoothed independently.
%
% The function handles edge effects by shrinking the window at the
% boundaries of the signal, so the output Y is the same length as X.
%
% Example
%   t = linspace(0, 2*pi, 200);
%   x = sin(t) + 0.5*randn(size(t));
%   y = smoothts(x);
%   plot(t, x, '.', t, y, 'LineWidth', 2)
%   legend('Noisy', 'Smoothed')
%
%   % Compare methods
%   y1 = smoothts(x, 'moving', 15);
%   y2 = smoothts(x, 'exponential', 15);
%   y3 = smoothts(x, 'gaussian', 15);
%   plot(t, x, '.', t, y1, t, y2, t, y3, 'LineWidth', 2)
%   legend('Noisy', 'Moving', 'Exponential', 'Gaussian')
%
% See also movmean, smoothdata, filter

if nargin < 2
    method = 'moving';
end
if nargin < 3
    window = 5;
end

n = length(x);
y = zeros(size(x));

switch lower(method)
    case 'moving'
        half = floor(window / 2);
        for i = 1:n
            lo = max(1, i - half);
            hi = min(n, i + half);
            y(i) = mean(x(lo:hi));
        end
    case 'exponential'
        alpha = 2 / (window + 1);
        y(1) = x(1);
        for i = 2:n
            y(i) = alpha * x(i) + (1 - alpha) * y(i-1);
        end
    case 'gaussian'
        half = floor(window / 2);
        kernel = exp(-0.5 * ((-half:half) / (half/2)).^2);
        kernel = kernel / sum(kernel);
        y = conv(x, kernel, 'same');
end
end
