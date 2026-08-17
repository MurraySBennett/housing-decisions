function waitForClick(window)
%UTILS.WAITFORCLICK  Wait for a mouse click, without PTB's GetClicks.
%
%   utils.waitForClick(window)
%
%   GetClicks(window) internally calls PTB's raw GetMouse(w, mouseDev),
%   which has the exact same window-relative fragility on Windows that
%   utils.getMouse was built to work around -- but GetClicks doesn't go
%   through our wrapper at all, so every "click to continue" screen was
%   still exposed to it. This is what actually crashed a session: the
%   observed error ("GlobalRect: Argument was recognized as neither a
%   window index nor a screen pointer") comes from exactly that unguarded
%   internal call, not from anything to do with a hard window close.
%
%   Use this everywhere GetClicks(window) was used before.

buttons = false(1,3);
while ~any(buttons)
    [~, ~, buttons] = utils.getMouse(window);
    utils.checkForQuit;
    WaitSecs(0.01);
end
while any(buttons)
    [~, ~, buttons] = utils.getMouse(window);
end

end
