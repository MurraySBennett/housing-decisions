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

% The HUD band is flush to three screen edges, and a rounded rect glued to
% the screen edge looks broken. So inset the DRAWN panel inside the band
% rather than rounding the band itself. s.hud.heightPx is unchanged, which
% is what makes this safe: hudH feeds every layout function in both tasks
% AND preflight.m's hand-copied mirrors of them, so changing it would move
% every AOI in the battery. Changing only the painted inset moves nothing.
panel = [12, 6, w - 12, hgt - 6];
utils.roundRect(window, panel, s.radiusPanel, s.bgPanel, s.border, s.hairlinePx);

oldFont = Screen('TextFont', window, s.fontChrome);
Screen('TextSize', window, s.sizeLabel);

% The uppercase, zero-padded forms existed to suit a pixel font that
% only really worked in caps. s.hudUppercase keeps them under the arcade
% theme and drops them elsewhere -- shouting reads as harsh, and the HUD
% is the one piece of chrome the participant sees on every single screen.
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
