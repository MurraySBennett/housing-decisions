function [mx, my, buttons] = getMouse(window)
%UTILS.GETMOUSE  Robust cursor query -- works around a real Windows/PTB issue.
%
%   [mx, my, buttons] = utils.getMouse(window)
%
%   GetMouse(window) asks the OS for the cursor position THROUGH that
%   window's own OpenGL/display context. On Windows, that path goes through
%   a different code branch than the no-argument form, and it is the one
%   that's more fragile: it has been reported to throw or return garbage
%   when the window isn't the frontmost one, when Windows display scaling
%   isn't 100%, in multi-monitor setups, or immediately after certain
%   Screen() calls that momentarily invalidate the context. GetMouse() with
%   no argument instead calls the plain Windows cursor-position API, which
%   doesn't go through PTB's window/OpenGL layer at all and is far more
%   reliable -- but it returns coordinates relative to the WHOLE virtual
%   desktop, not the window, so in windowed mode (dev rig, testing) those
%   need correcting by the window's own screen offset.
%
%   This tries the window-relative form first and falls back automatically
%   -- and validates the RESULT, not just whether it threw. This matters:
%   GetMouse(window) has been observed to return NaN or otherwise
%   non-finite coordinates on Windows WITHOUT throwing (e.g. when the
%   window hasn't taken focus yet, right after it opens) -- the original
%   version of this wrapper only caught a thrown exception, so a silent
%   NaN sailed straight through into a Screen('DrawLine'/'DrawDots') call
%   downstream, which is what actually crashed a session: PTB's generic
%   "Usage:" error is what you get when a coordinate argument isn't a
%   finite real scalar, not a clearer NaN-specific message.

[mx, my, buttons] = localGetMouse(window);
if isfinite(mx) && isfinite(my)
    return
end

% Primary form returned garbage rather than throwing -- fall back to the
% desktop-global query, which doesn't go through the window's OpenGL
% context at all and is far more reliable.
[mx, my, buttons] = GetMouse();
try
    gr = Screen('GlobalRect', window);   % [left top right bottom] in desktop coords
    mx = mx - gr(1);
    my = my - gr(2);
catch
    % If GlobalRect also fails we're fullscreen at the origin anyway;
    % uncorrected global coordinates are then already correct.
end

% Last resort: still non-finite even from the global query (e.g. no mouse
% device at all). Return the window centre rather than propagating NaN
% into whatever Screen call comes next.
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
