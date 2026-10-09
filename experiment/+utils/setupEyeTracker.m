function et = setupEyeTracker(cfg, window, doCalibrate)
%UTILS.SETUPEYETRACKER  Connect, calibrate, and start a Tobii recording.
%
%   Two failure classes, handled differently on purpose:
%
%   Connection failure degrades to an untracked session. A rig with no
%   tracker attached is a legitimate configuration.
%
%   Failure AFTER a tracker is connected does NOT degrade silently. This
%   used to be one broad try/catch, so a PTB error or a wrong SDK field
%   spelling inside positionGuide or calibrate set enabled = false and ran
%   the ENTIRE session with zero gaze data, reporting it only as a console
%   warning that an RA cannot see behind a fullscreen window. For an
%   eye-tracking study that is a wasted participant. The operator now has to
%   choose, on screen, and the choice is recorded with the data.

if nargin < 3, doCalibrate = true; end

et.enabled     = cfg.et.enabled;
et.obj         = [];
et.operations  = [];
et.mediaMode   = cfg.et.mediaMode;
et.showGaze    = cfg.et.mediaMode && cfg.et.showGaze;
et.calibrated  = false;
et.positioned  = false;   % head got inside the track box before calibrating
et.analyzable  = true;
et.requestedSampleRateHz = cfg.et.sampleRateHz;
et.actualSampleRateHz = NaN;
% Always present and always char, so the tasks can record them unconditionally.
et.setupFailureStage   = '';
et.setupFailureMessage = '';
et.operatorChoice      = 'none';

if ~et.enabled
    fprintf('Eye tracking disabled.\n');
    et.analyzable = false;
    return
end

% A visible gaze dot creates a feedback loop; any run with it visible is flagged non-analyzable.
if cfg.et.showGaze && ~cfg.et.mediaMode
    warning('hw:setupEyeTracker:gazeIgnored', ...
        'cfg.et.showGaze is set but cfg.et.mediaMode is false -- gaze dot NOT shown.');
    et.showGaze = false;
end
if et.showGaze
    et.analyzable = false;
    fprintf(2, '\n*** MEDIA MODE: gaze dot visible. This run is NOT analyzable. ***\n\n');
end

% --- Connect ----------------------------------------------------------
try
    Tobii = EyeTrackingOperations();
    et.operations = Tobii;
    trackers = Tobii.find_all_eyetrackers();
    if isempty(trackers)
        error('hw:setupEyeTracker:noTracker', 'No eye tracker found.');
    end
    et.obj = trackers(1);
    fprintf('Connected: %s (%s)\n', et.obj.Name, et.obj.SerialNumber);
catch connectME
    warning('hw:setupEyeTracker:noConnection', ...
        'Could not connect to an eye tracker (%s). Continuing without tracking.', ...
        connectME.message);
    et = markUntracked(et, 'connect', connectME.message, 'degraded-no-connection');
    return
end

try
    et.actualSampleRateHz = et.obj.get_gaze_output_frequency();
catch
end

% --- Position guide, calibration, and a clean buffer -------------------
attempt = 0;
while true
    attempt = attempt + 1;
    try
        if doCalibrate
            % First get_gaze_data() call subscribes; must run before the position guide.
            et.obj.get_gaze_data();
            et.positioned = utils.positionGuide(et, window, cfg);

            et.calibrated = utils.calibrate(et, window, cfg);
        end

        et.obj.get_gaze_data();     % clear any stale buffer before we start
        return
    catch prepME
        fprintf(2, '\nEye tracker setup failed after connecting (attempt %d):\n%s\n', ...
            attempt, getReport(prepME, 'extended', 'hyperlinks', 'off'));

        if ~doCalibrate
            % Testing/demo path: no participant is waiting and there is no
            % calibration to retry, so keep the old degrade behaviour.
            warning('hw:setupEyeTracker:failed', ...
                'Eye tracker setup failed (%s). Continuing without tracking.', prepME.message);
            et = markUntracked(et, 'prepare', prepME.message, 'degraded-testing');
            return
        end

        switch askOperator(window, cfg, prepME, attempt)
            case 'retry'
                continue
            case 'continue'
                et = markUntracked(et, 'prepare', prepME.message, 'continued-untracked');
                warning('hw:setupEyeTracker:continuedUntracked', ...
                    'Operator chose to continue WITHOUT eye tracking: %s', prepME.message);
                return
            otherwise  % 'abort'
                et = markUntracked(et, 'prepare', prepME.message, 'aborted');
                error('hw:setupEyeTracker:operatorAbort', ...
                    'Operator aborted the session after eye tracker setup failed: %s', ...
                    prepME.message);
        end
    end
end

end


function et = markUntracked(et, stage, message, choice)
%MARKUNTRACKED Stop the stream, drop the handle, and record why.
% The old code assigned et.obj = [] without stopping the subscription, so a
% tracker that had already been subscribed kept streaming into a buffer
% nobody read for the rest of the session.
if ~isempty(et.obj)
    try
        et.obj.stop_gaze_data();
    catch stopME
        fprintf(2, 'Could not stop gaze stream (ignored): %s\n', stopME.message);
    end
end
et.enabled    = false;
et.obj        = [];
et.analyzable = false;
et.setupFailureStage   = stage;
et.setupFailureMessage = message;
et.operatorChoice      = choice;
end


function choice = askOperator(window, cfg, ME, attempt)
%ASKOPERATOR Blocking, keyboard-only decision shown on the stimulus screen.
% Deliberately not utils.waitForClick: a participant must not be able to
% dismiss a tracking failure by clicking, and the three outcomes differ.
s = cfg.style;

headline = 'Eye tracker setup failed';
body = sprintf([ ...
    'Attempt %d could not complete.\n\n%s\n\n' ...
    'R  -  retry the position guide and calibration\n' ...
    'C  -  continue this session WITHOUT eye tracking\n' ...
    'A  -  abort the session now\n\n' ...
    'Continuing without tracking records no gaze data for the whole\n' ...
    'session. The choice is saved with the data.'], ...
    attempt, ME.message);

choice = 'abort';

% The on-screen prompt is the normal path, but it must never be the thing that
% ends a session. On 2026-10-09 sub-00010 died exactly here, 50 s in: the
% tracker failed to prepare, this ran to ask the operator what to do, and
% Screen('FillRect') rejected the window handle -- the generic "Usage:" error
% README's "Known gotchas" describes, from a handle OpenWindow had returned as
% valid. The crash dump confirmed every colour and font argument was
% well-formed, so the handle was the bad argument. A tracker failure is
% recoverable; being unable to ASK about it turned it into a lost participant.
onScreen = true;
try
    Screen('FillRect', window, s.bg);
    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeTitle);
    DrawFormattedText(window, headline, 'center', 0.18 * RectHeight(Screen('Rect', window)), s.text);
    Screen('TextSize', window, s.sizeContent);
    DrawFormattedText(window, body, 'center', 'center', s.textDim, 70, 0, 0, 1.5);
    Screen('Flip', window);
catch drawME
    onScreen = false;
    fprintf(2, ['\n*** Could not draw the eye-tracker prompt on the stimulus screen:\n' ...
                '    %s (%s)\n' ...
                '    Asking in this window instead. The session is NOT lost.\n'], ...
            drawME.message, drawME.identifier);
end

if onScreen
    retryKey    = KbName('r');
    continueKey = KbName('c');
    abortKey    = KbName('a');

    KbReleaseWait(-1);
    while true
        [down, ~, keyCode] = KbCheck(-1);
        if down
            if keyCode(retryKey),    choice = 'retry';    break; end
            if keyCode(continueKey), choice = 'continue'; break; end
            if keyCode(abortKey),    choice = 'abort';    break; end
        end
        WaitSecs(0.01);
    end
    KbReleaseWait(-1);
else
    % Hand the keyboard back first or input() reads nothing and this looks
    % hung -- the same trap that had operators force-quitting MATLAB.
    try
        ListenChar(0);
        ShowCursor;
    catch
        % Nothing to hand back; the console prompt below still works.
    end
    fprintf(2, '\n%s\n\n%s\n\n', headline, body);
    while true
        answer = strtrim(lower(input('Choose R (retry), C (continue untracked), A (abort): ', 's')));
        if isempty(answer), continue; end
        if     answer(1) == 'r', choice = 'retry';    break;
        elseif answer(1) == 'c', choice = 'continue'; break;
        elseif answer(1) == 'a', choice = 'abort';    break;
        end
    end
end

fprintf('Operator chose: %s\n', choice);
end
