function attempt = beginBlock(cfg, context, entryState)
%UTILS.BEGINBLOCK Open an immutable block attempt and record its entry state.
%
% Every attempt gets its own directory, named by a fresh attempt id, under
% <checkpoints>/<logicalRunId>/block-NNNN/. entry.mat stores the exact state
% (RNG, plan position) the block started from, so an interrupted attempt can
% be RETRIED from the same state -- never resumed in place, never mutated.
% utils.commitBlock turns an attempt into a verified block; utils.scanBlocks
% reads the result.
validateBlockContext(context);
attempt = context;
attempt.attemptId = utils.checkpointIO('id');
attempt.directory = fullfile(blockRunRoot(cfg, context.logicalRunId), ...
    sprintf('block-%04d', context.blockOrdinal), ['attempt-' attempt.attemptId]);
attempt.startedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
utils.checkpointIO('write', fullfile(attempt.directory, 'entry.mat'), ...
    struct('attempt', attempt, 'entryState', entryState));
end
