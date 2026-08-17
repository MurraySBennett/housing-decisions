function [flipTime, log] = awaitFixationStart(window, cfg, log, info)
%UTILS.AWAITFIXATIONSTART  Click a center cross to begin a trial.
%
%   [flipTime, log] = utils.awaitFixationStart(window, cfg, log, info)
%
%   Two jobs in one screen:
%     1. Self-paced "ready" signal -- the participant starts each trial
%        when they choose to, not when the code decides.
%     2. Sets a known GAZE START POINT. You usually look at the thing
%        you're about to click, so a click on a known, fixed, central
%        target anchors gaze to a known location and time immediately
%        before the trial's first saccade -- without this, "where were
%        they looking when the trial began" is unknown, which matters a
%        lot for interpreting first-fixation latency and direction.
%
%   This is also the ONLY place (besides block-intro screens) that shows
%   rich condition/progress info -- trial screens themselves stay clean.
%   Tempting a gaze shift toward a HUD during the actual response is the
%   thing we're avoiding; showing that same information here, before the
%   stimulus appears, gets the participant the information without that
%   cost.
%
%   info is passed straight to utils.drawHUD -- same fields you'd use
%   there (trial, nTrials, label).
%
%   Returns flipTime: the actual Screen('Flip') timestamp of the frame
%   the participant's click was registered on. Use this as the trial's t0
%   instead of GetSecs at function entry -- it's the true stimulus-locked
%   reference point, not "whenever this function happened to be called."

s = cfg.style;
scr = Screen('Rect', window);
cx = scr(3)/2; cy = scr(4)/2;

% Hit region around the cross. ~1 deg is generous enough to be a fair
% target but small enough that "clicked near center" still means they were
% looking there -- a click that lands nowhere near it is ignored rather
% than silently accepted as a fixation click.
hitR = max(30, cfg.geom.deg2px(1.0));

ShowCursor('Arrow', window);
armed = false;   % debounce: don't accept a click still held from the last screen

while true
    Screen('FillRect', window, s.bg);
    utils.drawHUD(window, cfg, info);

    % Crosshair target
    armLen = 18;
    Screen('DrawLine', window, s.interactive, cx-armLen, cy, cx+armLen, cy, 4);
    Screen('DrawLine', window, s.interactive, cx, cy-armLen, cx, cy+armLen, 4);
    Screen('FrameOval', window, s.border, [cx-hitR cy-hitR cx+hitR cy+hitR], 2);

    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeLabel);
    DrawFormattedText(window, 'Click the target to begin', 'center', cy + hitR + 40, s.textDim);

    flipTime = Screen('Flip', window);
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
    % Click landed outside the target -- ignore it, keep waiting.
    while any(buttons), [~,~,buttons] = utils.getMouse(window); end
end

end
