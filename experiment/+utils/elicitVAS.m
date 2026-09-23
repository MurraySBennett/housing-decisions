function [ratings, rts, order] = elicitVAS(window, cfg, items, prompt, anchors, rngStream)
%UTILS.ELICITVAS  Visual analogue rating of a set of items on one line.
%
%   ratings : 1 x nItems, NORMALISED 0-1 in the order of `items`
%   rts     : 1 x nItems response times
%   order   : the randomised presentation order actually used
%   A rating with previous marks visible, not a ranking -- order matters.

s = cfg.style;
scr = Screen('Rect', window);
cx = scr(3)/2; cy = scr(4)/2;

lineY     = cy + 120;
lineLeft  = scr(3) * 0.12;
lineRight = scr(3) * 0.88;
lineLen   = lineRight - lineLeft;

n = numel(items);
ratings = nan(1, n);
rts     = nan(1, n);
if nargin < 6 || isempty(rngStream)
    rngStream = RandStream.getGlobalStream;
end
order   = randperm(rngStream, n);

placedX = [];
placedLabel = {};

for k = 1:n
    idx = order(k);
    t0 = GetSecs;
    SetMouse(round(cx), round(lineY), window);
    ShowCursor('Arrow', window);

    while true
        % utils.getMouse, not GetMouse: GetMouse can return NaN on Windows
        % right after OpenWindow, and a NaN mx reaches Screen('DrawLine').
        [mx, ~, buttons] = utils.getMouse(window);
        mx = min(max(mx, lineLeft), lineRight);

        Screen('FillRect', window, s.bg);
        Screen('TextFont', window, s.fontContent);
        Screen('TextSize', window, s.sizeHeading);
        DrawFormattedText(window, prompt, 'center', cy - 240, s.textDim, 70, 0, 0, 1.5);

        Screen('TextSize', window, s.sizeTitle);
        DrawFormattedText(window, items{idx}, 'center', cy - 120, s.text);

        % s.track, not s.border: this line is the response scale.
        Screen('DrawLine', window, s.track, lineLeft, lineY, lineRight, lineY, 3);
        Screen('DrawLine', window, s.track, lineLeft, lineY-16, lineLeft, lineY+16, 3);
        Screen('DrawLine', window, s.track, lineRight, lineY-16, lineRight, lineY+16, 3);

        Screen('TextSize', window, s.sizeLabel);
        DrawFormattedText(window, anchors{1}, lineLeft - 40, lineY + 56, s.textDim);
        b = Screen('TextBounds', window, anchors{2});
        DrawFormattedText(window, anchors{2}, lineRight - b(3) + 40, lineY + 56, s.textDim);

        % Previously placed items stay visible
        for p = 1:numel(placedX)
            Screen('DrawLine', window, s.textDim, placedX(p), lineY-12, placedX(p), lineY+12, 3);
            Screen('TextSize', window, s.sizeMicro);
            bb = Screen('TextBounds', window, placedLabel{p});
            yOff = lineY + 24 + mod(p, 3) * 22;
            DrawFormattedText(window, placedLabel{p}, placedX(p) - bb(3)/2, yOff, s.textDim);
        end

        % Current marker
        Screen('DrawLine', window, s.interactive, mx, lineY-22, mx, lineY+22, 5);

        Screen('Flip', window);
        utils.checkForQuit;

        if buttons(1)
            while any(buttons), [~,~,buttons] = utils.getMouse(window); end
            break
        end
    end

    ratings(idx) = (mx - lineLeft) / lineLen;   % normalised 0-1
    rts(idx) = GetSecs - t0;
    placedX(end+1) = mx; %#ok<AGROW>
    placedLabel{end+1} = items{idx}; %#ok<AGROW>
end

% Cursor deliberately left visible: the auction's comprehension check needs it.

end
