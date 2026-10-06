function [flipTime, log] = awaitFixationStart(window, cfg, log, info)
%UTILS.AWAITFIXATIONSTART  Click a center cross to begin a trial.
%
%   [flipTime, log] = utils.awaitFixationStart(window, cfg, log, info)
%
%   Anchors gaze to a known central point before the first saccade; info goes
%   to utils.drawHUD. flipTime is the click frame's flip -- use it as trial t0.

s = cfg.style;
scr = Screen('Rect', window);
cx = scr(3)/2; cy = scr(4)/2;

% ~1 deg hit region; clicks outside it are ignored, not accepted.
hitR = max(30, cfg.geom.deg2px(1.0));

ShowCursor('Arrow', window);
onsetLogged = false;
armed = false;   % debounce: don't accept a click still held from the last screen

while true
    Screen('FillRect', window, s.bg);
    utils.drawHUD(window, cfg, info);

    % Crosshair target
    armLen = 18;
    Screen('DrawLine', window, s.interactive, cx-armLen, cy, cx+armLen, cy, 3);
    Screen('DrawLine', window, s.interactive, cx, cy-armLen, cx, cy+armLen, 3);
    % hitR is click geometry -- do not change it. Only the stroke changes.
    Screen('FrameOval', window, s.borderStrong, ...
        [cx-hitR cy-hitR cx+hitR cy+hitR], s.hairlinePx);

    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeLabel);
    DrawFormattedText(window, 'Click the target to begin', 'center', cy + hitR + 40, s.textDim);

    flipTime = Screen('Flip', window);
    if ~onsetLogged
        log = utils.eventLog('add', log, 'fixation_onset', flipTime, info);
        onsetLogged = true;
    end
    utils.checkForQuit;

    [mx, my, buttons] = utils.getMouse(window);
    if ~any(buttons)
        armed = true;   % button released since we started waiting
        continue
    end
    if ~armed
        continue        % still holding a click from before this screen
    end

    if hypot(mx - cx, my - cy) <= hitR
        while any(buttons), [~,~,buttons] = utils.getMouse(window); end
        log = utils.eventLog('add', log, 'fixation_start', flipTime, info);
        return
    end
    while any(buttons), [~,~,buttons] = utils.getMouse(window); end
end

end
