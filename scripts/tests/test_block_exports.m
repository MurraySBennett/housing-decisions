function tests = test_block_exports
tests = functiontests(localfunctions);
end
function testExactExportAndMissing(testCase)
root = tempname; mkdir(root); cleanup = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
[f,a] = checkpoint_fixture(fullfile(root,'raw'));
out = fullfile(root,'derived');
report = combine_blocks(f.root,out);
verifyEqual(testCase,report(1).trialCount,1);
file = fullfile(out,'cont_dc',[f.run.runId '.csv']);
before = utils.checkpointIO('hash',file);
combine_blocks(f.root,out);
verifyEqual(testCase,utils.checkpointIO('hash',file),before);
T = readtable(file);
verifyEqual(testCase,string(T.attempt_id),string(a.attemptId));
verifyEqual(testCase,T.block,1);
frozen = struct('blockCount',2);
utils.checkpointIO('write',fullfile(f.root,'runs',f.run.runId,'houses-plan.mat'),struct('frozen',frozen),true);
verifyError(testCase,@() combine_blocks(f.root,fullfile(root,'missing')), 'hw:combine:incomplete');
r = combine_blocks(f.root,fullfile(root,'partial'),'allowPartial',true);
verifyFalse(testCase,r(1).complete);
verifyFalse(testCase,isfolder(fullfile(root,'partial','cont_dc')));
end
function testAbandonedAttemptInventory(testCase)
root = tempname; mkdir(root); cleaner = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
[f,a] = checkpoint_fixture(fullfile(root,'raw'));
c = rmfield(a,{'attemptId','directory','startedAt'});
failed = utils.blockStore('begin',f.cfg,c,struct('seed',1));
out = fullfile(root,'derived'); combine_blocks(f.root,out);
s = load(fullfile(out,'cont_dc',[f.run.runId '.mat']),'dataMat');
inv = s.dataMat.attemptInventory;
ix = strcmp({inv.attemptId},failed.attemptId);
verifyEqual(testCase,sum(ix),1);
verifyEqual(testCase,inv(ix).status,'excluded');
verifyEqual(testCase,inv(ix).reason,'superseded interrupted attempt');
end
