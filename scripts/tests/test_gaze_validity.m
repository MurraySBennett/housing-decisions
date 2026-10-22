function tests = test_gaze_validity
%TEST_GAZE_VALIDITY One accessor for every spelling of Tobii's Validity.
%
% Four files used to unwrap Validity independently (gazeToPixels,
% positionGuide, gazeCodec, diagnoseTrackBox), with three different policies
% for an unreadable value. The unwrapping now lives once, in
% utils.gazeValidity; each caller keeps its policy at the call site.
% export_gaze_csv's validityColumn is deliberately separate: it reads packed
% leaf COLUMNS, not live samples, and documents its own path rule.
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root, 'experiment'));
addpath(fullfile(root, 'scripts', 'tests', 'fixtures'));
end

function testNumericPassesThrough(testCase)
% FakeGazeTracker and old recordings store a plain numeric.
verifyEqual(testCase, utils.gazeValidity(int32(1)), int32(1));
verifyEqual(testCase, utils.gazeValidity(0), 0);
verifyEqual(testCase, utils.gazeValidity(true), true);
end

function testWrapperObjectUnwraps(testCase)
% The real SDK wraps validity in an object exposing .value (rig probe, item 4).
verifyEqual(testCase, utils.gazeValidity(ValidityFake(int32(1))), int32(1));
verifyEqual(testCase, utils.gazeValidity(ValidityFake(false)), false);
end

function testStructUnwraps(testCase)
% gazeCodec's unpack reconstructs the wrapper as a struct with a value field.
verifyEqual(testCase, utils.gazeValidity(struct('value', 1)), 1);
end

function testUnreadableReturnsInputForCallerPolicy(testCase)
% No .value and not numeric: the caller decides what that means
% (gazeToPixels fails closed, positionGuide asserts). The accessor never throws.
in = struct('somethingElse', 1);
verifyEqual(testCase, utils.gazeValidity(in), in);
end
