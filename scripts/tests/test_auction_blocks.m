function tests = test_auction_blocks
tests = functiontests(localfunctions);
end
function testAbandonedRetirementsDoNotLeak(testCase)
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
function testDriftPreservesUnsavedGaze(testCase)
stubs = fullfile(fileparts(mfilename('fullpath')),'fixtures','ptb_fake');
addpath(stubs,'-begin'); cleaner = onCleanup(@() removeStubs(stubs)); %#ok<NASGU>
clear Screen GetSecs WaitSecs DrawFormattedText;
tracker = FakeGazeTracker(); et = struct('enabled',true,'obj',tracker,'operations',[]);
r = utils.blockRecording('start',et);
s = utils.gazeBuffer('poll',et,r.store); before = [s.samples{:}];
cfg.et = struct('driftCheck',true,'driftTolDeg',1,'recalOnFail',false);
cfg.style = struct('bg',[0 0 0],'sizeContent',20,'textDim',[1 1 1],'target',[1 1 1]);
cfg.geom.px2deg = @(x) x;
[~,~,s,markers] = utils.driftCheck(et,0,cfg,[960 540],s);
allSamples = vertcat(s.samples{:});
verifyEqual(testCase,allSamples(1:numel(before)),before(:));
verifyFalse(testCase,tracker.stopped);
retained = utils.gazeBuffer('retained'); verifyEqual(testCase,retained.n,s.n);
verifyEqual(testCase,markers(1).phase,'drift');
utils.gazeBuffer('release');
end
function removeStubs(path)
rmpath(path); clear Screen GetSecs WaitSecs DrawFormattedText;
end
