function savingScreen(window, cfg, frac, label, fact)
%UTILS.SAVINGSCREEN  "Please wait, saving data" with a real progress bar.
%
%   utils.savingScreen(window, cfg, frac, label, fact)  -- frac 0..1
%   Pass the same fact to every call in a save sequence to avoid flicker.

% save() blocks and reports nothing, so the caller brackets real steps; the bar is honest -- do not fake-animate it.
if nargin < 5, fact = ''; end
if nargin < 4, label = ''; end

s = cfg.style;
scr = Screen('Rect', window);
W = scr(3); H = scr(4);
cx = W / 2;

frac = min(max(frac, 0), 1);

Screen('FillRect', window, s.bg);
Screen('TextFont', window, s.fontContent);

% --- Heading ----------------------------------------------------------
Screen('TextSize', window, s.sizeHeading);
head = 'Please wait - saving your data';
b = Screen('TextBounds', window, head);
DrawFormattedText(window, head, cx - b(3)/2, H * 0.30, s.text);

% --- Progress bar -----------------------------------------------------
barW = min(560, W * 0.42);
barH = 20;
barL = cx - barW/2;
barT = H * 0.30 + 52;

utils.roundRect(window, [barL, barT, barL + barW, barT + barH], ...
    s.radiusPill, s.bg, s.borderStrong, s.hairlinePx);
if frac > 0
    utils.roundRect(window, [barL, barT, barL + barW*frac, barT + barH], ...
        s.radiusPill, s.interactive);
end

% --- Current step -----------------------------------------------------
if ~isempty(label)
    Screen('TextSize', window, s.sizeLabel);
    b = Screen('TextBounds', window, label);
    DrawFormattedText(window, label, cx - b(3)/2, barT + barH + 34, s.textDim);
end

% --- Did you know ------------------------------------------------------
if ~isempty(fact)
    panW = min(760, W * 0.56);
    panL = cx - panW/2;
    panT = H * 0.30 + 150;
    panB = panT + 190;
    utils.roundRect(window, [panL, panT, panL + panW, panB], ...
        s.radiusPanel, s.bgPanel, s.border, s.hairlinePx);

    Screen('TextSize', window, s.sizeLabel);
    DrawFormattedText(window, 'Did you know...', panL + 28, panT + 38, s.interactive);

    Screen('TextSize', window, s.sizeContent);
    DrawFormattedText(window, fact, panL + 28, panT + 78, s.text, ...
        52, 0, 0, 1.35);
end

Screen('Flip', window);

end
