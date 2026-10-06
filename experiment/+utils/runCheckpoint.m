function out = runCheckpoint(action, sess, varargin)
%UTILS.RUNCHECKPOINT Frozen logical identity and plans, independent of attempts.
switch lower(action)
    case 'open'
        task = char(varargin{1}); domains = varargin{2};
        if ischar(domains) || isstring(domains), domains = cellstr(domains); end
        id = sprintf('sub-%05d_ses-%02d_task-%s_dom-%s', ...
            sess.participant, sess.sessionNum, task, strjoin(domains, '-'));
        file = fullfile(sess.cfg.paths.runs, id, 'run.mat');
        signature = fingerprint(sess);
        if isfile(file)
            saved = load(file, 'record');
            assert(isequaln(saved.record.signature, signature), ...
                'hw:runCheckpoint:incompatible', ...
                'Saved assignment/configuration/code differs for %s. Do not mix runs.', id);
            out = localPaths(saved.record.run, sess.cfg); return;
        end
        out = struct('schemaVersion', 1, 'runId', id, 'logicalRunId', id, ...
            'task', task, 'domains', {domains}, 'domainStr', strjoin(domains, '+'), ...
            'participant', sess.participant, 'sessionNum', sess.sessionNum, ...
            'runKind', sess.runKind, 'startedAt', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
            'stamp', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')), ...
            'dataDir', sess.cfg.paths.taskData.(task));
        out.fileStem = fullfile(out.dataDir, id);
        out.gazeFile = fullfile(sess.cfg.paths.gaze, [id '_gaze.mat']);
        out.seed = utils.taskSeed(sess.participant, sess.sessionNum, [task '_' out.domainStr]);
        out.rngState = rng; % diagnostic; actual block entry states are explicit.
        record = struct('signature', signature, 'run', out);
        utils.checkpointIO('write', file, struct('record', record));
    case 'freeze'
        run = varargin{1}; domain = varargin{2}; proposed = varargin{3};
        file = fullfile(sess.cfg.paths.runs, run.runId, [domain '-plan.mat']);
        if isfile(file)
            s = load(file, 'frozen'); out = s.frozen;
        else
            utils.checkpointIO('write', file, struct('frozen', proposed)); out = proposed;
        end
    case 'peek'
        run = varargin{1}; domain = varargin{2};
        file = fullfile(sess.cfg.paths.runs, run.runId, [domain '-plan.mat']);
        out = [];
        if isfile(file), s = load(file, 'frozen'); out = s.frozen; end
    case 'resolve'
        run = varargin{1}; domain = varargin{2};
        out = utils.blockStore('recover', sess.cfg, [run.runId '_' domain]);
    case 'complete'
        run = varargin{1}; out = true;
        for k = 1:numel(run.domains)
            domain = run.domains{k};
            frozen = utils.runCheckpoint('peek', sess, run, domain);
            if isempty(frozen) || ~isfield(frozen, 'blockCount'), out = false; return; end
            state = utils.runCheckpoint('resolve', sess, run, domain);
            if numel(state.receipts) ~= frozen.blockCount, out = false; return; end
        end
    otherwise
        error('hw:runCheckpoint:action', 'Unknown checkpoint action %s.', action);
end
end
function signature = fingerprint(sess)
c = sess.cfg;
% Paths can move across rigs. Values and source/stimulus contents cannot change.
for field = {'paths', 'stimFiles', 'codeVersion'}
    if isfield(c, field{1}), c = rmfield(c, field{1}); end
end
signature = struct('schemaVersion', 1, 'assignment', sess.assignment, ...
    'config', plain(c), 'codeVersion', sess.codeVersion, 'sources', [], 'stimuli', struct());
root = fileparts(fileparts(mfilename('fullpath')));
files = [dir(fullfile(root, '*.m')); dir(fullfile(root, '+utils', '*.m'))];
[~, order] = sort({files.name}); files = files(order);
signature.sources = cell(numel(files), 2);
for k = 1:numel(files)
    signature.sources(k,:) = {files(k).name, utils.checkpointIO('hash', fullfile(files(k).folder, files(k).name))};
end
stimFiles = sess.cfg.stimFiles;
% Preference jobs always use this ecological definition regardless of auction arm.
stimFiles.preferenceJobs = fullfile(sess.cfg.paths.prepared, 'job_stimuli_ecological.csv');
names = fieldnames(stimFiles);
for k = 1:numel(names)
    path = stimFiles.(names{k});
    if isfile(path)
        signature.stimuli.(names{k}) = utils.checkpointIO('hash', path);
    else
        signature.stimuli.(names{k}) = 'missing';
    end
end
end
function v = plain(v)
if isa(v, 'function_handle')
    v = func2str(v);
elseif isstruct(v)
    names = fieldnames(v);
    for i = 1:numel(v)
        for j = 1:numel(names), v(i).(names{j}) = plain(v(i).(names{j})); end
    end
elseif iscell(v)
    for i = 1:numel(v), v{i} = plain(v{i}); end
end
end

function run = localPaths(run,cfg)
% Stored identity travels; live output paths always belong to this rig.
run.dataDir = cfg.paths.taskData.(run.task);
run.fileStem = fullfile(run.dataDir,run.runId);
run.gazeFile = fullfile(cfg.paths.gaze,[run.runId '_gaze.mat']);
end
