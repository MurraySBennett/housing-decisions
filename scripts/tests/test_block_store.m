function tests = test_block_store
% Catch false completion after partial writes and mutation of older attempts.
tests = functiontests(localfunctions);
end
function setup(testCase)
root = tempname; mkdir(root);
testCase.TestData.root = root;
testCase.TestData.cfg.paths.checkpoints = fullfile(root, 'blocks');
end
function teardown(testCase)
rmdir(testCase.TestData.root, 's');
end
function testValidCommitAndStaleReceipt(testCase)
cfg = testCase.TestData.cfg;
c = context();
a = utils.beginBlock(cfg, c, struct('seed', 4));
p = payload();
r = utils.commitBlock(cfg, a, p);
s = utils.scanBlocks(cfg, c.logicalRunId);
verifyEqual(testCase, s.nextBlock, 2);
verifyEqual(testCase, s.receipts(1).attemptId, a.attemptId);
f = fullfile(a.directory, 'behavior.mat');
before = utils.checkpointIO('hash', f);
delete(fullfile(a.directory, 'receipt.mat'));
s = utils.scanBlocks(cfg, c.logicalRunId);
verifyEqual(testCase, s.nextBlock, 2);
verifyEqual(testCase, utils.checkpointIO('hash', f), before);
verifyEqual(testCase, s.receipts(1).files, r.files);
end
function testIncompleteRetryIsSeparate(testCase)
cfg = testCase.TestData.cfg; c = context();
a = utils.beginBlock(cfg, c, struct('seed', 4));
s = utils.scanBlocks(cfg, c.logicalRunId);
verifyEqual(testCase, s.nextBlock, 1);
verifyEqual(testCase, s.entryState.seed, 4);
b = utils.beginBlock(cfg, c, s.entryState);
verifyNotEqual(testCase, a.attemptId, b.attemptId);
verifyTrue(testCase, isfolder(a.directory));
end
function testCorruptArtifactNotComplete(testCase)
cfg = testCase.TestData.cfg; c = context();
a = utils.beginBlock(cfg, c, struct());
utils.commitBlock(cfg, a, payload());
fid = fopen(fullfile(a.directory, 'gaze.mat'), 'w'); fwrite(fid, 'truncated'); fclose(fid);
verifyError(testCase, @() utils.scanBlocks(cfg, c.logicalRunId), 'hw:blockStore:corrupt');
end
function testDisabledTracker(testCase)
cfg = testCase.TestData.cfg; c = context();
a = utils.beginBlock(cfg, c, struct());
p = payload(); p.gaze = [];
utils.commitBlock(cfg, a, p);
s = utils.scanBlocks(cfg, c.logicalRunId);
verifyEqual(testCase, s.receipts(1).sampleCount, 0);
end
function c = context
c = struct('schemaVersion', 1, 'logicalRunId', 'test-run', 'participant', 9999, ...
    'session', 1, 'task', 'contdc', 'domain', 'houses', 'runKind', 'practice', ...
    'blockOrdinal', 1, 'parentAttemptId', '');
end
function p = payload
p = struct('trials', struct('trial', 1), 'trialTable', table(1, 'VariableNames', {'trial'}), ...
    'events', table(), 'metadata', struct(), 'gaze', struct('SystemTimeStamp', uint64(25)), ...
    'clockSync', struct(), 'nextState', struct('seed', 8));
end

function testLocalConfigDoesNotProbeShare(testCase)
cfg = utils.config('projRoot', testCase.TestData.root, ...
    'localDataRoot', fullfile(testCase.TestData.root, 'local'), ...
    'dataRoot', fullfile(testCase.TestData.root, 'not-created-share'), ...
    'testing', true, 'runKind', 'practice');
verifyEqual(testCase, cfg.paths.data, fullfile(testCase.TestData.root, 'local', 'practice'));
verifyFalse(testCase, isfolder(fullfile(testCase.TestData.root, 'not-created-share')));
verifyTrue(testCase, isfolder(cfg.paths.checkpoints));
end
function testMissingDescriptorsMeanRedo(testCase)
% POLICY (2026-10-22): with BOTH descriptors gone -- a kill between gaze.mat
% and prepared.mat -- the block is REDONE, not resurrected from its artifacts.
% The old orphan-reconstruction branch rebuilt a receipt from behavior+gaze;
% it was the hardest-to-read part of the store and bought one rare kill
% window. Losing it costs repeating one block. The entry state survives, so
% the redo starts from the exact state the lost attempt started from.
cfg = testCase.TestData.cfg; c = context();
a = utils.beginBlock(cfg,c,struct('seed',4));
utils.commitBlock(cfg,a,payload());
delete(fullfile(a.directory,'receipt.mat')); delete(fullfile(a.directory,'prepared.mat'));
s = utils.scanBlocks(cfg,c.logicalRunId);
verifyEqual(testCase,s.nextBlock,1);
verifyEqual(testCase,s.entryState.seed,4);
end

function testRecoverRepublishesDescriptors(testCase)
% recoverBlocks finishes two-phase descriptor publication: a receipt.mat lost
% after prepared.mat was written comes back on the next recovery, and the
% loaded behaviors ride along for the task to reassemble its trials.
cfg = testCase.TestData.cfg; c = context(); c.logicalRunId = 'myrun_houses';
a = utils.beginBlock(cfg,c,struct('seed',4));
utils.commitBlock(cfg,a,payload());
delete(fullfile(a.directory,'receipt.mat'));
sess = struct('cfg', cfg);
run = struct('runId', 'myrun', 'task', 'contdc');
out = utils.recoverBlocks(sess, run, 'houses');
verifyTrue(testCase, isfile(fullfile(a.directory,'receipt.mat')), ...
    'recovery must republish the receipt from prepared.mat');
verifyEqual(testCase, numel(out.blocks), 1);
verifyEqual(testCase, out.blocks{1}.trials.trial, 1);
verifyEqual(testCase, out.nextBlock, 2);
end
function testBehaviorOnlyDoesNotComplete(testCase)
cfg = testCase.TestData.cfg; c = context();
a = utils.beginBlock(cfg,c,struct('seed',4));
p = payload(); behavior = rmfield(p,'gaze'); behavior.identity = a;
utils.checkpointIO('write',fullfile(a.directory,'behavior.mat'),struct('behavior',behavior));
s = utils.scanBlocks(cfg,c.logicalRunId);
verifyEqual(testCase,s.nextBlock,1);
verifyEqual(testCase,s.entryState.seed,4);
end
function testTwoValidAttemptsConflict(testCase)
cfg = testCase.TestData.cfg; c = context();
a = utils.beginBlock(cfg,c,struct('seed',4));
b = utils.beginBlock(cfg,c,struct('seed',4));
utils.commitBlock(cfg,a,payload()); utils.commitBlock(cfg,b,payload());
verifyError(testCase,@() utils.scanBlocks(cfg,c.logicalRunId),'hw:blockStore:conflict');
end
function testUnsupportedGazeKeepsBehavior(testCase)
cfg = testCase.TestData.cfg; c = context();
a = utils.beginBlock(cfg,c,struct('seed',4));
p = payload(); p.gaze = struct('unsupported',{{1,2}});
try
    utils.commitBlock(cfg,a,p);
    verifyFail(testCase,'Unknown leaf silently accepted.');
catch ME
    verifyTrue(testCase,startsWith(ME.identifier,'hw:gazeCodec:'));
end
verifyTrue(testCase,isfile(fullfile(a.directory,'behavior.mat')));
verifyFalse(testCase,isfile(fullfile(a.directory,'receipt.mat')));
end
