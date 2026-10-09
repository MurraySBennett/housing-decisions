function tests = test_trial_log
tests = functiontests(localfunctions);
end

% utils.progressLog is the per-trial record. It runs inside the trial loop of
% every task, so the properties that matter are that it appends rather than
% truncates, that one call produces exactly one line, and that it can never
% throw -- a logging failure during a session must not replace the
% experiment's own error.

function run = localRun()
% A unique runId per test keeps these cases independent of each other and of
% any real log left in tempdir by a previous session.
run = struct('runId', ['test-trial-log-' char(utils.checkpointIO('id'))]);
end

function lines = readLog(logFile)
text = fileread(logFile);
lines = strsplit(strtrim(text), newline);
lines = lines(~cellfun(@isempty, lines));
end

function testWritesOneLinePerCall(testCase)
run = localRun();
logFile = utils.progressLog(run, 'TRIAL block=%d/%d trial=%d/%d rt=%.3f', 1, 4, 1, 20, 0.812);
cleaner = onCleanup(@() delete(logFile)); %#ok<NASGU>
verifyTrue(testCase, isfile(logFile));
lines = readLog(logFile);
verifyEqual(testCase, numel(lines), 1);
verifySubstring(testCase, lines{1}, 'TRIAL block=1/4 trial=1/20 rt=0.812');
end

function testAppendsRatherThanTruncating(testCase)
run = localRun();
logFile = '';
for t = 1:5
    logFile = utils.progressLog(run, 'TRIAL trial=%d/5', t, 5);
end
cleaner = onCleanup(@() delete(logFile)); %#ok<NASGU>
lines = readLog(logFile);
verifyEqual(testCase, numel(lines), 5);
% Order is the diagnostic value of the log: it must read as the session ran.
verifySubstring(testCase, lines{1}, 'trial=1/5');
verifySubstring(testCase, lines{5}, 'trial=5/5');
end

function testEachLineCarriesATimestamp(testCase)
run = localRun();
logFile = utils.progressLog(run, 'TRIAL trial=%d/%d', 3, 10);
cleaner = onCleanup(@() delete(logFile)); %#ok<NASGU>
lines = readLog(logFile);
verifyNotEmpty(testCase, regexp(lines{1}, ...
    '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\] TRIAL ', 'once'));
end

function testNaNFieldsDoNotBreakTheLine(testCase)
% A timed-out trial carries NaN rt and NaN choseMoney (blankTrial in
% continuous_DC_task). %d against NaN must still produce one readable line.
run = localRun();
logFile = utils.progressLog(run, 'TRIAL choseMoney=%d rt=%.3f timedOut=%d', NaN, NaN, true);
cleaner = onCleanup(@() delete(logFile)); %#ok<NASGU>
lines = readLog(logFile);
verifyEqual(testCase, numel(lines), 1);
verifySubstring(testCase, lines{1}, 'NaN');
end

function threw = callThrew(fn)
% The framework has no verifyNoError, and progressLog reports its own failures
% on fd 2 rather than as warnings, so warning-based qualifications would pass
% vacuously here.
try
    fn();
    threw = false;
catch
    threw = true;
end
end

function testUnopenableLogDoesNotThrow(testCase)
% The guarantee every task relies on: if the log cannot be written, the
% session continues. A runId naming a directory that does not exist makes
% fopen fail, which is the real failure this guard exists for.
% This case and the next one print 'Progress log unavailable' on fd 2 by
% design; BLOCK_CHECKPOINTS.md tells the operator those two lines in the
% rig transcript are expected.
run = struct('runId', fullfile('no-such-dir', 'nested', 'x'));
verifyFalse(testCase, callThrew(@() utils.progressLog(run, 'TRIAL trial=%d', 1)));
end

function testMissingRunIdDoesNotThrow(testCase)
% A malformed run struct must not end a participant's session either.
verifyFalse(testCase, callThrew(@() utils.progressLog(struct(), 'TRIAL trial=%d', 1)));
end
