function out = recoverBlocks(sess, run, domain)
%UTILS.RECOVERBLOCKS Pick a domain run back up from its verified blocks.
%
% utils.scanBlocks decides which blocks count; this adds the three things a
% resuming TASK needs on top of the scan:
%   1. finish two-phase descriptor publication -- a receipt.mat lost after
%      prepared.mat was written is republished, so the next scan is whole;
%   2. load every verified block's behavior.mat into .blocks (and its event
%      log into .events) -- each task reassembles its own trials from these,
%      because the tasks' trial shapes differ by design;
%   3. default .entryState to .nextState, so "nothing interrupted" and
%      "retry the interrupted attempt" read the same way in the task loop.
out = utils.scanBlocks(sess.cfg, [run.runId '_' domain]);
for k = 1:numel(out.receipts)
    receipt = out.receipts(k); folder = receipt.artifactDirectory;
    receipt = rmfield(receipt, 'artifactDirectory');
    utils.checkpointIO('write', fullfile(folder, 'prepared.mat'), struct('receipt', receipt));
    utils.checkpointIO('write', fullfile(folder, 'receipt.mat'), struct('receipt', receipt));
end
out.blocks = {}; out.events = {};
for k = 1:numel(out.receipts)
    b = load(fullfile(out.receipts(k).artifactDirectory, 'behavior.mat'), 'behavior');
    out.blocks{end+1} = b.behavior; %#ok<AGROW>
    out.events{end+1} = b.behavior.events; %#ok<AGROW>
end
if isempty(out.entryState), out.entryState = out.nextState; end
fprintf('Recovery %s [%s]: %d verified block(s), next block %d\n', ...
    run.task, domain, numel(out.receipts), out.nextBlock);
end
