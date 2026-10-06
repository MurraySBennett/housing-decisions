function preserveGazeFailure(sess, run, et)
%UTILS.PRESERVEGAZEFAILURE Retain unsaved chunks without hiding the task error.
% A process kill cannot preserve RAM. Ordinary exceptions leave a named base
% workspace copy AND attempt local chunk writes; no previous file is replaced.
try
    store = utils.gazeBuffer('retained');
    if isempty(store), return; end
    if et.enabled && ~isempty(et.obj)
        try, store = utils.gazeBuffer('poll', et, store, run); catch, end
        try, et.obj.stop_gaze_data(); catch, end
    end
    id = strrep(utils.checkpointIO('id'), '-', '_');
    name = ['unsaved_gaze_' id];
    assignin('base', name, store);
    folder = fullfile(sess.cfg.paths.fallbackData, [run.runId '_' id]);
    utils.progressLog(run, 'UNSAVED GAZE retained in workspace variable %s; emergency folder %s', name, folder);
    for k = 1:numel(store.samples)
        % Keep unknown SDK leaves as original raw values, not an inferred codec.
        utils.checkpointIO('write', fullfile(folder, sprintf('chunk-%06d.mat', k)), ...
            struct('raw', store.samples{k}, 'run', run, 'chunkIndex', k));
    end
    utils.progressLog(run, 'Emergency gaze chunks verified; incomplete attempt remains incomplete');
catch emergencyError
    utils.progressLog(run, 'EMERGENCY GAZE SAVE ERROR: %s; retained buffer remains in memory', emergencyError.message);
end
end
