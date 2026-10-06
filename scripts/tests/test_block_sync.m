function tests = test_block_sync
tests = functiontests(localfunctions);
end
function testCopyAndConflict(testCase)
root = tempname; mkdir(root); cleanup = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
source = fullfile(root,'source'); target = fullfile(root,'target'); mkdir(source);
f = fullfile(source,'x.mat'); utils.checkpointIO('write',f,struct('value',uint64(17)));
before = utils.checkpointIO('hash', f);
utils.checkpointIO('copy',f,fullfile(target,'x.mat'));
utils.checkpointIO('copy',f,fullfile(target,'x.mat'));
verifyEqual(testCase,utils.checkpointIO('hash',f),before);
verifyEqual(testCase,utils.checkpointIO('hash',fullfile(target,'x.mat')),before);
utils.checkpointIO('write',fullfile(target,'x.mat'),struct('value',18),true);
verifyError(testCase,@() utils.checkpointIO('copy',f,fullfile(target,'x.mat')), 'hw:checkpointIO:conflict');
end
function testIdempotentBundles(testCase)
root = tempname; mkdir(root); cleanup = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
[f, a] = checkpoint_fixture(fullfile(root,'local'));
report = sync_blocks(f.root, fullfile(root,'remote'));
verifyEqual(testCase, string({report.status}), repmat("complete",1,numel(report)));
before = utils.checkpointIO('hash', fullfile(a.directory,'behavior.mat'));
report = sync_blocks(f.root, fullfile(root,'remote'));
verifyTrue(testCase, all(strcmp({report.status},'complete')));
verifyEqual(testCase,utils.checkpointIO('hash',fullfile(a.directory,'behavior.mat')),before);
cfg.paths.checkpoints = fullfile(root,'remote','blocks');
r = utils.blockStore('scan',cfg,a.logicalRunId);
verifyEqual(testCase,r.nextBlock,2);
end
function testSessionCalibrationAndTimingSurviveTransfer(testCase)
root = tempname; mkdir(root); cleaner = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
[f,~] = checkpoint_fixture(fullfile(root,'local'));
sessions = fullfile(f.root,'sessions'); mkdir(sessions);
data = struct('anchor',400000,'keepIndustries',{{'Education'}},'savedAt','test');
name = 'sub-09999_ses-01_houses_elicitation.mat';
utils.checkpointIO('write',fullfile(sessions,name),struct('data',data));
T = table("unique-attempt", "auction", 123.4,'VariableNames',{'timing_id','task','seconds'});
writetable(T,fullfile(sessions,'sub-09999_ses-01_timing.csv'));
remote = fullfile(root,'remote'); sync_blocks(f.root,remote); sync_blocks(f.root,remote);
s.cfg.paths.sessions = fullfile(remote,'sessions'); s.participant = 9999; s.sessionNum = 1;
result = utils.elicitationCache('load',s,'houses');
verifyEqual(testCase,result.anchor,data.anchor);
verifyEqual(testCase,result.keepIndustries,data.keepIndustries);
verifyEqual(testCase,height(readtable(fullfile(remote,'sessions','sub-09999_ses-01_timing.csv'))),1);
end
