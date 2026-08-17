function run = beginRun(sess, taskName, domains)
%UTILS.BEGINRUN  Register the start of one task run for this participant.
%
%   run = utils.beginRun(sess, 'auction')                  uses sess.domains
%   run = utils.beginRun(sess, 'auction', {'jobs'})         jobs only, this run
%   run = utils.beginRun(sess, 'contdc',  {'houses'})       houses only
%
%   Domains are now a property of the RUN, not just the session, so one
%   participant can do jobs-only auction, houses-only contdc, both domains
%   in one task, or any other combination -- rather than every task in a
%   session necessarily covering the same domain(s).
%
%   Returns a struct with the run id, the deterministic RNG seed for this
%   participant+session+task+domain-set, and the output file stem. Call
%   utils.endRun when the task finishes (or crashes) so the manifest reflects
%   reality.

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

% Run id now carries the domain set, so e.g. a jobs-only auction run and a
% houses-only auction run for the same participant/session don't collide:
% sub-00012_ses-01_task-auction_dom-jobs_20260721_143205
run.runId = sprintf('sub-%05d_ses-%02d_task-%s_dom-%s_%s', ...
    sess.participant, sess.sessionNum, taskName, run.domainStr, run.stamp);

run.dataDir  = sess.cfg.paths.taskData.(taskName);
run.fileStem = fullfile(run.dataDir, run.runId);
run.gazeFile = fullfile(sess.cfg.paths.gaze, [run.runId '_gaze.mat']);

% --- Deterministic, reproducible seeding ------------------------------
% Derived from participant+session+task+domains, so a session can be
% replayed exactly (important for the model fits) but no two runs share a
% stream -- including two runs of the same task over different domains.
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
