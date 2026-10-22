function out = drainRecording(et, store, anchors, run)
%UTILS.DRAINRECORDING Close a block recording: final poll, stop, second anchor.
%
% The pair to utils.startRecording. Flushes the accumulated samples (the
% final get_gaze_data drain and tracker stop live in utils.gazeBuffer), takes
% the closing clock anchor, and returns the raw samples plus both anchors --
% exactly what utils.commitBlock needs to pack and align the block's gaze.
utils.progressLog(run, 'BEGIN block gaze drain samples=%d chunks=%d', store.n, numel(store.samples));
raw = utils.gazeBuffer('flush', et, store, run);
anchors.end = utils.clockSync(et);
utils.progressLog(run, 'END block gaze drain samples=%d syncOK=%d/%d', ...
    numel(raw), anchors.start.ok, anchors.end.ok);
out = struct('gaze', raw, 'clockSync', anchors);
end
