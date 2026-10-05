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

idx = find(strcmp({manifest.runs.runId}, run.runId), 1, 'last');
if isempty(idx)
    warning('hw:endRun:notFound', 'Run %s not in manifest; appending.', run.runId);
    return
end

manifest.runs(idx).finishedAt = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
manifest.runs(idx).status     = status;

utils.progressLog(run, 'BEGIN manifest save status=%s: %s', status, sess.manifestFile);
save(sess.manifestFile, 'manifest');
utils.progressLog(run, 'END manifest save status=%s', status);
fprintf('Run %s -> %s\n', run.runId, status);

end
