function tests = test_gaze_codec
% Catch precision/shape/order loss and silent dropping of SDK fields.
tests = functiontests(localfunctions);
end
function testRoundtrip(testCase)
t = bitshift(uint64(1), 53) + uint64(1);
eyeSample = struct('GazePoint', struct('OnDisplayArea', [NaN .7], 'Validity', int32(0)), ...
    'Pupil', struct('Diameter', single(3.2), 'Validity', int32(1)));
s = struct('SystemTimeStamp', t, 'LeftEye', eyeSample, 'RightEye', eyeSample, 'Extra', int16([2; 3]));
s(2) = s; s(2).SystemTimeStamp = t + uint64(17);
s(2).LeftEye.GazePoint.OnDisplayArea = [.2 .5];
p = utils.gazeCodec('pack', s);
verifyEqual(testCase, p.sampleCount, 2);
verifyTrue(testCase, isequaln(utils.gazeCodec('unpack', p), s));
verifyTrue(testCase, isequaln(utils.gazeCodec('unpack', utils.gazeCodec('pack', s(:))), s(:)));
end
function testPlainRoundtripIgnoresSdkSpelling(testCase)
% The regression for the 2026-10-09 all-blocks crash. testActualSdkRoundtrip
% could not catch it: it builds its own GazeData with the 18-arg constructor,
% so it only ever round-trips the spelling this file already assumes. The lab's
% rigs carry different Tobii builds -- the R2024b rig's GazeOrigin has no
% InTrackBoxCoordinateSystem -- and blockStore's commit used to unpack all the
% way back to an SDK object, so an unknown spelling killed every block.
%
% This uses snake_case names the hardcoded eyeArgs list does NOT match, and
% asserts the pair blockStore actually relies on still round-trips. It needs no
% SDK, so it runs everywhere, which is the point.
t = bitshift(uint64(1), 53) + uint64(3);
eye = struct('gaze_point', struct('on_display_area', single([.4 .6]), 'validity', int32(1)), ...
    'gaze_origin', struct('in_track_box_coordinate_system', single([0 1 2]), ...
                          'validity', int32(1)));
s = struct('device_time_stamp', t, 'LeftEye', eye, 'RightEye', eye);
s(2) = s; s(2).device_time_stamp = t + uint64(11);
s(2).LeftEye.gaze_origin.in_track_box_coordinate_system = single([.5 .5 .5]);

packed = utils.gazeCodec('pack', s);

% This is the exact call blockStore's commit now makes.
verifyTrue(testCase, utils.gazeCodec('verify', packed, s));
verifyTrue(testCase, isequaln(utils.gazeCodec('unpackplain', packed), s));

% 'verify' must actually be able to say no, or the assert above is decoration.
corrupt = packed;
corrupt.columns{1}(2, 1) = corrupt.columns{1}(2, 1) + 1;
verifyFalse(testCase, utils.gazeCodec('verify', corrupt, s));
verifyFalse(testCase, utils.gazeCodec('verify', packed, s(1)));

% And the hardcoded reconstruction must now fail by NAMING the mismatch
% instead of throwing a bare 'Unrecognized field name', which is what cost a
% session to interpret.
sdkish = packed; sdkish.sourceClass = 'GazeData';
verifyError(testCase, @() utils.gazeCodec('unpack', sdkish), 'hw:gazeCodec:sdkField');
end

function testEmpties(testCase)
for raw = {[], struct('T', {}), zeros(0, 3, 'uint64')}
    verifyTrue(testCase, isequaln(raw{1}, utils.gazeCodec('unpack', utils.gazeCodec('pack', raw{1}))));
end
end
function testIncompatibleLeaf(testCase)
s = struct('Value', {1, [2 3]});
verifyError(testCase, @() utils.gazeCodec('pack', s), 'hw:gazeCodec:shape');
s = struct('Value', {{'unsupported'}});
verifyError(testCase, @() utils.gazeCodec('pack', s), 'hw:gazeCodec:type');
end
function testMalformedPacked(testCase)
p = utils.gazeCodec('pack', struct('T', uint64(12)));
p.columns{1} = double(p.columns{1});
verifyError(testCase, @() utils.gazeCodec('unpack', p), 'hw:gazeCodec:column');
end

function testActualSdkRoundtrip(testCase)
assumeTrue(testCase, exist('GazeData', 'class') == 8, 'Tobii SDK needed for object roundtrip');
t = bitshift(uint64(1), 53) + uint64(1);
a = {single([.2 .3]), single([1 2 3]), true, single(3.25), false, ...
    single([0 1 2]), single([.1 .2 .3]), true};
g = GazeData(t, t + uint64(7), a{:}, a{:});
g(2) = g;
p = utils.gazeCodec('pack', g);
verifyTrue(testCase, isequaln(utils.gazeCodec('unpack', p), g));
verifyEqual(testCase, p.sourceClass, 'GazeData');
end
