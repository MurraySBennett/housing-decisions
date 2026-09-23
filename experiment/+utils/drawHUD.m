function rect = drawHUD(window, cfg, info)
%UTILS.DRAWHUD  Static status strip along the top of the screen.
%   Must stay static during a search episode: a ticking timer or live counter
%   is an off-task gaze magnet.

s = cfg.style;
if ~s.hud.enabled
    rect = [0 0 0 0];
    return
end

scr = Screen('Rect', window);
w = scr(3);
hgt = s.hud.heightPx;
rect = [0 0 w hgt];

% Inset only the painted panel, never s.hud.heightPx: hudH feeds every layout
% function and preflight's mirrors, so changing it moves every AOI.
panel = [12, 6, w - 12, hgt - 6];
utils.roundRect(window, panel, s.radiusPanel, s.bgPanel, s.border, s.hairlinePx);

oldFont = Screen('TextFont', window, s.fontChrome);
Screen('TextSize', window, s.sizeLabel);

% s.hudUppercase keeps the caps forms under the arcade theme only.
left = '';
if s.hud.showBlock && isfield(info, 'trial')
    if s.hudUppercase
        left = sprintf('TRIAL %02d/%02d', info.trial, info.nTrials);
    else
        left = sprintf('Trial %d of %d', info.trial, info.nTrials);
    end
end
mid = '';
if isfield(info, 'label')
    mid = utils.ternary(s.hudUppercase, upper(info.label), info.label);
end
right = '';
if s.hud.showEarnings && isfield(info, 'earnings')
    right = sprintf('$%.2f', info.earnings);
end

pad = 24;
if ~isempty(left)
    DrawFormattedText(window, left, pad, hgt/2 + 8, s.textDim);
end
if ~isempty(mid)
    DrawFormattedText(window, mid, 'center', hgt/2 + 8, s.money);
end
if ~isempty(right)
    b = Screen('TextBounds', window, right);
    DrawFormattedText(window, right, w - b(3) - pad, hgt/2 + 8, s.money);
end

Screen('TextFont', window, oldFont);

end
