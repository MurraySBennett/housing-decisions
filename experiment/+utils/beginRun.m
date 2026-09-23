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

run.task        = taskName;
run.domains     = domains;
run.domainStr   = strjoin(domains, '+');
run.participant = sess.participant;
run.sessionNum  = sess.sessionNum;
run.startedAt   = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
run.stamp       = char(datetime('now','Format','yyyyMMdd_HHmmss'));

% Run id carries the domain set so same-task runs over different domains don't collide.
run.runId = sprintf('sub-%05d_ses-%02d_task-%s_dom-%s_%s', ...
    sess.participant, sess.sessionNum, taskName, run.domainStr, run.stamp);

run.dataDir  = sess.cfg.paths.taskData.(taskName);
run.fileStem = fullfile(run.dataDir, run.runId);
run.gazeFile = fullfile(sess.cfg.paths.gaze, [run.runId '_gaze.mat']);

% --- Deterministic, reproducible seeding ------------------------------
% Seed from participant+session+task+domains: replayable, no two runs share a stream.
run.seed = utils.taskSeed(sess.participant, sess.sessionNum, ...
    [taskName '_' run.domainStr]);
run.rngState = rng(run.seed, 'twister');

% --- Append a provisional entry to the manifest -----------------------
entry = struct( ...
    'task',           taskName, ...
    'sessionNum',     sess.sessionNum, ...
    'runId',          run.runId, ...
    'domainOrderStr', run.domainStr, ...
    'startedAt',      run.startedAt, ...
    'finishedAt',     '', ...
    'status',         'started', ...
    'dataFile',       [run.fileStem '.mat'], ...
    'seed',           run.seed, ...
    'codeVersion',    sess.codeVersion);

utils.appendRun(sess.manifestFile, entry);

fprintf('Run started: %s (seed %d)\n', run.runId, run.seed);

end
