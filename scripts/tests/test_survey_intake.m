function tests = test_survey_intake
% A resumed session must not re-consent the participant or destroy the
% original consent record.
tests = functiontests(localfunctions);
end

function s = session(root)
s = struct('participant', 9999, 'sessionNum', 1, 'runKind', 'practice', ...
    'assignment', struct('taskOrder', 2, 'domain', 'houses'), 'codeVersion', 'test');
s.cfg = utils.config('projRoot', root, 'localDataRoot', fullfile(root,'data'), ...
    'runKind', 'practice');
s.manifestFile = fullfile(s.cfg.paths.sessions, 'manifest.mat');
s.manifest = struct('runs', {{}});
end

function testWriteThenReadRoundtrip(testCase)
root = tempname; mkdir(root); cleanup = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
s = session(root);
verifyEmpty(testCase, utils.consentRecord('read', s));
info = struct('enabled', true, 'url', 'https://example.invalid/x', 'opened', true, ...
    'browser', 'chrome', 'consented', true, 'startedAt', '2026-10-06 09:00:00');
utils.consentRecord('write', s, info);
back = utils.consentRecord('read', s);
verifyEqual(testCase, back.consented, true);
verifyEqual(testCase, back.startedAt, info.startedAt);
end

function testWriteNeverClobbersTheFirstRecord(testCase)
root = tempname; mkdir(root); cleanup = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
s = session(root);
first = struct('enabled', true, 'url', 'u', 'opened', true, 'browser', 'chrome', ...
    'consented', true, 'startedAt', 'FIRST');
utils.consentRecord('write', s, first);
file = utils.consentRecord('file', s);
before = utils.checkpointIO('hash', file);

second = first; second.startedAt = 'SECOND';
warnState = warning('off', 'hw:consentRecord:existing');
restore = onCleanup(@() warning(warnState)); %#ok<NASGU>
utils.consentRecord('write', s, second);

% The original is byte-for-byte intact and still what 'read' returns.
verifyEqual(testCase, utils.checkpointIO('hash', file), before);
verifyEqual(testCase, utils.consentRecord('read', s).startedAt, 'FIRST');
% The later attempt is kept beside it rather than discarded.
extra = dir(fullfile(s.cfg.paths.sessions, 'sub-09999_ses-01_survey_*.mat'));
verifyEqual(testCase, numel(extra), 1);
end

function testResumeSkipsSurveyAndKeepsOriginalRecord(testCase)
root = tempname; mkdir(root); cleanup = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
s = session(root);
s.cfg.survey.enabled = true;
s.cfg.survey.baseUrl = 'https://example.invalid/consent';
prior = struct('enabled', true, 'url', 'https://example.invalid/consent', ...
    'opened', true, 'browser', 'chrome', 'consented', true, ...
    'startedAt', '2026-10-06 09:00:00', 'finishedAt', '2026-10-06 09:04:00');
utils.consentRecord('write', s, prior);
file = utils.consentRecord('file', s);
before = utils.checkpointIO('hash', file);

% No browser, no console prompt: returns from the record alone. If this
% test ever blocks waiting for input, the resume guard has regressed.
info = utils.launchSurvey(s);

verifyTrue(testCase, info.consented);
verifyTrue(testCase, info.resumed);
verifyEqual(testCase, info.startedAt, prior.startedAt);
verifyEqual(testCase, utils.checkpointIO('hash', file), before);
verifyEqual(testCase, numel(dir(fullfile(s.cfg.paths.sessions, 'sub-09999_ses-01_survey_*.mat'))), 0);
end
