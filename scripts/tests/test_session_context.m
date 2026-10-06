function tests = test_session_context
tests = functiontests(localfunctions);
end
function testChangedDomainsAreRejected(testCase)
root = tempname; mkdir(root); cleaner = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
s = struct('participant',9999,'sessionNum',1,'runKind','practice', ...
    'assignment',struct('taskOrder',2),'codeVersion','test');
s.cfg = utils.config('projRoot',root,'localDataRoot',fullfile(root,'data'),'testing',true,'runKind','practice');
utils.runCheckpoint('open',s,'contdc',{'houses'});
verifyError(testCase,@() utils.runCheckpoint('open',s,'contdc',{'jobs'}),'hw:sessionContext:incompatible');
end
function testBatteryCannotChangeBeforeNextTask(testCase)
root = tempname; mkdir(root); cleaner = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
s = struct('participant',9999,'sessionNum',1,'runKind','practice', ...
    'assignment',struct('taskOrder',2),'codeVersion','test');
s.cfg = utils.config('projRoot',root,'localDataRoot',fullfile(root,'data'),'testing',true,'runKind','practice');
plan = {struct('task','auction','domains',{{'houses'}}),struct('task','contdc','domains',{{'houses'}})};
utils.sessionContext('battery',s,plan);
plan{2}.domains = {'jobs'};
verifyError(testCase,@() utils.sessionContext('battery',s,plan),'hw:sessionContext:incompatible');
end
