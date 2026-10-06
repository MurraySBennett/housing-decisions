function tests = test_block_sync
tests = functiontests(localfunctions);
end
function copyAndConflict(testCase)
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
function idempotentBundles(testCase)
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
