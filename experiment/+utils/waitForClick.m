function waitForClick(window)
%UTILS.WAITFORCLICK  Wait for a mouse click, without PTB's GetClicks.
%
%   GetClicks bypasses utils.getMouse and hits raw GetMouse's window-relative
%   fragility on Windows; use this wherever GetClicks(window) was used.

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
