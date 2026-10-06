function tests = test_auction_blocks
tests = functiontests(localfunctions);
end
function abandonedRetirementsDoNotLeak(testCase)
root = tempname; mkdir(root); cleanup = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
[f,a] = checkpoint_fixture(root);
rs = RandStream('twister','Seed',23); rand(rs,1,5); % practice consumption
entry = struct('plan',struct('stimIdx',{[1 2 3],[1 4 5]},'block',{2,3}), ...
    'wonStimIdx',8,'rsState',rs.State,'globalState',rng);
c = rmfield(a,{'attemptId','directory','startedAt'}); c.blockOrdinal = 2; c.parentAttemptId = a.attemptId;
utils.blockStore('begin',f.cfg,c,entry);
expected = rand(rs,1,4);
abandoned = entry; abandoned.plan(2).stimIdx = [4 5]; abandoned.wonStimIdx = [8 1]; %#ok<NASGU>
state = utils.blockStore('recover',f.cfg,c.logicalRunId);
verifyEqual(testCase,state.entryState.plan(2).stimIdx,[1 4 5]);
verifyEqual(testCase,state.entryState.wonStimIdx,8);
rs.State = state.entryState.rsState;
verifyEqual(testCase,rand(rs,1,4),expected);
verifyEqual(testCase,state.entryState.globalState,entry.globalState);
end
