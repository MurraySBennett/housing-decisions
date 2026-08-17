function [offsetDeg, recalibrated] = driftCheck(et, window, cfg, centre)
%UTILS.DRIFTCHECK  Fixation-based drift measurement at a block boundary.
%
%   Tobii accuracy degrades over a session as the participant shifts. With
%   blocks running several minutes and no re-check, that drift accumulates
%   silently and shows up as AOIs that no longer line up with the stimuli.

offsetDeg = NaN;
recalibrated = false;
if ~et.enabled || isempty(et.obj) || ~cfg.et.driftCheck
    return
end

s = cfg.style;
[cx, cy] = deal(centre(1), centre(2));

% Draw a fixation target and collect a short sample
Screen('FillRect', window, s.bg);
Screen('TextSize', window, s.sizeContent);
DrawFormattedText(window, 'Please look at the dot.', 'center', cy - 160, s.textDim);
Screen('DrawDots', window, [cx; cy], 18, s.interactive, [], 2);
Screen('DrawDots', window, [cx; cy], 5,  s.bg, [], 2);
Screen('Flip', window);
WaitSecs(0.6);

et.obj.get_gaze_data();      % discard the approach saccade
store = utils.gazeBuffer('init');
t0 = GetSecs;
while GetSecs - t0 < 1.2
    store = utils.gazeBuffer('poll', et, store);
    WaitSecs(0.02);
end
samples = utils.gazeBuffer('flush', et, store);

if isempty(samples)
    warning('hw:driftCheck:noSamples', 'Drift check collected no gaze data.');
    return
end

[gx, gy] = utils.gazeToPixels(samples, window);
valid = ~isnan(gx) & ~isnan(gy);
if nnz(valid) < 10
    warning('hw:driftCheck:tooFewValid', 'Only %d valid samples in drift check.', nnz(valid));
    return
end

offsetPx  = hypot(median(gx(valid)) - cx, median(gy(valid)) - cy);
offsetDeg = cfg.geom.px2deg(offsetPx);
fprintf('Drift check: %.2f deg offset (tolerance %.2f).\n', offsetDeg, cfg.et.driftTolDeg);

if offsetDeg > cfg.et.driftTolDeg && cfg.et.recalOnFail
    fprintf('  Exceeds tolerance -- recalibrating.\n');
    utils.calibrate(et, window, cfg);
    recalibrated = true;
end

end
