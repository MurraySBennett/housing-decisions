function rect = drawHUD(window, cfg, info)
%UTILS.DRAWHUD  Static status strip along the top of the screen.
%
%   The HUD is the highest-value retro element because it is genuinely
%   informative and lives OUTSIDE the stimulus AOIs. It must stay static
%   during a search episode: a ticking timer or a live earnings counter is
%   an off-task attention magnet that pulls gaze away from the options.

s = cfg.style;
if ~s.hud.enabled
    rect = [0 0 0 0];
    return
end

scr = Screen('Rect', window);
w = scr(3);
hgt = s.hud.heightPx;
rect = [0 0 w hgt];

Screen('FillRect', window, s.bgPanel, rect);
Screen('FrameRect', window, s.border, rect, s.borderWidthPx);

oldFont = Screen('TextFont', window, s.fontChrome);
Screen('TextSize', window, s.sizeLabel);

left = '';
if s.hud.showBlock && isfield(info, 'trial')
    left = sprintf('TRIAL %02d/%02d', info.trial, info.nTrials);
end
mid = '';
if isfield(info, 'label'), mid = upper(info.label); end
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
