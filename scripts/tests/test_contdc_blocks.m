function tests = test_contdc_blocks
tests = functiontests(localfunctions);
end
function matchedPricingRetry(testCase)
root = tempname; mkdir(root); cleanup = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
[f,a] = checkpoint_fixture(root);
before = utils.checkpointIO('hash',fullfile(a.directory,'behavior.mat'));
rs = RandStream('twister','Seed',19);
entry = struct('pairs',[4 9;2 7],'rsState',rs.State,'globalState',rng);
c = rmfield(a,{'attemptId','directory','startedAt'}); c.blockOrdinal = 2; c.parentAttemptId = a.attemptId;
failed = utils.blockStore('begin',f.cfg,c,entry);
expectedOrder = randperm(rs,2); randperm(rs,20);
state = utils.blockStore('recover',f.cfg,c.logicalRunId);
verifyEqual(testCase,state.nextBlock,2);
verifyEqual(testCase,state.entryState.pairs,entry.pairs);
rs.State = state.entryState.rsState;
verifyEqual(testCase,randperm(rs,2),expectedOrder);
retry = utils.blockStore('begin',f.cfg,c,state.entryState);
verifyNotEqual(testCase,retry.attemptId,failed.attemptId);
verifyEqual(testCase,utils.checkpointIO('hash',fullfile(a.directory,'behavior.mat')),before);
end
