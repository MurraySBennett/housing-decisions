function run = beginRun(sess, taskName, domains)
%UTILS.BEGINRUN  Register the start of one task run for this participant.
%   run = utils.beginRun(sess, 'auction')                  uses sess.domains
%   run = utils.beginRun(sess, 'auction', {'jobs'})         jobs only, this run
%   Call utils.endRun when the task finishes or crashes.

if nargin < 3 || isempty(domains), domains = sess.domains; end
if ischar(domains) || isstring(domains), domains = {char(domains)}; end

taskName = lower(char(taskName));
assert(isfield(sess.cfg.paths.taskData, taskName), ...
    'hw:beginRun:unknownTask', 'No data path configured for task "%s".', taskName);

old = load(sess.manifestFile, 'manifest');
for k = 1:numel(old.manifest.runs)
    previous = old.manifest.runs(k);
    if strcmp(previous.task, taskName) && previous.sessionNum == sess.sessionNum
        assert(isfile(fullfile(sess.cfg.paths.runs, previous.runId, 'run.mat')), ...
            'hw:beginRun:legacy', 'This session has legacy task data without block receipts. Do not restart it as a new-format run.');
    end
end

run = utils.runCheckpoint('open', sess, taskName, domains);
rng(run.seed, 'twister');

% --- Append a provisional entry to the manifest -----------------------
entry = struct( ...
    'task',           taskName, ...
    'sessionNum',     sess.sessionNum, ...
    'runId',          run.runId, ...
    'runKind',        sess.runKind, ...
    'domainOrderStr', run.domainStr, ...
    'startedAt',      run.startedAt, ...
    'finishedAt',     '', ...
    'status',         'started', ...
    'dataFile',       [run.fileStem '.mat'], ...
    'seed',           run.seed, ...
    'codeVersion',    sess.codeVersion);

logFile = utils.progressLog(run, 'RUN START task=%s domains=%s version=%s MATLAB=%s code=%s data=%s', ...
    run.task, run.domainStr, sess.codeVersion, version, mfilename('fullpath'), run.fileStem);
fprintf('Local progress log: %s\n', logFile);
utils.progressLog(run, 'BEGIN manifest append: %s', sess.manifestFile);
existing = load(sess.manifestFile, 'manifest');
if isempty(existing.manifest.runs) || ~any(strcmp({existing.manifest.runs.runId}, run.runId))
    utils.appendRun(sess.manifestFile, entry);
end
utils.progressLog(run, 'END manifest append');

fprintf('Run started: %s (seed %d)\n', run.runId, run.seed);

end
