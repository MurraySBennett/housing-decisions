function out = scanBlocks(cfg, logicalRunId)
%UTILS.SCANBLOCKS What one logical run has actually completed. Read-only.
%
% Walks <checkpoints>/<logicalRunId>/block-*/attempt-*, keeps every attempt
% whose descriptor (receipt.mat, or prepared.mat when the final write was
% lost) validates against its artifact hashes, and chains them by
% parentAttemptId from block 1 upward. Returns:
%
%   receipts         the verified chain, each with .artifactDirectory
%   nextBlock        first block ordinal with no verified attempt
%   entryState       the state the next block's interrupted attempt(s)
%                    recorded at entry, or [] if none
%   nextState        the state the last verified block said comes next
%   incomplete       attempts with no valid descriptor (never resurrected:
%                    a kill that lost both descriptors means that block is
%                    REDONE from its entry state -- policy 2026-10-22)
%   parentAttemptId  what the next attempt must name as its parent
%
% Used by the tasks (through utils.recoverBlocks), by utils.runComplete, and
% by scripts/combine_blocks.m and scripts/sync_blocks.m -- the scan is the
% single authority on "which blocks count".
out = struct('receipts', [], 'nextBlock', 1, 'entryState', [], ...
    'nextState', [], 'incomplete', {{}}, 'parentAttemptId', '');
root = blockRunRoot(cfg, logicalRunId);
entries = dir(fullfile(root, 'block-*', 'attempt-*', 'entry.mat'));
candidate = [];
for k = 1:numel(entries)
    folder = entries(k).folder;
    entry = load(fullfile(folder, 'entry.mat'), 'attempt', 'entryState');
    entry.artifactDirectory = folder;
    attempt = entry.attempt;
    validateBlockContext(attempt);
    assert(strcmp(attempt.logicalRunId, logicalRunId), 'hw:blockStore:identity', 'Logical run mismatch.');
    rf = fullfile(folder, 'receipt.mat'); pf = fullfile(folder, 'prepared.mat');
    if isfile(rf) || isfile(pf)
        try
            if isfile(rf), r = load(rf, 'receipt'); else, r = load(pf, 'receipt'); end
            validateBlockReceipt(folder, r.receipt);
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
end
