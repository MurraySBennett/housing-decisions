function tests = test_run_recovery
tests = functiontests(localfunctions);
end
function testFrozenRun(testCase)
root = tempname; mkdir(root); cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
s = struct('participant', 9999, 'sessionNum', 1, 'runKind', 'practice', ...
    'assignment', struct('taskOrder', 2), 'codeVersion', 'test');
s.cfg = utils.config('projRoot', root, 'localDataRoot', fullfile(root,'data'), 'testing', true, 'runKind', 'practice');
r = utils.runCheckpoint('open', s, 'contdc', {'houses'});
r2 = utils.runCheckpoint('open', s, 'contdc', {'houses'});
verifyEqual(testCase, r.runId, r2.runId);
original = struct('order', [3 1 2], 'seed', uint32(12));
a = utils.runCheckpoint('freeze', s, r, 'houses', original);
b = utils.runCheckpoint('freeze', s, r, 'houses', struct('order', [1 2 3]));
verifyEqual(testCase, a, b);
s.assignment.taskOrder = 3;
verifyError(testCase, @() utils.runCheckpoint('open', s, 'contdc', {'houses'}), ...
    'hw:sessionContext:incompatible');
end
function testRelocatedRunUsesCurrentPaths(testCase)
root = tempname; mkdir(root); cleanup = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
s = struct('participant',9999,'sessionNum',1,'runKind','practice', ...
    'assignment',struct('taskOrder',2),'codeVersion','test');
s.cfg = utils.config('projRoot',root,'localDataRoot',fullfile(root,'data'),'testing',true,'runKind','practice');
r = utils.runCheckpoint('open',s,'contdc',{'houses'});
s.cfg.paths.taskData.contdc = fullfile(root,'another-local-root');
r2 = utils.runCheckpoint('open',s,'contdc',{'houses'});
verifyEqual(testCase,r.runId,r2.runId);
verifyEqual(testCase,r2.fileStem,fullfile(s.cfg.paths.taskData.contdc,r.runId));
end
