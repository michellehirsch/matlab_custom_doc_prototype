function p = addgradient(ax, opts)
% addgradient  Add a gradient background to a plot.
%
% Fills the axes background with a smooth color gradient, creating a
% polished visual effect. The gradient is drawn as an interpolated
% patch behind all other plot objects.
%
% ## Input Arguments
%
% **ax** — Target axes. If omitted, uses the current axes (`gca`).
%
% **opts.TopColor** — Color at the top of the gradient. Specify as an
% RGB triplet `[R G B]` with values in the range `[0, 1]`. Default
% is a light gray `[0.95 0.95 0.95]`.
%
% **opts.BottomColor** — Color at the bottom of the gradient. Specify
% as an RGB triplet `[R G B]`. Default is a medium gray
% `[0.75 0.75 0.75]`.
%
% **opts.FaceAlpha** — Gradient transparency. Scalar in the range
% `[0, 1]` where `0` is fully transparent and `1` is fully opaque.
% Default is `1`.
%
% ## Output Arguments
%
% **p** — Handle to the patch object used to draw the gradient,
% returned as a `matlab.graphics.primitive.Patch`. Use this to further
% customize the gradient appearance after creation.
%
% ## Examples
%
% ### Basic gray gradient
%
% ```matlab
% plot(10*rand(1, 100))
% addgradient
% ```
%
% ![Basic gradient](images/basic_gradient.png)
%
% ### Custom colors with transparency
%
% ```matlab
% ax1 = subplot(2,1,1);
% plot(magic(3))
% ax2 = subplot(2,1,2);
% plot(10*rand(1,100));
% addgradient(ax1)
% p = addgradient(ax2, TopColor=[1 0 0], BottomColor=[0 1 0], ...
%     FaceAlpha=0.3);
% ```
%
% ## Tips
%
% - Add the gradient **after** setting final axis limits, since the
%   gradient patch is not automatically redrawn when limits change.
% - Use `FaceAlpha` to make the gradient subtle beneath dense data.
% - For a horizontal gradient, transpose the color assignments or
%   create a custom patch manually.
%
% > [!NOTE]
% > The gradient is placed at the bottom of the axes stacking order
% > using `uistack`, so it appears behind all other plot objects.
%
% See also patch, uistack, colormap

arguments
    ax          (1,1) matlab.graphics.axis.Axes = gca  % Target axes
    opts.TopColor    (1,3) double = [.95 .95 .95]      % Top gradient color (RGB)
    opts.BottomColor (1,3) double = [.75 .75 .75]      % Bottom gradient color (RGB)
    opts.FaceAlpha   (1,1) double {mustBeInRange( ...
                     opts.FaceAlpha,0,1)} = 1           % Gradient transparency
end

lim = axis(ax);
xdata = [lim(1) lim(2) lim(2) lim(1)];
ydata = [lim(3) lim(3) lim(4) lim(4)];
cdata(1,1,:) = opts.BottomColor;
cdata(1,2,:) = opts.BottomColor;
cdata(1,3,:) = opts.TopColor;
cdata(1,4,:) = opts.TopColor;

p = patch(xdata, ydata, 'k', 'Parent', ax);
set(p, 'CData', cdata, ...
    'FaceColor', 'interp', ...
    'EdgeColor', 'none', ...
    'FaceAlpha', opts.FaceAlpha);

uistack(p, 'bottom')
set(ax, 'Layer', 'top')
end
