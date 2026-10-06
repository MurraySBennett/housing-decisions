function out = blockRecording(action, et, varargin)
%UTILS.BLOCKRECORDING One bounded recording; gaps between blocks are explicit.
switch lower(action)
    case 'start'
        % Subscribe/drain pre-block samples. No task stimulus has started yet.
        % Guarded like clockSync.m:12 and gazeBuffer.m:22: a failed
        % setupEyeTracker can leave et non-struct, and bare et.enabled then
        % throws "Dot indexing is not supported" at the first block.
        if isstruct(et) && et.enabled && ~isempty(et.obj), et.obj.get_gaze_data(); end
        out = struct('store', utils.gazeBuffer('init'), ...
            'clockSync', struct('start', utils.clockSync(et), 'end', []));
    case 'finish'
        store = varargin{1}; anchors = varargin{2}; run = varargin{3};
        utils.progressLog(run, 'BEGIN block gaze drain samples=%d chunks=%d', store.n, numel(store.samples));
        raw = utils.gazeBuffer('flush', et, store, run);
        anchors.end = utils.clockSync(et);
        utils.progressLog(run, 'END block gaze drain samples=%d syncOK=%d/%d', ...
            numel(raw), anchors.start.ok, anchors.end.ok);
        out = struct('gaze', raw, 'clockSync', anchors);
    otherwise
        error('hw:blockRecording:action', 'Unknown recording action %s.', action);
end
end
