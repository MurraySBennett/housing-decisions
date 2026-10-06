function tests = test_gaze_benchmark
tests = functiontests(localfunctions);
end
function testBenchmarkRoundtripPreservesInput(testCase)
root = tempname; mkdir(root); cleaner = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
source = fullfile(root,'source.mat');
gaze = struct('SystemTimeStamp',bitshift(uint64(1),53)+uint64(1),'Value',single([1 NaN]));
utils.checkpointIO('write',source,struct('gaze',gaze));
before = utils.checkpointIO('hash',source);
r = benchmark_gaze_storage(source,fullfile(root,'output'));
verifyTrue(testCase,r.complete);
verifyEqual(testCase,numel(r.outputs),2);
verifyEqual(testCase,utils.checkpointIO('hash',source),before);
end
function testBenchmarkFailureLeavesReport(testCase)
root = tempname; mkdir(root); cleaner = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
source = fullfile(root,'source.mat');
utils.checkpointIO('write',source,struct('gaze',struct('Unsupported',{{1}})));
verifyError(testCase,@() benchmark_gaze_storage(source,fullfile(root,'output')),'hw:gazeCodec:type');
files = dir(fullfile(root,'output','*','report.mat'));
verifyEqual(testCase,numel(files),1);
s = load(fullfile(files(1).folder,files(1).name),'report');
verifyFalse(testCase,s.report.complete);
verifyEqual(testCase,s.report.stage,'pack');
verifyNotEmpty(testCase,s.report.error);
end
