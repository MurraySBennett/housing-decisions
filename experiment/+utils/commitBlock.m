function receipt = commitBlock(cfg, attempt, payload)
%UTILS.COMMITBLOCK Turn one finished block attempt into a verified block.
%
% THE WRITE PATH, top to bottom. Four files land in the attempt directory,
% in this order, each through utils.checkpointIO's verified write:
%
%   behavior.mat  everything except gaze: trials, trialTable, events,
%                 metadata, clockSync, nextState. Written FIRST so a failure
%                 anywhere in the gaze path can never lose behavior.
%   gaze.mat      the packed gaze (utils.gazeCodec) with its trial/phase
%                 association (utils.alignBlockGaze).
%   prepared.mat  the receipt, written before receipt.mat: the two-phase
%                 descriptor. A kill between the two is healed by
%                 utils.recoverBlocks, which republishes receipt.mat.
%   receipt.mat   the completion authority. utils.scanBlocks counts a block
%                 done only when a descriptor validates against the artifact
%                 hashes it names.
%
% payload must carry: trials, trialTable, events, metadata, clockSync, gaze
% (raw samples), nextState.
validateBlockContext(attempt);
assert(strcmp(attempt.directory, fullfile(blockRunRoot(cfg, attempt.logicalRunId), ...
    sprintf('block-%04d', attempt.blockOrdinal), ['attempt-' attempt.attemptId])), ...
    'hw:blockStore:path', 'Attempt directory is outside the configured run.');
behavior = rmfield(payload, 'gaze');
behavior.identity = attempt;
behavior.expectedSamples = numel(payload.gaze);
utils.checkpointIO('write', fullfile(attempt.directory, 'behavior.mat'), struct('behavior', behavior));
packed = utils.gazeCodec('pack', payload.gaze);
% Compare the PLAIN representations, not reconstructed SDK objects.
% What this file stores is `packed` (below) -- no GazeData object is
% ever written -- so plain-to-plain is the fidelity that matters, and it
% checks every leaf of every sample just as the old form did.
%
% The old form unpacked all the way back to GazeData, which made the
% commit depend on gazeCodec's hardcoded SDK field names. On 2026-10-09
% that killed every block on the R2024b rig (GazeOrigin has no
% InTrackBoxCoordinateSystem there) AFTER behavior.mat was written and
% BEFORE gaze.mat, so each block lost its gaze to the emergency folder.
% The rigs carry different SDK builds with different spellings, so no
% hardcoded list belongs anywhere in the save path.
assert(utils.gazeCodec('verify', packed, payload.gaze), ...
    'hw:blockStore:roundtrip', 'Gaze packing changed values. Behavioral data is preserved.');
gaze = struct('identity', attempt, 'packed', packed, ...
    'clockSync', payload.clockSync, 'metadata', payload.metadata, ...
    'association', utils.alignBlockGaze(packed, payload.events, payload.clockSync));
utils.checkpointIO('write', fullfile(attempt.directory, 'gaze.mat'), struct('gaze', gaze));
receipt = makeReceipt(attempt, behavior, gaze);
utils.checkpointIO('write', fullfile(attempt.directory, 'prepared.mat'), struct('receipt', receipt));
validateBlockReceipt(attempt.directory, receipt);
utils.checkpointIO('write', fullfile(attempt.directory, 'receipt.mat'), struct('receipt', receipt));
end

function receipt = makeReceipt(a, behavior, gaze)
folder = a.directory;
receipt = struct('schemaVersion', 1, 'identity', a, 'attemptId', a.attemptId, ...
    'blockOrdinal', a.blockOrdinal, 'parentAttemptId', a.parentAttemptId, ...
    'trialCount', height(behavior.trialTable), 'sampleCount', gaze.packed.sampleCount, ...
    'files', struct('entry', utils.checkpointIO('hash', fullfile(folder, 'entry.mat')), ...
                    'behavior', utils.checkpointIO('hash', fullfile(folder, 'behavior.mat')), ...
                    'gaze', utils.checkpointIO('hash', fullfile(folder, 'gaze.mat'))));
end
