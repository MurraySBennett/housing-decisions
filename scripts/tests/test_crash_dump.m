function tests = test_crash_dump
%TEST_CRASH_DUMP  The task-side crash handler, executed from its real source.
%
% Every task file ends in one `catch ME` block. These tests cut that block out
% of each task's source text and run it, so what is covered is the shipped
% handler, not a copy. Two contracts:
%
%   1. The dump is readable off the rig: default v7 save (scipy cannot open
%      -v7.3/HDF5, and scripts/read_crash_dump.py is the only reader that
%      works without MATLAB), written under cfg.paths.crashed, holding
%      ME, dataMat, sess and run. preference_task shipped a -v7.3 dump to a
%      different directory with half the variables, which is why the
%      2026-10-06 pref crashes could not be read off-rig.
%   2. The handler is byte-identical across the three tasks, so reading one
%      is reading all three. Divergence is how the pref dump broke silently.
tests = functiontests(localfunctions);
end

function testHandlersAreIdenticalText(testCase)
blocks = cellfun(@(f) handlerText(f), taskFiles(), 'UniformOutput', false);
verifyEqual(testCase, blocks{2}, blocks{1}, ...
    'continuous_DC_task crash handler differs from auction_task.');
verifyEqual(testCase, blocks{3}, blocks{1}, ...
    'preference_task crash handler differs from auction_task.');
end

function testAuctionCrashDumpReadable(testCase)
runHandlerAndVerifyDump(testCase, 1);
end

function testContdcCrashDumpReadable(testCase)
runHandlerAndVerifyDump(testCase, 2);
end

function testPrefCrashDumpReadable(testCase)
runHandlerAndVerifyDump(testCase, 3);
end

% ----------------------------------------------------------------------
function files = taskFiles()
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
files = { ...
    fullfile(root, 'experiment', 'auction_task.m'), ...
    fullfile(root, 'experiment', 'continuous_DC_task.m'), ...
    fullfile(root, 'experiment', 'preference_task.m')};
end

function block = handlerText(file)
% The final catch of the task function, from `catch ME` through `rethrow(ME);`.
src = fileread(file);
src = strrep(src, sprintf('\r\n'), newline);
matches = regexp(src, 'catch ME\n.*?rethrow\(ME\);', 'match');
assert(numel(matches) == 1, 'Expected exactly one task-level catch in %s, found %d.', ...
    file, numel(matches));
block = matches{1};
end

function runHandlerAndVerifyDump(testCase, which)
files = taskFiles();
body = handlerText(files{which});
body = regexprep(body, '^catch ME\n', '');       % ME is supplied below
body = regexprep(body, 'rethrow\(ME\);$', '');   % its presence is what ends the extraction

stubs = fullfile(fileparts(mfilename('fullpath')), 'fixtures', 'ptb_fake');
addpath(stubs, '-begin'); cleaner = onCleanup(@() rmpath(stubs)); %#ok<NASGU>
utils.gazeBuffer('release'); % no retained gaze from other tests

root = tempname; mkdir(root); cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
crashed = fullfile(root, 'crashed'); mkdir(crashed);

% The workspace the handler runs against. Everything a handler may touch is
% here; a handler needing more than this is a finding.
cfg = struct('paths', struct('crashed', crashed)); %#ok<NASGU>
sess = struct('cfg', struct('paths', struct('fallbackData', fullfile(root, 'emergency')))); %#ok<NASGU>
run = struct('runId', 'sub-09999_ses-01_task-test_dom-houses', ...
    'fileStem', fullfile(root, 'stem')); %#ok<NASGU>
et = struct('enabled', false, 'obj', []); %#ok<NASGU>
dataMat = struct('note', 'partial data at crash time'); %#ok<NASGU>
standalone = false; %#ok<NASGU>
tl = struct('sections', {{}}, 'startedAt', 0); %#ok<NASGU>
ME = MException('hw:test:boom', 'deliberate test crash');

eval(body);

dumps = dir(fullfile(crashed, '*_crash.mat'));
assertNumElements(testCase, dumps, 1, ...
    'Expected exactly one crash dump under cfg.paths.crashed.');
dumpFile = fullfile(dumps(1).folder, dumps(1).name);
verifySubstring(testCase, dumps(1).name, run.runId, ...
    'Dump name must carry the runId.');

fid = fopen(dumpFile, 'r'); header = fread(fid, [1 10], '*char'); fclose(fid);
verifyEqual(testCase, header, 'MATLAB 5.0', ...
    'Dump must be a default v7 save: scripts/read_crash_dump.py cannot open -v7.3.');

loaded = load(dumpFile);
verifyEqual(testCase, sort(fieldnames(loaded)), {'ME'; 'dataMat'; 'run'; 'sess'}, ...
    'Dump must hold exactly ME, dataMat, sess and run.');
verifyEqual(testCase, loaded.ME.identifier, 'hw:test:boom');
end
