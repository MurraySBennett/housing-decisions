function [offsetDeg, recalibrated, store, markers] = driftCheck(et, window, cfg, centre, store)
%UTILS.DRIFTCHECK  Fixation-based drift measurement at a block boundary.
%
%   Tobii accuracy degrades over a session as the participant shifts. With
%   blocks running several minutes and no re-check, that drift accumulates
%   silently and shows up as AOIs that no longer line up with the stimuli.

ownsRecording = nargin < 5;
if ownsRecording, store = []; end
markers = struct('event',{},'flipTime',{},'phase',{});
offsetDeg = NaN;
recalibrated = false;
if ~et.enabled || isempty(et.obj) || ~cfg.et.driftCheck
    return
end

s = cfg.style;
[cx, cy] = deal(centre(1), centre(2));

% An active task owns its buffer: never clear, discard, or stop that stream.
if ownsRecording
    recording = utils.blockRecording('start',et); store = recording.store;
else
    store = utils.gazeBuffer('poll',et,store);
end

% Draw a fixation target and collect a short sample
Screen('FillRect', window, s.bg);
Screen('TextSize', window, s.sizeContent);
DrawFormattedText(window, 'Please look at the dot.', 'center', cy - 160, s.textDim);
Screen('DrawDots', window, [cx; cy], 18, s.target, [], 2);
Screen('DrawDots', window, [cx; cy], 5,  s.bg, [], 2);
flip = Screen('Flip', window);
markers(end+1) = struct('event','drift_onset','flipTime',flip,'phase','drift');
WaitSecs(0.6);
store = utils.gazeBuffer('poll',et,store);
% Exclude approach samples from the offset estimate, but retain them on disk.
firstChunk = numel(store.samples) + 1;
t0 = GetSecs;
while GetSecs - t0 < 1.2
    store = utils.gazeBuffer('poll', et, store);
    WaitSecs(0.02);
end
store = utils.gazeBuffer('poll',et,store);
if firstChunk <= numel(store.samples)
    samples = vertcat(store.samples{firstChunk:end});
else
    samples = [];
end
if ownsRecording
    utils.gazeBuffer('flush',et,store);
end

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
    [recalibrated,firstFlip,lastFlip] = utils.calibrate(et, window, cfg);
    markers(end+1) = struct('event','calibration_onset','flipTime',firstFlip,'phase','calibration');
    markers(end+1) = struct('event','intertrial_onset','flipTime',lastFlip,'phase','intertrial');
    if ~ownsRecording, store = utils.gazeBuffer('poll',et,store); end
end

end
