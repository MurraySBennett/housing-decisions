function roundRect(window, rect, radius, fillColour, edgeColour, edgeWidth)
%UTILS.ROUNDRECT  Rounded panel: one call replaces FillRect + FrameRect.
%
%   utils.roundRect(win, rect, r, fill)
%   utils.roundRect(win, rect, r, fill, edge, edgeWidth)
%
%   `rect` is [left top right bottom], row or column, integer or not.
%   `radius` is clamped to floor(min(w,h)/2).
%
%   ROLLBACK. radius < 1 falls through to a plain Screen('FillRect'), so
%   setting every radius token in utils.style to 0 restores the previous
%   square output without touching a single call site. That is the
%   shape-only rollback lever; see the theme switch in utils.style for the
%   coarser one.
%
%   FRAMES ARE TWO NESTED FILLS, not a stroked outline: the outer rounded
%   rect in the edge colour, the inner one inset by edgeWidth in the fill
%   colour, with inner radius = outer radius - edgeWidth. That is the
%   correct concentric-curvature rule, it leaves no seam where a straight
%   edge meets a corner, and it collapses the FillRect + FrameRect pair
%   this codebase uses everywhere into one call.
%
%   STROKE PLACEMENT DIFFERS FROM Screen('FrameRect'). FrameRect centres
%   its stroke on the rect boundary (glLineWidth semantics), so a 4 px
%   frame spills 2 px outside the rect. This function strokes strictly
%   INSIDE. That is deliberate: these rects sit next to AOIs and a stroke
%   must never encroach on a neighbouring AOI's pixels. Expect frames to
%   sit 1-2 px further in than they used to. Nothing measures those pixels
%   and no AOI is defined by them.
%
%   OPACITY CONTRACT. The shape is drawn as a union of two rects and four
%   ovals, which overlap at the corners. Overlapping pixels are painted
%   twice -- invisible for opaque colours, WRONG for translucent ones. So
%   every colour passed here must be opaque: 3 elements, or 4 with alpha
%   == 1. The debug gaze dot is the only translucent colour in the
%   codebase and it is a DrawDots call that never comes through here.
%
%   ANTIALIASING. Screen('FillOval') is a tessellated GL disk and is not
%   antialiased unless the window was opened with multisampling, which it
%   is not. Corners are therefore very slightly stepped. At the
%   panel-to-ground contrast used by either theme a one-pixel step is
%   roughly one LSB of luminance and is not visible at the rig's viewing
%   distance. Multisampling is a positional argument on OpenWindow and a
%   mistake there is a hard startup failure with a participant in the
%   chair -- do not add it to fix something this small.
%
%   The Screen('BlendFunction', win, 'GL_SRC_ALPHA',
%   'GL_ONE_MINUS_SRC_ALPHA') already set at auction_task.m and
%   continuous_DC_task.m is required and must not be changed.
%
%   See also UTILS.STYLE.

if nargin < 5, edgeColour = []; end
if nargin < 6 || isempty(edgeWidth), edgeWidth = 0; end

rect = double(rect(:))';
if numel(rect) ~= 4 || ~all(isfinite(rect)), return; end

w = rect(3) - rect(1);
h = rect(4) - rect(2);
if w <= 0 || h <= 0, return; end

radius = max(0, min([radius, floor(w/2), floor(h/2)]));

if edgeWidth > 0 && ~isempty(edgeColour)
    edgeWidth = min(edgeWidth, floor(min(w, h) / 2));
    solid(window, rect, radius, edgeColour);
    inner = [rect(1) + edgeWidth, rect(2) + edgeWidth, ...
             rect(3) - edgeWidth, rect(4) - edgeWidth];
    solid(window, inner, radius - edgeWidth, fillColour);
else
    solid(window, rect, radius, fillColour);
end

end


%% ======================================================================
function solid(window, rect, r, colour)
%SOLID  One filled rounded rectangle: two crossed bars plus four discs.
%
%   The union of these six shapes is exactly the rounded rectangle: a bar
%   spanning the full height inset by r horizontally, a bar spanning the
%   full width inset by r vertically, and a disc of radius r centred at
%   each inset corner.

if isempty(colour), return; end

w = rect(3) - rect(1);
h = rect(4) - rect(2);
if w <= 0 || h <= 0, return; end

r = max(0, min([r, floor(w/2), floor(h/2)]));
if r < 1
    Screen('FillRect', window, colour, rect);
    return
end

l = rect(1); t = rect(2); rr = rect(3); b = rect(4);
d = 2 * r;

Screen('FillRect', window, colour, [l + r,  t,      rr - r, b      ]);
Screen('FillRect', window, colour, [l,      t + r,  rr,     b - r  ]);
Screen('FillOval', window, colour, [l,      t,      l + d,  t + d  ]);
Screen('FillOval', window, colour, [rr - d, t,      rr,     t + d  ]);
Screen('FillOval', window, colour, [l,      b - d,  l + d,  b      ]);
Screen('FillOval', window, colour, [rr - d, b - d,  rr,     b      ]);

end
