function [ok, firstFlip, lastFlip] = calibrate(et, window, cfg)
%UTILS.CALIBRATE  Five-point Tobii calibration.

ok = false; firstFlip = NaN; lastFlip = NaN;
if ~et.enabled || isempty(et.obj), return; end

s = cfg.style;
rect = Screen('Rect', window);
w = rect(3); h = rect(4);
pts = [0.5 0.5; 0.1 0.1; 0.9 0.1; 0.1 0.9; 0.9 0.9];

Screen('FillRect', window, s.bg);
Screen('TextSize', window, s.sizeContent);
DrawFormattedText(window, ...
    ['Calibration\n\nPlease follow the dot with your eyes.\n\n' ...
     'Try to keep your head still.\n\nClick to begin.'], ...
    'center', 'center', s.text, 60, 0, 0, 1.5);
firstFlip = Screen('Flip', window);
utils.waitForClick(window);

calib = ScreenBasedCalibration(et.obj);
calib.enter_calibration_mode();
% Leaving calibration mode must be guaranteed, not merely sequential. This used
% to be a bare call after compute_and_apply below, so ANY throw in between --
% collect_data, compute_and_apply, a Screen flip -- left the tracker inside
% calibration mode. setupEyeTracker's operator gate then offers 'retry', which
% re-enters this function and calls enter_calibration_mode() a second time; the
% real SDK rejects that, so the retry could never succeed however many times the
% operator chose it. onCleanup fires on the error path as well as the normal one.
modeGuard = onCleanup(@() leaveCalibrationMode(calib)); %#ok<NASGU>

for k = 1:size(pts, 1)
    px = pts(k,1) * w; py = pts(k,2) * h;

    % Shrink the target to pull fixation to its centre
    for r = linspace(30, 8, 20)
        Screen('FillRect', window, s.bg);
        Screen('DrawDots', window, [px; py], r*2, s.target, [], 2);
        Screen('DrawDots', window, [px; py], 4,  s.bg, [], 2);
        Screen('Flip', window);
    end
    WaitSecs(0.7);

    status = calib.collect_data(pts(k,:));
    if status.value ~= CalibrationStatus.Success
        calib.collect_data(pts(k,:));    % one retry
    end
end

result = calib.compute_and_apply();
% No explicit leave_calibration_mode here: modeGuard above owns it, so there is
% exactly one call on every path. It fires when this function returns, a few
% flips later than before, and setupEyeTracker's next get_gaze_data() runs after
% that -- so nothing observes the mode being held marginally longer.

ok = result.Status == CalibrationStatus.Success;
if ok
    fprintf('Calibration succeeded (%d points).\n', size(pts,1));
else
    warning('hw:calibrate:failed', 'Calibration did not converge.');
end

Screen('FillRect', window, s.bg);
lastFlip = Screen('Flip', window);

end


%% ======================================================================
function leaveCalibrationMode(calib)
%LEAVECALIBRATIONMODE  Guarded exit from calibration mode.
%   Swallows its own failure deliberately: this runs from onCleanup, including
%   while an exception is already unwinding, and a throw from here would replace
%   the real calibration error with a teardown error. A tracker that rejects the
%   call is already out of calibration mode, which is the outcome we wanted.

try
    calib.leave_calibration_mode();
catch leaveME
    fprintf(2, 'Could not leave calibration mode cleanly: %s\n', leaveME.message);
end

end
