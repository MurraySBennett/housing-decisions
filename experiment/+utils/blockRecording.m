function out = blockRecording(action, et, varargin)
%UTILS.BLOCKRECORDING One bounded recording; gaps between blocks are explicit.
switch lower(action)
    case 'start'
        % Subscribe/drain pre-block samples. No task stimulus has started yet.
        if et.enabled && ~isempty(et.obj), et.obj.get_gaze_data(); end
        out = struct('store', utils.gazeBuffer('init'), ...
            'clockSync', struct('start', utils.clockSync(et), 'end', []));
    case 'finish'
        store = varargin{1}; anchors = varargin{2}; run = varargin{3};
        anchors.end = utils.clockSync(et);
        utils.progressLog(run, 'BEGIN block gaze drain samples=%d chunks=%d', store.n, numel(store.samples));
        raw = utils.gazeBuffer('flush', et, store, run);
        utils.progressLog(run, 'END block gaze drain samples=%d syncOK=%d/%d', ...
            numel(raw), anchors.start.ok, anchors.end.ok);
        out = struct('gaze', raw, 'clockSync', anchors);
    otherwise
        error('hw:blockRecording:action', 'Unknown recording action %s.', action);
end
end
