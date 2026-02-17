function y = rescale(x, a, b)
arguments
    x        double              % Input data array
    a (1,1)  double = 0          % Lower bound of target range
    b (1,1)  double = 1          % Upper bound of target range
end
y = a + (x - min(x(:))) ./ (max(x(:)) - min(x(:))) * (b - a);
end
