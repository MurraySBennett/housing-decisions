function ok = positionGuide(et, window, cfg)
%UTILS.POSITIONGUIDE  Live head-position feedback before calibration.
%
%   ok = utils.positionGuide(et, window, cfg)
%
%   Shows the participant where the tracker currently sees their eyes and
%   where they need to be, and waits until the two agree. Returns true if
%   they got into position, false if it was skipped or timed out -- either
%   way the session continues, because a positioning aid must never be the
%   reason a session cannot run.
%
%   WHY. Calibration can succeed from a bad head position and then drift
%   or lose an eye halfway through a block, and by then the trials are
%   spent. "Sit comfortably" is not instruction enough, because the track
%   box is invisible to the person inside it. This is the standard Tobii
%   positioning guide, reimplemented here because the SDK's own is a
%   Windows dialog that cannot be shown on a PTB fullscreen window.
%
%   THE SIGNAL. Tobii reports gaze origin in TRACK BOX coordinates:
%   x, y, z each normalised to 0..1 across the volume the tracker can see,
%   with 0.5, 0.5, 0.5 dead centre. Those are the only numbers here --
%   nothing is inferred from gaze point, which is not yet calibrated and
%   would be meaningless at this stage.
%
%   MIRRORING. The display acts as a mirror: lean left and the dots move
%   left. Tobii's track-box x runs the other way, so it is flipped below.
%   If the rig ever behaves backwards, flip cfg.et.positionGuide.mirrorX
%   rather than editing the arithmetic.
%
%   ROBUSTNESS. Every SDK access is wrapped. The property spelling for
%   track-box coordinates differs between SDK versions, both known
%   spellings are tried, and if neither works the screen says so and lets
%   the experimenter continue rather than stopping the session. A click
%   always skips.
%
%   See also UTILS.CALIBRATE, UTILS.SETUPEYETRACKER.

ok = false;
if ~et.enabled || isempty(et.obj), return; end

g = cfg.et.positionGuide;
if ~g.enabled, return; end

s   = cfg.style;
r   = Screen('Rect', window);
W   = r(3); H = r(4);
cx  = W/2;

% Track-box panel: a window onto what the tracker can see.
boxW = min(560, W*0.42);
boxH = boxW * 0.62;
boxL = cx - boxW/2;
boxT = H*0.26;

% Depth bar, below the box.
barW = boxW;
barL = boxL;
barT = boxT + boxH + 64;
barH = 26;

tStart   = GetSecs;
goodFrom = NaN;
sawData  = false;

Screen('TextFont', window, s.fontContent);

while true
    [pos, nEyes] = headPosition(et);
    haveData = any(isfinite(pos));
    sawData  = sawData || haveData;

    dx = pos(1) - 0.5;
    dy = pos(2) - 0.5;
    dz = pos(3) - 0.5;
    inBox = haveData && abs(dx) <= g.tolerance ...
                     && abs(dy) <= g.tolerance ...
                     && abs(dz) <= g.tolerance;

    % Hold steady before accepting, so a moment of passing through the
    % right spot does not count as being settled in it.
    if inBox
        if isnan(goodFrom), goodFrom = GetSecs; end
        if GetSecs - goodFrom >= g.holdSec
            ok = true;
            break
        end
    else
        goodFrom = NaN;
    end

    % ---------------- draw ----------------
    Screen('FillRect', window, s.bg);

    Screen('TextSize', window, s.sizeHeading);
    DrawFormattedText(window, 'Finding a comfortable position', ...
        'center', H*0.10, s.text);

    Screen('TextSize', window, s.sizeContent);
    DrawFormattedText(window, ...
        ['The dots show where the eye tracker can see your eyes.\n' ...
         'Move gently until they sit inside the outline.'], ...
        'center', H*0.16, s.textDim, 70, 0, 0, 1.35);

    % Track-box panel and its target zone
    utils.roundRect(window, [boxL boxT boxL+boxW boxT+boxH], ...
        s.radiusPanel, s.bgPanel, s.border, s.hairlinePx);

    tolW = boxW * g.tolerance * 2;
    tolH = boxH * g.tolerance * 2;
    zone = [cx - tolW/2, boxT + boxH/2 - tolH/2, ...
            cx + tolW/2, boxT + boxH/2 + tolH/2];
    zoneCol = utils.ternary(inBox, s.accepted, s.marker);
    utils.roundRect(window, zone, s.radiusPanel, s.bgPanel, zoneCol, 2);

    if haveData
        ex = pos(1);
        if g.mirrorX, ex = 1 - ex; end
        px = boxL + ex * boxW;
        py = boxT + pos(2) * boxH;
        px = min(max(px, boxL+8), boxL+boxW-8);
        py = min(max(py, boxT+8), boxT+boxH-8);

        % Eye spacing shrinks with distance, which gives the depth cue a
        % second, non-verbal channel.
        sep = 34 * (1.35 - dz);
        dotCol = utils.ternary(inBox, s.accepted, s.interactive);
        Screen('DrawDots', window, [px-sep, px+sep; py, py], 26, dotCol, [], 2);
        if nEyes < 2
            Screen('TextSize', window, s.sizeLabel);
            DrawFormattedText(window, 'only one eye visible', ...
                'center', boxT + boxH - 30, s.textDim);
        end
    else
        Screen('TextSize', window, s.sizeContent);
        msg = utils.ternary(sawData, 'Lost your eyes - please face the screen', ...
                                     'Looking for your eyes...');
        DrawFormattedText(window, msg, 'center', boxT + boxH/2, s.textDim);
    end

    % Depth bar
    utils.roundRect(window, [barL barT barL+barW barT+barH], ...
        s.radiusPill, s.bg, s.borderStrong, s.hairlinePx);
    tolBar = barW * g.tolerance;
    utils.roundRect(window, [cx-tolBar, barT, cx+tolBar, barT+barH], ...
        s.radiusPill, s.bgPanel);
    if haveData
        zx = barL + min(max(pos(3), 0), 1) * barW;
        zc = utils.ternary(abs(dz) <= g.tolerance, s.accepted, s.interactive);
        Screen('DrawDots', window, [zx; barT + barH/2], 22, zc, [], 2);
    end
    Screen('TextSize', window, s.sizeLabel);
    DrawFormattedText(window, 'closer', barL, barT + barH + 30, s.textDim);
    b = Screen('TextBounds', window, 'further back');
    DrawFormattedText(window, 'further back', barL + barW - b(3), ...
        barT + barH + 30, s.textDim);

    % One instruction at a time -- the largest error, so the participant
    % is never given two corrections to hold in mind at once.
    Screen('TextSize', window, s.sizeHeading);
    DrawFormattedText(window, nudge(haveData, inBox, dx, dy, dz, g), ...
        'center', barT + barH + 86, utils.ternary(inBox, s.accepted, s.text));

    Screen('TextSize', window, s.sizeLabel);
    DrawFormattedText(window, 'Click to continue anyway', ...
        'center', H - 48, s.textDim);

    Screen('Flip', window);
    utils.checkForQuit;

    % A click always continues. The experimenter may have a good reason
    % -- glasses, an unusual seating position, a participant who cannot
    % get centred -- and being trapped on a setup screen is worse than a
    % slightly off-centre head.
    [~, ~, buttons] = utils.getMouse(window);
    if any(buttons)
        while any(buttons), [~,~,buttons] = utils.getMouse(window); end
        break
    end

    if GetSecs - tStart > g.timeoutSec
        fprintf(2, ['Position guide timed out after %.0fs. Continuing.\n' ...
                    'If this keeps happening, check that gaze data is ' ...
                    'streaming and that the track-box property name ' ...
                    'matches this SDK version.\n'], g.timeoutSec);
        break
    end
end

Screen('FillRect', window, s.bg);
Screen('Flip', window);

if ok
    fprintf('Head position within tolerance.\n');
end

end


%% ======================================================================
function txt = nudge(haveData, inBox, dx, dy, dz, g)
%NUDGE  The single most useful correction right now.

if ~haveData
    txt = '';
    return
end
if inBox
    txt = 'That is the spot - hold still';
    return
end

[~, worst] = max(abs([dx dy dz]) ./ g.tolerance);
switch worst
    case 1
        txt = utils.ternary(dx > 0, 'Move a little to your left', ...
                                    'Move a little to your right');
    case 2
        txt = utils.ternary(dy > 0, 'Sit up a little', 'Lower slightly');
    otherwise
        txt = utils.ternary(dz > 0, 'Move a little closer', 'Move back a little');
end

end


%% ======================================================================
function [pos, nEyes] = headPosition(et)
%HEADPOSITION  Mean track-box position of whichever eyes are visible.
%
%   Returns [x y z] normalised to the track box, or NaNs. Every SDK
%   access is wrapped: property spellings differ across SDK versions and
%   a positioning aid must never throw into the middle of a session.

pos = [NaN NaN NaN];
nEyes = 0;

try
    samples = et.obj.get_gaze_data();
catch
    return
end
if isempty(samples), return; end

sample = samples(end);
acc = zeros(1, 3);

for side = {'left_eye', 'right_eye'}
    try
        p = trackBox(sample.(side{1}));
    catch
        p = [NaN NaN NaN];
    end
    if all(isfinite(p))
        acc = acc + p;
        nEyes = nEyes + 1;
    end
end

if nEyes > 0
    pos = acc / nEyes;
end

end


%% ======================================================================
function p = trackBox(eye)
%TRACKBOX  Track-box coordinates for one eye, across SDK spellings.

p = [NaN NaN NaN];

% Skip an eye the tracker has explicitly marked invalid. If validity
% cannot be read at all, fall through and let the finite check decide.
try
    if eye.gaze_origin.validity ~= Validity.Valid
        return
    end
catch
end

try
    p = double(eye.gaze_origin.in_track_box_coordinate_system(:))';
catch
    try
        p = double(eye.gaze_origin.position_in_track_box_coordinate_system(:))';
    catch
        return
    end
end

if numel(p) ~= 3 || ~all(isfinite(p))
    p = [NaN NaN NaN];
end

end
