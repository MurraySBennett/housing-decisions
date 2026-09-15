function ok = calibrate(et, window, cfg)
%UTILS.CALIBRATE  Five-point Tobii calibration.

ok = false;
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
Screen('Flip', window);
utils.waitForClick(window);

calib = ScreenBasedCalibration(et.obj);
calib.enter_calibration_mode();

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
calib.leave_calibration_mode();

ok = result.Status == CalibrationStatus.Success;
if ok
    fprintf('Calibration succeeded (%d points).\n', size(pts,1));
else
    warning('hw:calibrate:failed', 'Calibration did not converge.');
end

Screen('FillRect', window, s.bg);
Screen('Flip', window);

end
