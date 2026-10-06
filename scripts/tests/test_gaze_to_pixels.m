function tests = test_gaze_to_pixels
% The rig and the fake tracker disagree about the type of Validity, and only
% the fake was ever tested. The real SDK wraps it in an object exposing
% .value -- the spelling utils.gazeCodec's eyeArgs uses, confirmed by the
% actual-SDK roundtrip case passing on the rig -- while FakeGazeTracker sets
% a plain numeric 1. A bare `== 1` on the wrapper either throws at the first
% drift check or silently reports every sample invalid for a whole session.
tests = functiontests(localfunctions);
end

function testValiditySpellings(testCase)
stubs = fullfile(fileparts(mfilename('fullpath')), 'fixtures', 'ptb_fake');
addpath(stubs, '-begin'); cleaner = onCleanup(@() dropStubs(stubs)); %#ok<NASGU>
clear Screen GetSecs WaitSecs DrawFormattedText;

% Screen('Rect') is stubbed to [0 0 1920 1080].
onDisplay = [0.5 0.25];
expectedX = 960; expectedY = 270;

% Bare numeric, as FakeGazeTracker and older saved data report it.
plainEye = struct('GazePoint', struct('Validity', 1, 'OnDisplayArea', onDisplay));
[x, y] = utils.gazeToPixels(struct('LeftEye', plainEye, 'RightEye', plainEye), 0);
verifyEqual(testCase, x, expectedX);
verifyEqual(testCase, y, expectedY);

% Wrapped in an object/struct exposing .value, as the real SDK reports it.
validEye = struct('GazePoint', ...
    struct('Validity', struct('value', true), 'OnDisplayArea', onDisplay));
[x, y] = utils.gazeToPixels(struct('LeftEye', validEye, 'RightEye', validEye), 0);
verifyEqual(testCase, x, expectedX);
verifyEqual(testCase, y, expectedY);

% An invalid wrapped sample must come back NaN, not a position.
invalidEye = struct('GazePoint', ...
    struct('Validity', struct('value', false), 'OnDisplayArea', onDisplay));
[x, y] = utils.gazeToPixels(struct('LeftEye', invalidEye, 'RightEye', invalidEye), 0);
verifyTrue(testCase, isnan(x) && isnan(y));

% One valid eye is still a usable sample, and must not be averaged with the
% invalid one -- gazeToPixels documents exactly this behaviour.
[x, y] = utils.gazeToPixels(struct('LeftEye', validEye, 'RightEye', invalidEye), 0);
verifyEqual(testCase, x, expectedX);
verifyEqual(testCase, y, expectedY);

% Unreadable validity fails closed rather than throwing mid-block.
oddEye = struct('GazePoint', ...
    struct('Validity', struct('unexpected', 1), 'OnDisplayArea', onDisplay));
[x, y] = utils.gazeToPixels(struct('LeftEye', oddEye, 'RightEye', oddEye), 0);
verifyTrue(testCase, isnan(x) && isnan(y));
end

function dropStubs(path)
rmpath(path); clear Screen GetSecs WaitSecs DrawFormattedText;
end
