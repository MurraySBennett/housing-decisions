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
function validCommitAndStaleReceipt(testCase)
cfg = testCase.TestData.cfg;
c = context();
a = utils.blockStore('begin', cfg, c, struct('seed', 4));
p = payload();
r = utils.blockStore('commit', cfg, a, p);
s = utils.blockStore('recover', cfg, c.logicalRunId);
verifyEqual(testCase, s.nextBlock, 2);
verifyEqual(testCase, s.receipts(1).attemptId, a.attemptId);
f = fullfile(a.directory, 'behavior.mat');
before = utils.checkpointIO('hash', f);
delete(fullfile(a.directory, 'receipt.mat'));
s = utils.blockStore('recover', cfg, c.logicalRunId);
verifyEqual(testCase, s.nextBlock, 2);
verifyEqual(testCase, utils.checkpointIO('hash', f), before);
verifyEqual(testCase, s.receipts(1).files, r.files);
end
function incompleteRetryIsSeparate(testCase)
cfg = testCase.TestData.cfg; c = context();
a = utils.blockStore('begin', cfg, c, struct('seed', 4));
s = utils.blockStore('recover', cfg, c.logicalRunId);
verifyEqual(testCase, s.nextBlock, 1);
verifyEqual(testCase, s.entryState.seed, 4);
b = utils.blockStore('begin', cfg, c, s.entryState);
verifyNotEqual(testCase, a.attemptId, b.attemptId);
verifyTrue(testCase, isfolder(a.directory));
end
function corruptArtifactNotComplete(testCase)
cfg = testCase.TestData.cfg; c = context();
a = utils.blockStore('begin', cfg, c, struct());
utils.blockStore('commit', cfg, a, payload());
fid = fopen(fullfile(a.directory, 'gaze.mat'), 'w'); fwrite(fid, 'truncated'); fclose(fid);
verifyError(testCase, @() utils.blockStore('recover', cfg, c.logicalRunId), 'hw:blockStore:corrupt');
end
function disabledTracker(testCase)
cfg = testCase.TestData.cfg; c = context();
a = utils.blockStore('begin', cfg, c, struct());
p = payload(); p.gaze = [];
utils.blockStore('commit', cfg, a, p);
s = utils.blockStore('scan', cfg, c.logicalRunId);
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

function localConfigDoesNotProbeShare(testCase)
cfg = utils.config('projRoot', testCase.TestData.root, ...
    'localDataRoot', fullfile(testCase.TestData.root, 'local'), ...
    'dataRoot', fullfile(testCase.TestData.root, 'not-created-share'), ...
    'testing', true, 'runKind', 'practice');
verifyEqual(testCase, cfg.paths.data, fullfile(testCase.TestData.root, 'local', 'practice'));
verifyFalse(testCase, isfolder(fullfile(testCase.TestData.root, 'not-created-share')));
verifyTrue(testCase, isfolder(cfg.paths.checkpoints));
end
function beforeDescriptorIsRecoverable(testCase)
cfg = testCase.TestData.cfg; c = context();
a = utils.blockStore('begin',cfg,c,struct('seed',4));
utils.blockStore('commit',cfg,a,payload());
delete(fullfile(a.directory,'receipt.mat')); delete(fullfile(a.directory,'prepared.mat'));
s = utils.blockStore('recover',cfg,c.logicalRunId);
verifyEqual(testCase,s.nextBlock,2);
end
function behaviorOnlyDoesNotComplete(testCase)
cfg = testCase.TestData.cfg; c = context();
a = utils.blockStore('begin',cfg,c,struct('seed',4));
p = payload(); behavior = rmfield(p,'gaze'); behavior.identity = a;
utils.checkpointIO('write',fullfile(a.directory,'behavior.mat'),struct('behavior',behavior));
s = utils.blockStore('recover',cfg,c.logicalRunId);
verifyEqual(testCase,s.nextBlock,1);
verifyEqual(testCase,s.entryState.seed,4);
end
function twoValidAttemptsConflict(testCase)
cfg = testCase.TestData.cfg; c = context();
a = utils.blockStore('begin',cfg,c,struct('seed',4));
b = utils.blockStore('begin',cfg,c,struct('seed',4));
utils.blockStore('commit',cfg,a,payload()); utils.blockStore('commit',cfg,b,payload());
verifyError(testCase,@() utils.blockStore('recover',cfg,c.logicalRunId),'hw:blockStore:conflict');
end
function unsupportedGazeKeepsBehavior(testCase)
cfg = testCase.TestData.cfg; c = context();
a = utils.blockStore('begin',cfg,c,struct('seed',4));
p = payload(); p.gaze = struct('unsupported',{{1,2}});
try
    utils.blockStore('commit',cfg,a,p);
    verifyFail(testCase,'Unknown leaf silently accepted.');
catch ME
    verifyTrue(testCase,startsWith(ME.identifier,'hw:gazeCodec:'));
end
verifyTrue(testCase,isfile(fullfile(a.directory,'behavior.mat')));
verifyFalse(testCase,isfile(fullfile(a.directory,'receipt.mat')));
end
