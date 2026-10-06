function ok = positionGuide(et, window, cfg)
%UTILS.POSITIONGUIDE  Live head-position feedback before calibration.
%
%   ok = utils.positionGuide(et, window, cfg)
%   Uses track-box eye origin only (gaze point is uncalibrated here);
%   skip or timeout still returns, so this aid can never block a session.

ok = false;
if ~et.enabled || isempty(et.obj), return; end

g = cfg.et.positionGuide;
if ~g.enabled, return; end

s   = cfg.style;
r   = Screen('Rect', window);
W   = r(3); H = r(4);
cx  = W/2;

% Track-box panel
boxW = min(560, W*0.42);
boxH = boxW * 0.62;
boxL = cx - boxW/2;
boxT = H*0.26;

% Depth bar, below the box
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

    % Require holdSec inside tolerance so passing through does not count.
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
        % Display mirrors but track-box x runs the other way; flip cfg.et.positionGuide.mirrorX, not the arithmetic.
        if g.mirrorX, ex = 1 - ex; end
        px = boxL + ex * boxW;
        py = boxT + pos(2) * boxH;
        px = min(max(px, boxL+8), boxL+boxW-8);
        py = min(max(py, boxT+8), boxT+boxH-8);

        % Eye spacing shrinks with distance: second, non-verbal depth cue.
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

    % One instruction at a time: the largest error only.
    Screen('TextSize', window, s.sizeHeading);
    DrawFormattedText(window, nudge(haveData, inBox, dx, dy, dz, g), ...
        'center', barT + barH + 86, utils.ternary(inBox, s.accepted, s.text));

    Screen('TextSize', window, s.sizeLabel);
    DrawFormattedText(window, 'Click to continue anyway', ...
        'center', H - 48, s.textDim);

    Screen('Flip', window);
    utils.checkForQuit;

    % A click always continues; being trapped on a setup screen is worse than an off-centre head.
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
%   Returns [x y z] normalised 0..1 in the track box (0.5 centre), or NaNs; every SDK access wrapped so a positioning aid never throws mid-session.

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

for side = {{'LeftEye', 'left_eye'}, {'RightEye', 'right_eye'}}
    try
        p = trackBox(pickField(sample, side{1}));
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
%
% The PascalCase names are the real SDK's and are tried first. This function
% used to try only snake_case (gaze_origin.in_track_box_coordinate_system),
% which cannot match a real sample -- every access fell into its catch, so
% headPosition returned NaNs, ok stayed false, and the guide sat on "Looking
% for your eyes..." for the whole timeout. That is the 2026-09-18 rig failure
% that put cfg.et.positionGuide.enabled to false.
%
% Confirmed, not assumed: utils.gazeCodec's eyeArgs reads
% e.GazeOrigin.InTrackBoxCoordinateSystem, and the actual-SDK roundtrip case
% in scripts/tests/test_gaze_codec.m exercises that path and passed at the rig.

p = [NaN NaN NaN];

try
    origin = pickField(eye, {'GazeOrigin', 'gaze_origin'});
catch
    return
end

% Skip an eye the tracker marks invalid. An UNREADABLE validity deliberately
% falls through to the finite check instead of returning -- a positioning aid
% must not refuse to show a position it actually has.
try
    if ~validityIsValid(pickField(origin, {'Validity', 'validity'}))
        return
    end
catch
end

try
    v = pickField(origin, {'InTrackBoxCoordinateSystem', ...
        'in_track_box_coordinate_system', ...
        'position_in_track_box_coordinate_system'});
    p = double(v(:))';
catch
    return
end

if numel(p) ~= 3 || ~all(isfinite(p))
    p = [NaN NaN NaN];
end

end


%% ======================================================================
function v = pickField(s, names)
%PICKFIELD  First readable field/property from a list of candidate spellings.
%   Errors if none can be read, so every caller's existing catch still fires.

for k = 1:numel(names)
    try
        v = s.(names{k});
        return
    catch
    end
end
error('hw:positionGuide:field', 'No candidate field among: %s.', strjoin(names, ', '));

end


%% ======================================================================
function tf = validityIsValid(v)
%VALIDITYISVALID  True/false for a validity the real SDK wraps in an object.
%   Errors when the value cannot be read at all, which the caller treats as
%   "unknown" and falls through, rather than as "invalid".

if ~isnumeric(v) && ~islogical(v)
    v = v.value;
end
assert(isscalar(v) && (isnumeric(v) || islogical(v)), ...
    'hw:positionGuide:validity', 'Unreadable validity.');
tf = double(v) == 1;

end
