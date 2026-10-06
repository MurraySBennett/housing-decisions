function tests = test_block_recording
tests = functiontests(localfunctions);
end
function exactIntegerAlignment(testCase)
base = bitshift(uint64(1),53) + uint64(1);
g = repmat(struct('SystemTimeStamp', base), 4, 1);
for k = 1:4, g(k).SystemTimeStamp = base + uint64((k-1)*1000000); end
p = utils.gazeCodec('pack', g);
clockSync = struct('start', struct('ok',true,'ptbSecs',10,'tobiiSystemTimeStamp',base), ...
    'end', struct('ok',true,'ptbSecs',13,'tobiiSystemTimeStamp',base+uint64(3000000)));
events = table([10;11;12], [1;1;0], {'fixation';'stimulus';'intertrial'}, ...
    'VariableNames', {'flipTime','trial','phase'});
a = utils.alignBlockGaze(p, events, clockSync);
verifyEqual(testCase, a.ptbTime, [10;11;12;13]);
verifyEqual(testCase, a.trial, [1;1;0;0]);
verifyEqual(testCase, a.phase, ["fixation";"stimulus";"intertrial";"intertrial"]);
clockSync.start.ok = false;
a = utils.alignBlockGaze(p, events, clockSync);
verifyTrue(testCase, all(isnan(a.ptbTime)));
verifyTrue(testCase, all(a.phase == "unknown"));
end
function restartSubscriptionRetainsEveryPoll(testCase)
tracker = FakeGazeTracker();
et = struct('enabled',true,'obj',tracker,'operations',[]);
r = utils.blockRecording('start',et);
s = utils.gazeBuffer('poll',et,r.store);
s = utils.gazeBuffer('poll',et,s);
r = utils.blockRecording('finish',et,s,r.clockSync,struct('runId','synthetic-recording-test'));
verifyEqual(testCase,[r.gaze.SystemTimeStamp],uint64([201:202 301:303 401:404]));
verifyTrue(testCase,tracker.stopped);
retained = utils.gazeBuffer('retained');
verifyEqual(testCase,retained.n,9);
utils.gazeBuffer('release');
r = utils.blockRecording('start',et);
verifyFalse(testCase,tracker.stopped);
verifyEqual(testCase,r.store.n,0);
r = utils.blockRecording('finish',et,r.store,r.clockSync,struct('runId','synthetic-recording-test'));
verifyEqual(testCase,[r.gaze.SystemTimeStamp],uint64(601:606));
utils.gazeBuffer('release');
end
function resetClockStaysUnknown(testCase)
g = [struct('SystemTimeStamp',uint64(20)); struct('SystemTimeStamp',uint64(10))];
c = struct('start',struct('ok',true,'ptbSecs',1,'tobiiSystemTimeStamp',uint64(1)), ...
    'end',struct('ok',true,'ptbSecs',2,'tobiiSystemTimeStamp',uint64(30)));
a = utils.alignBlockGaze(utils.gazeCodec('pack',g),table(),c);
verifyTrue(testCase,all(a.phase == "unknown"));
end
