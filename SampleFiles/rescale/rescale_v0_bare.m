function y = rescale_v0_bare(x, a, b)
arguments
    x        double
    a (1,1)  double = 0
    b (1,1)  double = 1
end
y = a + (x - min(x(:))) ./ (max(x(:)) - min(x(:))) * (b - a);
end
