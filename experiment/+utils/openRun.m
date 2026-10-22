function run = openRun(sess, task, domains)
%UTILS.OPENRUN The frozen logical identity of one task run.
%
% First call for a (participant, session, task, domains) writes run.mat and
% returns a fresh identity. Every later call returns THE SAME identity --
% same runId, same seed -- or refuses outright when the saved signature
% (code, config, assignment, stimuli; see utils.runSignature) no longer
% matches. That refusal is the rule that a run interrupted under one code
% version is never resumed under another.
%
% utils.beginRun wraps this with the manifest entry and progress log; tasks
% and tests that only need the identity call this directly.
task = char(task);
if ischar(domains) || isstring(domains), domains = cellstr(domains); end
utils.sessionContext('run', sess, task, domains);
id = sprintf('sub-%05d_ses-%02d_task-%s_dom-%s', ...
    sess.participant, sess.sessionNum, task, strjoin(domains, '-'));
file = fullfile(sess.cfg.paths.runs, id, 'run.mat');
signature = utils.runSignature(sess);
if isfile(file)
    saved = load(file, 'record');
    assert(isequaln(saved.record.signature, signature), ...
        'hw:runCheckpoint:incompatible', ...
        'Saved assignment/configuration/code differs for %s. Do not mix runs.', id);
    run = localPaths(saved.record.run, sess.cfg); return;
end
run = struct('schemaVersion', 1, 'runId', id, 'logicalRunId', id, ...
    'task', task, 'domains', {domains}, 'domainStr', strjoin(domains, '+'), ...
    'participant', sess.participant, 'sessionNum', sess.sessionNum, ...
    'runKind', sess.runKind, 'startedAt', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'stamp', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')), ...
    'dataDir', sess.cfg.paths.taskData.(task));
run.fileStem = fullfile(run.dataDir, id);
run.gazeFile = fullfile(sess.cfg.paths.gaze, [id '_gaze.mat']);
run.seed = taskSeed(sess.participant, sess.sessionNum, [task '_' run.domainStr]);
run.rngState = rng; % diagnostic; actual block entry states are explicit.
record = struct('signature', signature, 'run', run);
utils.checkpointIO('write', file, struct('record', record));
end

function run = localPaths(run, cfg)
% Stored identity travels; live output paths always belong to this rig.
run.dataDir = cfg.paths.taskData.(run.task);
run.fileStem = fullfile(run.dataDir, run.runId);
run.gazeFile = fullfile(cfg.paths.gaze, [run.runId '_gaze.mat']);
end

function seed = taskSeed(participant, sessionNum, taskName)
%TASKSEED Deterministic 32-bit seed from participant/session/task.
% Same inputs always give the same seed, so a session is replayable;
% different inputs are extremely unlikely to collide.
key = sprintf('%d|%d|%s', participant, sessionNum, lower(char(taskName)));
% Simple FNV-1a hash -- no toolbox or Java dependency.
h = uint32(2166136261);
prime = uint32(16777619);
b = uint32(double(key));
for k = 1:numel(b)
    h = bitxor(h, b(k));
    h = uint32(mod(double(h) * double(prime), 2^32));
end
% MATLAB's Twister accepts 0..2^32-1.
seed = double(h);
end
