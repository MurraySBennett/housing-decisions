function out = blockStore(action, cfg, varargin)
%UTILS.BLOCKSTORE Immutable attempts; verified receipts are completion authority.
switch lower(action)
    case 'begin'
        context = varargin{1}; entryState = varargin{2};
        validateContext(context);
        attempt = context;
        attempt.attemptId = utils.checkpointIO('id');
        attempt.directory = fullfile(runRoot(cfg, context.logicalRunId), ...
            sprintf('block-%04d', context.blockOrdinal), ['attempt-' attempt.attemptId]);
        attempt.startedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
        utils.checkpointIO('write', fullfile(attempt.directory, 'entry.mat'), ...
            struct('attempt', attempt, 'entryState', entryState));
        out = attempt;
    case 'commit'
        attempt = varargin{1}; payload = varargin{2};
        validateContext(attempt);
        assert(strcmp(attempt.directory, fullfile(runRoot(cfg, attempt.logicalRunId), ...
            sprintf('block-%04d', attempt.blockOrdinal), ['attempt-' attempt.attemptId])), ...
            'hw:blockStore:path', 'Attempt directory is outside the configured run.');
        behavior = rmfield(payload, 'gaze');
        behavior.identity = attempt;
        behavior.expectedSamples = numel(payload.gaze);
        utils.checkpointIO('write', fullfile(attempt.directory, 'behavior.mat'), struct('behavior', behavior));
        packed = utils.gazeCodec('pack', payload.gaze);
        assert(isequaln(utils.gazeCodec('unpack', packed), payload.gaze), ...
            'hw:blockStore:roundtrip', 'Gaze packing changed values. Behavioral data is preserved.');
        gaze = struct('identity', attempt, 'packed', packed, ...
            'clockSync', payload.clockSync, 'metadata', payload.metadata, ...
            'association', utils.alignBlockGaze(packed, payload.events, payload.clockSync));
        utils.checkpointIO('write', fullfile(attempt.directory, 'gaze.mat'), struct('gaze', gaze));
        % This transaction descriptor follows BOTH validated artifacts. Recovery
        % can finish receipt publication after a process kill from this point.
        receipt = makeReceipt(attempt, behavior, gaze);
        utils.checkpointIO('write', fullfile(attempt.directory, 'prepared.mat'), struct('receipt', receipt));
        validateReceipt(attempt.directory, receipt);
        utils.checkpointIO('write', fullfile(attempt.directory, 'receipt.mat'), struct('receipt', receipt));
        out = receipt;
    case {'scan', 'recover'}
        root = runRoot(cfg, varargin{1});
        out = struct('receipts', [], 'nextBlock', 1, 'entryState', [], ...
            'nextState', [], 'incomplete', {{}}, 'parentAttemptId', '');
        entries = dir(fullfile(root, 'block-*', 'attempt-*', 'entry.mat'));
        candidate = [];
        for k = 1:numel(entries)
            folder = entries(k).folder;
            entry = load(fullfile(folder, 'entry.mat'), 'attempt', 'entryState');
            entry.artifactDirectory = folder;
            attempt = entry.attempt;
            validateContext(attempt);
            assert(strcmp(attempt.logicalRunId, varargin{1}), 'hw:blockStore:identity', 'Logical run mismatch.');
            rf = fullfile(folder, 'receipt.mat'); pf = fullfile(folder, 'prepared.mat');
            orphan = [];
            if ~isfile(rf) && ~isfile(pf) && isfile(fullfile(folder, 'behavior.mat')) && ...
                    isfile(fullfile(folder, 'gaze.mat'))
                try
                    b = load(fullfile(folder, 'behavior.mat'), 'behavior');
                    g = load(fullfile(folder, 'gaze.mat'), 'gaze');
                    orphan = makeReceipt(attempt, b.behavior, g.gaze, folder);
                    validateReceipt(folder, orphan);
                    if ~strcmpi(action, 'recover'), orphan = []; end
                catch
                    orphan = [];
                    % Uncommitted invalid files remain an interrupted attempt.
                end
            end
            if isfile(rf) || isfile(pf) || ~isempty(orphan)
                try
                    if isfile(rf), r = load(rf, 'receipt');
                    elseif isfile(pf), r = load(pf, 'receipt');
                    else, r = struct('receipt', orphan); end
                    validateReceipt(folder, r.receipt);
                    assert(isequaln(r.receipt.identity, attempt), 'hw:blockStore:identity', 'Entry/receipt mismatch.');
                catch ME
                    error('hw:blockStore:corrupt', 'Invalid committed/prepared block at %s: %s', folder, ME.message);
                end
                r.receipt.artifactDirectory = folder;
                if isempty(candidate), candidate = r.receipt; else, candidate(end+1) = r.receipt; end %#ok<AGROW>
            else
                out.incomplete{end+1} = entry;
            end
        end
        parent = ''; ordinal = 1;
        while ~isempty(candidate)
            ix = find([candidate.blockOrdinal] == ordinal & strcmp({candidate.parentAttemptId}, parent));
            assert(numel(ix) <= 1, 'hw:blockStore:conflict', 'Multiple completed attempts for block %d.', ordinal);
            if isempty(ix), break; end
            r = candidate(ix);
            if isempty(out.receipts), out.receipts = r; else, out.receipts(end+1) = r; end %#ok<AGROW>
            b = load(fullfile(r.artifactDirectory, 'behavior.mat'), 'behavior');
            out.nextState = b.behavior.nextState;
            parent = r.attemptId; ordinal = ordinal + 1;
            candidate(ix) = [];
        end
        assert(isempty(candidate), 'hw:blockStore:lineage', 'Completed blocks have missing or conflicting ancestry.');
        if strcmpi(action, 'recover')
            for k = 1:numel(out.receipts)
                receipt = out.receipts(k); folder = receipt.artifactDirectory;
                receipt = rmfield(receipt, 'artifactDirectory');
                utils.checkpointIO('write', fullfile(folder,'prepared.mat'), struct('receipt',receipt));
                utils.checkpointIO('write', fullfile(folder,'receipt.mat'), struct('receipt',receipt));
            end
        end
        out.nextBlock = ordinal; out.parentAttemptId = parent;
        for k = 1:numel(out.incomplete)
            e = out.incomplete{k};
            if e.attempt.blockOrdinal ~= ordinal || ~strcmp(e.attempt.parentAttemptId, parent), continue; end
            if isempty(out.entryState), out.entryState = e.entryState;
            else
                assert(isequaln(out.entryState, e.entryState), 'hw:blockStore:conflict', ...
                    'Interrupted attempts disagree on block-entry state.');
            end
        end
    otherwise
        error('hw:blockStore:action', 'Unknown block-store action %s.', action);
end
end
function root = runRoot(cfg, id)
assert(ischar(id) && ~isempty(regexp(id, '^[A-Za-z0-9_-]+$', 'once')), ...
    'hw:blockStore:id', 'Invalid logical run ID.');
root = fullfile(cfg.paths.checkpoints, id);
end
function validateContext(c)
assert(c.schemaVersion == 1 && isscalar(c.blockOrdinal) && ...
    c.blockOrdinal >= 1 && c.blockOrdinal == fix(c.blockOrdinal), ...
    'hw:blockStore:context', 'Invalid checkpoint schema or block ordinal.');
for name = {'participant','session','task','domain','runKind','logicalRunId','parentAttemptId'}
    assert(isfield(c, name{1}), 'hw:blockStore:context', 'Missing %s', name{1});
end
end
function receipt = makeReceipt(a, behavior, gaze, folder)
if nargin < 4, folder = a.directory; end
receipt = struct('schemaVersion', 1, 'identity', a, 'attemptId', a.attemptId, ...
    'blockOrdinal', a.blockOrdinal, 'parentAttemptId', a.parentAttemptId, ...
    'trialCount', height(behavior.trialTable), 'sampleCount', gaze.packed.sampleCount, ...
    'files', struct('entry', utils.checkpointIO('hash', fullfile(folder, 'entry.mat')), ...
                    'behavior', utils.checkpointIO('hash', fullfile(folder, 'behavior.mat')), ...
                    'gaze', utils.checkpointIO('hash', fullfile(folder, 'gaze.mat'))));
end
function validateReceipt(folder, r)
assert(r.schemaVersion == 1, 'hw:blockStore:schema', 'Unknown receipt schema.');
assert(r.blockOrdinal == r.identity.blockOrdinal && strcmp(r.attemptId,r.identity.attemptId) && ...
    strcmp(r.parentAttemptId,r.identity.parentAttemptId), 'hw:blockStore:identity', 'Receipt identity mismatch.');
assert(strcmp(utils.checkpointIO('hash', fullfile(folder, 'entry.mat')), r.files.entry) && ...
    strcmp(utils.checkpointIO('hash', fullfile(folder, 'behavior.mat')), r.files.behavior) && ...
    strcmp(utils.checkpointIO('hash', fullfile(folder, 'gaze.mat')), r.files.gaze), ...
    'hw:blockStore:digest', 'Artifact fingerprint mismatch.');
b = load(fullfile(folder, 'behavior.mat'), 'behavior');
g = load(fullfile(folder, 'gaze.mat'), 'gaze');
assert(isequaln(b.behavior.identity, r.identity) && isequaln(g.gaze.identity, r.identity) && ...
    height(b.behavior.trialTable) == r.trialCount && g.gaze.packed.sampleCount == r.sampleCount && ...
    b.behavior.expectedSamples == r.sampleCount, ...
    'hw:blockStore:identity', 'Artifact identity or count mismatch.');
% Unpack validates the column schema/classes/shapes; raw data is never inferred.
utils.gazeCodec('validate', g.gaze.packed);
end
