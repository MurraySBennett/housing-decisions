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
