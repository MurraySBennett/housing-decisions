function tests = test_session_tail
%TEST_SESSION_TAIL  Cover the end-of-session tail: publish, then derive.
%
% utils.publishToShare and utils.exportSession are the last two things a
% session does, and until this file existed neither had any coverage at all.
% Three shipped bugs went out behind a green suite because of it:
%
%   1. publishToShare resolved repoRoot with two fileparts instead of three,
%      so its addpath(scripts/) silently did nothing and sync_blocks was
%      undefined. It only ever worked because rig_checks had already put
%      scripts/ on the path for the session.
%   2. exportSession called export_gaze_csv, which had never been committed.
%      Every clone but the author's failed; the author's passed.
%   3. Committing the missing test took discovery from 46 cases to 52, and
%      both runners asserted the literal 46.
%
% Bug 1 is the reason testPublishResolvesWithoutScriptsOnPath scrubs scripts/
% off the path first. verify_block_checkpoints.m:5 adds it for the whole
% suite, which would mask that bug here forever.
%
% Both functions NEVER THROW by contract (publishToShare.m:18,
% exportSession.m:16) -- a replication failure must not turn a completed
% session into a failed one. So every assertion here is on ARTEFACTS ON DISK
% or on the printed banner, never on a return value and never on the absence
% of an error. exportSession in particular keeps its combine_blocks report
% assigned before export_gaze_csv throws, so a non-empty report proves
% nothing at all.
tests = functiontests(localfunctions);
end

% ---------------------------------------------------------------- helpers

function c = tailCase()
%TAILCASE  A sandboxed cfg plus a committed run, with nothing on the share.
%
% Every path is under tempdir. Nothing here may call utils.config: its
% defaults point at the real OSU share (config.m:29-30), and publishing a
% test fixture into live participant data is not a recoverable mistake.
c.root = tempname;
c.local = fullfile(c.root, 'local');
c.share = fullfile(c.root, 'share');
c.derived = fullfile(c.root, 'derived');
c.shareDerived = fullfile(c.root, 'shareDerived');
% publishToShare.m:49 and exportSession.m:61 both isfolder-gate the share and
% return early when it is missing, so these must exist before the call.
mkdir(c.local); mkdir(c.share); mkdir(c.shareDerived);

c.cfg = struct();
c.cfg.paths = struct('data', c.local, 'checkpoints', fullfile(c.local, 'blocks'), ...
    'derived', c.derived, 'shareData', c.share, 'shareDerived', c.shareDerived);
c.cfg.share = struct('publishOnCompletion', true, 'exportOnCompletion', true);

% The default fixture payload carries metadata=struct() and events=table(),
% which means no _et.csv (export_gaze_csv.m:285 needs metadata.eyeTracking)
% and no events CSV (export_gaze_csv.m:115 skips an empty table). Supply both
% in the TASKS' spelling, per continuous_DC_task.m:70-77 -- not the
% exporter's, which is how the sampleRateHz mismatch went unnoticed.
et = struct('enabled', false, 'analyzable', false, 'positioned', false, ...
    'mediaMode', false, 'requestedSampleRateHz', 120, ...
    'actualSampleRateHz', NaN, 'setupFailureStage', '', ...
    'setupFailureMessage', '', 'operatorChoice', 'none');
events = table(1, "block_start", 'VariableNames', {'t', 'name'});
overrides = struct('metadata', struct('eyeTracking', et), 'events', events);

[c.f, c.a] = checkpoint_fixture(c.local, overrides);
c.runId = c.f.run.runId;
c.domain = 'houses';
end

function cleaner = scrubScriptsFromPath()
%SCRUBSCRIPTSFROMPATH  Make scripts/ unreachable so the callee must find it.
%
% This is the whole point of the publish and export cases. With scripts/
% reachable -- which verify_block_checkpoints.m:5 guarantees for the suite --
% sync_blocks resolves no matter how broken publishToShare's own addpath block
% is, and the case passes against the exact bug it exists to catch.
%
% rmpath ALONE IS NOT ENOUGH. MATLAB resolves functions in the current folder
% whether or not it is on the path, so if MATLAB was launched from scripts/
% -- which is how you run verify_block_checkpoints by hand -- sync_blocks stays
% visible after rmpath. Without the cd below, this file passes or fails
% depending on which directory you happened to start in, which is the same
% class of environment-dependence that let all three bugs ship.
scriptsDir = fileparts(fileparts(mfilename('fullpath')));
wasOn = contains([path pathsep], [scriptsDir pathsep]);
if wasOn, rmpath(scriptsDir); end
neutral = tempname; mkdir(neutral);
oldCd = cd(neutral);
rehash;
cleaner = onCleanup(@() restoreScripts(scriptsDir, wasOn, oldCd, neutral));
end

function restoreScripts(scriptsDir, wasOn, oldCd, neutral)
cd(oldCd);
if wasOn && ~contains([path pathsep], [scriptsDir pathsep])
    addpath(scriptsDir);
end
rehash;
if isfolder(neutral), rmdir(neutral, 's'); end
end

% ------------------------------------------------------------------ cases

function testPublishResolvesWithoutScriptsOnPath(testCase)
c = tailCase();
scrubbed = scrubScriptsFromPath(); %#ok<NASGU>

% Guard the guard. If scripts/ were still reachable the rest of this case
% would pass against a broken publishToShare, exactly as it did in production.
verifyEqual(testCase, exist('sync_blocks', 'file'), 0, ...
    'scripts/ is still on the path; this case cannot detect the bug it exists for.');

out = evalc('utils.publishToShare(c.cfg);');

% The blocks reached the share. sync_blocks mirrors the local tree, so the
% block store must be readable from the share side with the same scan idiom
% test_block_sync.m:26 uses.
shareCfg.paths.checkpoints = fullfile(c.share, 'blocks');
state = utils.scanBlocks(shareCfg, [c.runId '_' c.domain]);
verifyEqual(testCase, state.nextBlock, 2, ...
    'the committed block did not arrive on the share');
verifyFalse(testCase, contains(out, 'NOT PUBLISHED'), out);
verifyFalse(testCase, contains(out, 'Undefined function'), out);
end

function testExportResolvesWithoutScriptsOnPath(testCase)
% Separately scrubbed from the publish case on purpose: publishToShare
% addpaths scripts/ when it runs, so testing both in one call would let
% publish's addpath cover for a broken one in exportSession.
c = tailCase();
scrubbed = scrubScriptsFromPath(); %#ok<NASGU>
verifyEqual(testCase, exist('export_gaze_csv', 'file'), 0, ...
    'scripts/ is still on the path; this case cannot detect the bug it exists for.');

out = evalc('utils.exportSession(c.cfg);');
verifyFalse(testCase, contains(out, 'NOT DERIVED'), out);
verifyFalse(testCase, contains(out, 'Undefined function'), out);
end

function testDerivedExportsLandLocallyAndOnTheShare(testCase)
c = tailCase();
evalc('utils.publishToShare(c.cfg); utils.exportSession(c.cfg);');

% combine_blocks maps task 'contdc' onto directory 'cont_dc'
% (combine_blocks.m:72). A run is complete when its receipt count matches the
% frozen plan's blockCount (combine_blocks.m:29) -- the fixture freezes 1 and
% commits 1, so these land at the derived root rather than under partial/,
% which the R globs and export_gaze_csv both skip.
rel = { ...
    fullfile('cont_dc', [c.runId '.csv']), ...
    fullfile('cont_dc', [c.runId '.mat']), ...
    fullfile('events',  [c.runId '_events.mat']), ...
    fullfile('events',  [c.runId '_events.csv']), ...
    fullfile('gaze',    [c.runId '_' c.domain '_gaze.mat']), ...
    fullfile('gaze_qc', [c.runId '_' c.domain '_et.csv'])};

for k = 1:numel(rel)
    verifyTrue(testCase, isfile(fullfile(c.derived, rel{k})), ...
        sprintf('missing derived export: %s', rel{k}));
end

% exportSession.m:70-82 copies the derived tree to the share. That loop never
% runs if export_gaze_csv threw, which is precisely how the second bug
% presented: blocks on the share, no derived folder beside them.
for k = 1:numel(rel)
    verifyTrue(testCase, isfile(fullfile(c.shareDerived, rel{k})), ...
        sprintf('derived export never reached the share: %s', rel{k}));
end
end

function testGazeExportsRunWithoutATracker(testCase)
% The tracker is off in the fixture, and that must not stop the tail. Gaze
% blocks are still written as validated empty stubs (the tasks' responses write,
% commitBlock.m), combine_blocks still emits the per-domain gaze MAT
% (combine_blocks.m:62), and export_gaze_csv reports 0 samples rather than
% warning or throwing. A no-tracker run therefore exercises the whole tail.
c = tailCase();
out = evalc('utils.exportSession(c.cfg);');

verifyTrue(testCase, isfile(fullfile(c.derived, 'gaze', ...
    [c.runId '_' c.domain '_gaze.mat'])), 'no per-domain gaze export');
verifySubstring(testCase, out, '0 samples');

% No samples means no _gaze.csv, by design -- assert the absence so that a
% future change which starts emitting an empty one is noticed here.
verifyFalse(testCase, isfile(fullfile(c.derived, 'gaze_qc', ...
    [c.runId '_' c.domain '_gaze.csv'])), ...
    'a sample-level CSV was written for a run with no gaze samples');
end

function testTailNeverTouchesTheRealShare(testCase)
% A tripwire, not a behaviour test. The failure it guards against is someone
% later reaching for utils.config() in this file for convenience and
% publishing fixture data into live participant directories.
c = tailCase();
p = struct2cell(c.cfg.paths);
for k = 1:numel(p)
    verifyFalse(testCase, contains(lower(char(p{k})), 'asc-files'), ...
        'a path under test points at the real OSU share');
    verifySubstring(testCase, char(p{k}), tempdir, ...
        'a path under test is outside tempdir');
end
end
