function tests = test_preference_blocks
tests = functiontests(localfunctions);
end
function testExactSequence(testCase)
c = utils.preferenceChunks({'pwc','rating'}, 60, 161);
verifyEqual(testCase, numel(c), 7);
verifyEqual(testCase, [c(1:5).indices], 1:161);
verifyEqual(testCase, [c(6:7).indices], 1:60);
verifyEqual(testCase, [c.globalIndices], 1:221);
verifyTrue(testCase, all(arrayfun(@(x) numel(x.indices) <= 40, c)));
end
function testJobsOnly(testCase)
c = utils.preferenceChunks({'pwc'}, 0, 160);
verifyEqual(testCase, numel(c), 4);
verifyEqual(testCase, [c.indices], 1:160);
end
