function [mx, my, buttons] = getMouse(window)
%UTILS.GETMOUSE  Robust cursor query -- works around a real Windows/PTB issue.
%
%   [mx, my, buttons] = utils.getMouse(window)
%   On Windows GetMouse(window) can return NaN without throwing; validate
%   the result and fall back to the desktop-global query.

[mx, my, buttons] = localGetMouse(window);
if isfinite(mx) && isfinite(my)
    return
end

% Global query bypasses the window's OpenGL context; returns virtual-desktop coords.
[mx, my, buttons] = GetMouse();
try
    gr = Screen('GlobalRect', window);   % [left top right bottom] in desktop coords
    mx = mx - gr(1);
    my = my - gr(2);
catch
    % GlobalRect failure implies fullscreen at origin; global coords already correct.
end

% Last resort: return the window centre rather than propagate NaN into Screen calls.
if ~isfinite(mx) || ~isfinite(my)
    r = Screen('Rect', window);
    if ~isfinite(mx), mx = r(3)/2; end
    if ~isfinite(my), my = r(4)/2; end
end

end


function [mx, my, buttons] = localGetMouse(window)
try
    [mx, my, buttons] = GetMouse(window);
catch
    mx = NaN; my = NaN; buttons = false(1,3);
end
end
