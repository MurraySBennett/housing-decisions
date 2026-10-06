function endRun(sess, run, status)
%UTILS.ENDRUN  Mark a run complete (or crashed) in the participant manifest.
%
%   utils.endRun(sess, run, 'complete')
%   utils.endRun(sess, run, 'crashed')
%   utils.endRun(sess, run, 'quit')

if nargin < 3, status = 'complete'; end

utils.progressLog(run, 'BEGIN manifest load for status=%s: %s', status, sess.manifestFile);
M = load(sess.manifestFile, 'manifest');
utils.progressLog(run, 'END manifest load');
manifest = M.manifest;

idx = [];
if ~isempty(manifest.runs)
    idx = find(strcmp({manifest.runs.runId}, run.runId), 1, 'last');
end
if isempty(idx)
    % This used to warn "appending" and then return WITHOUT appending, so a
    % run missing from the manifest was never recorded as finished: it stayed
    % 'started', and nextParticipant is resume-first, so that participant
    % number gets offered to the next person. Schema mirrors beginRun.m:27-38.
    warning('hw:endRun:notFound', 'Run %s was not in the manifest; appending it.', run.runId);
    entry = struct();
    entry.task           = run.task;
    entry.sessionNum     = sess.sessionNum;
    entry.runId          = run.runId;
    entry.runKind        = sess.runKind;
    entry.domainOrderStr = run.domainStr;
    entry.startedAt      = run.startedAt;
    entry.finishedAt     = '';
    entry.status         = 'started';
    entry.dataFile       = [run.fileStem '.mat'];
    entry.seed           = run.seed;
    entry.codeVersion    = sess.codeVersion;
    try
        utils.appendRun(sess.manifestFile, entry);
        M = load(sess.manifestFile, 'manifest');
        manifest = M.manifest;
        idx = find(strcmp({manifest.runs.runId}, run.runId), 1, 'last');
    catch appendME
        % A manifest written by a different code version can have a different
        % field set, and appendRun's runs(end+1) assignment then throws. Block
        % receipts are already on disk and are the completion authority, so
        % never let a manifest repair abort the end of a run.
        utils.progressLog(run, 'MANIFEST APPEND FAILED: %s', appendME.message);
        warning('hw:endRun:appendFailed', ...
            ['Could not append run %s to the manifest: %s\n' ...
             'Block receipts under cfg.paths.checkpoints remain authoritative.'], ...
            run.runId, appendME.message);
        return
    end
    if isempty(idx)
        warning('hw:endRun:appendFailed', ...
            'Run %s still absent after append; manifest left unchanged.', run.runId);
        return
    end
end

manifest.runs(idx).finishedAt = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
manifest.runs(idx).status     = status;

utils.progressLog(run, 'BEGIN manifest save status=%s: %s', status, sess.manifestFile);
if strcmp(status, 'complete')
    assert(utils.runCheckpoint('complete', sess, run), 'hw:endRun:incomplete', ...
        'Cannot mark a run complete without all verified block receipts.');
end
utils.checkpointIO('write', sess.manifestFile, struct('manifest', manifest), true);
utils.progressLog(run, 'END manifest save status=%s', status);
fprintf('Run %s -> %s\n', run.runId, status);

end
