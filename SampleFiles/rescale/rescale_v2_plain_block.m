function y = rescale(x, a, b)
%{
rescale  Rescale data to a specified range.

Y = rescale(X) rescales the elements of X to the range [0, 1]. The
minimum value of X maps to 0 and the maximum maps to 1.

Y = rescale(X, A, B) rescales to the range [A, B].

X can be a vector, matrix, or N-D array of type double.  A and B are
scalar double values specifying the lower and upper bounds of the
target range.  If omitted, A defaults to 0 and B defaults to 1.

Example
  x = [1 2 3 4 5];
  y = rescale(x)            % returns [0 0.25 0.5 0.75 1]
  y = rescale(x, -1, 1)    % returns [-1 -0.5 0 0.5 1]

See also normalize, mapminmax
%}

arguments
    x        double              % Input data array
    a (1,1)  double = 0          % Lower bound of target range
    b (1,1)  double = 1          % Upper bound of target range
end
y = a + (x - min(x(:))) ./ (max(x(:)) - min(x(:))) * (b - a);
end
