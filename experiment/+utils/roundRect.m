function roundRect(window, rect, radius, fillColour, edgeColour, edgeWidth)
%UTILS.ROUNDRECT  Rounded panel: one call replaces FillRect + FrameRect.
%
%   utils.roundRect(win, rect, r, fill, edge, edgeWidth)
%   rect is [left top right bottom]; radius clamped to floor(min(w,h)/2).
%
% Corner shapes overlap, so every colour must be opaque (3 elements, or alpha == 1).
% Requires the GL_SRC_ALPHA blend function set in the task scripts; must not be changed.
% Corners are slightly stepped; do not add multisampling to OpenWindow to fix it.

if nargin < 5, edgeColour = []; end
if nargin < 6 || isempty(edgeWidth), edgeWidth = 0; end

rect = double(rect(:))';
if numel(rect) ~= 4 || ~all(isfinite(rect)), return; end

w = rect(3) - rect(1);
h = rect(4) - rect(2);
if w <= 0 || h <= 0, return; end

radius = max(0, min([radius, floor(w/2), floor(h/2)]));

% Frame is two nested fills (inner radius = outer - edgeWidth); stroke sits strictly inside, unlike FrameRect's centred stroke, so it never encroaches on a neighbouring AOI.
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

if isempty(colour), return; end

w = rect(3) - rect(1);
h = rect(4) - rect(2);
if w <= 0 || h <= 0, return; end

r = max(0, min([r, floor(w/2), floor(h/2)]));
% radius < 1 falls back to plain FillRect: setting style radii to 0 is the shape-only rollback lever.
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
