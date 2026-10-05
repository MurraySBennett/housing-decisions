function logFile = progressLog(run, fmt, varargin)
%UTILS.PROGRESSLOG Persistent, best-effort task-end diagnostics on local disk.
% Each entry opens and closes the file; nothing waits for normal task exit.
% No writes during trial timing. Never use the shared data root for this log.
logFile = '';
try
    logDir = fullfile(tempdir, 'housing-wages-logs');
    if ~exist(logDir, 'dir'), mkdir(logDir); end
    logFile = fullfile(logDir, [run.runId '.log']);
    [fid, msg] = fopen(logFile, 'a');
    if fid < 0, error('hw:progressLog:open', '%s', msg); end
    closeFile = onCleanup(@() fclose(fid)); %#ok<NASGU>
    stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
    fprintf(fid, '[%s] %s\n', stamp, sprintf(fmt, varargin{:}));
catch ME
    % Diagnostics must not replace the experiment's original error.
    fprintf(2, 'Progress log unavailable: %s\n', ME.message);
end
end
