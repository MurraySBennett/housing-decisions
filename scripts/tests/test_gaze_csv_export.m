function tests = test_gaze_csv_export
% Cover the flat CSV export the R QC pipeline reads: both SDK spellings of
% Validity, eye averaging, phase=unknown survival, and the plan flattening.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root, 'experiment'));
addpath(fullfile(root, 'scripts'));
testCase.TestData.root = root;
end

function setup(testCase)
testCase.TestData.dir = tempname;
mkdir(testCase.TestData.dir);
end

function teardown(testCase)
if isfolder(testCase.TestData.dir)
    rmdir(testCase.TestData.dir, 's');
end
end

% ---- fixtures --------------------------------------------------------------

function s = makeSamples(n, validitySpelling)
%MAKESAMPLES Raw-shaped Tobii samples, with Validity in either spelling.
%
% The real SDK wraps Validity in an object exposing .value, so gazeCodec's
% describe() recurses and the packed leaf path gains a trailing 'value'.
% FakeGazeTracker stores a plain numeric and does not. Both must export.
s = struct([]);
for k = 1:n
    v = int32(1);
    if strcmp(validitySpelling, 'wrapped'), v = struct('value', int32(1)); end
    eye = struct( ...
        'GazePoint', struct('OnDisplayArea', single([0.4 + 0.01 * k, 0.6]), ...
                            'Validity', v), ...
        'Pupil', struct('Diameter', single(3.2), 'Validity', v));
    s(k).DeviceTimeStamp = uint64(1000 * k);
    s(k).SystemTimeStamp = uint64(1000 * k);
    s(k).LeftEye = eye;
    s(k).RightEye = eye;
end
end

function writeRun(dir, runId, domain, n, validitySpelling, phaseUnknown)
%WRITERUN A minimal combine_blocks-shaped derived tree.
packed = utils.gazeCodec('pack', makeSamples(n, validitySpelling));

phase = repmat("stimulus", n, 1);
if phaseUnknown, phase(:) = "unknown"; end
association = table((1:n)', (100 + (0:n-1)' / 60), ones(n, 1), phase, ...
    'VariableNames', {'sampleIndex','ptbTime','trial','phase'});
association.run_id = repmat(string(runId), n, 1);
association.domain = repmat(string(domain), n, 1);
association.block = ones(n, 1);

gz = packed;
gz.association = association;
gazeExport = struct('schemaVersion', 1, 'logicalRunId', runId, 'domain', domain, ...
    'complete', true, 'blocks', {{gz}}, 'alignmentRule', 'test fixture');
utils.checkpointIO('write', fullfile(dir, 'gaze', [runId '_' domain '_gaze.mat']), ...
    struct('gazeExport', gazeExport));

% The task MAT, carrying the metadata the exporter mines for AOI/ET/stimuli.
stimuliShown = table([250000; 310000], [3; 4], ...
    'VariableNames', {'listPrice','nBeds'});
metadata = {struct( ...
    'eyeTracking', struct('sampleRateHz', 60, 'actualSampleRateHz', 60, ...
                          'enabled', true, 'calibrated', true), ...
    'aoiNames', {{'bid_listPrice','bid_nBeds'}}, ...
    'aoiRects', [10 10 110 60; 200 10 300 60], ...
    'aoiReport', struct('verdict', {{'ok','TOO CLOSE'}}), ...
    'stimuliShown', stimuliShown)};
domainData = struct();
domainData.(domain) = struct('trialBlocks', {{}}, 'metadata', {metadata});
dataMat = struct('schemaVersion', 1, 'complete', true, 'domainData', domainData);
utils.checkpointIO('write', fullfile(dir, 'auction', [runId '.mat']), ...
    struct('dataMat', dataMat, 'trialTable', table()));
end

function writeRawPlan(rawRoot, runId, domain)
plan = struct('trial', {}, 'competition', {}, 'block', {}, 'blockPos', {}, ...
    'stimIdx', {}, 'repIdx', {});
for t = 1:2
    plan(t).trial = t;
    plan(t).competition = 'high';
    plan(t).block = 1;
    plan(t).blockPos = t;
    plan(t).stimIdx = [5 9 12];
    plan(t).repIdx = [t t t];
end
frozen = struct('plan', plan, 'blockCount', 1);
utils.checkpointIO('write', fullfile(rawRoot, 'runs', runId, [domain '-plan.mat']), ...
    struct('frozen', frozen));
end

% ---- cases -----------------------------------------------------------------

function testPlainValidityExports(testCase)
d = testCase.TestData.dir;
runId = 'sub-00012_ses-01_task-auction_dom-houses';
writeRun(d, runId, 'houses', 5, 'plain', false);

export_gaze_csv(d);

f = fullfile(d, 'gaze_qc', [runId '_houses_gaze.csv']);
verifyTrue(testCase, isfile(f), 'gaze QC CSV was not written');
T = readtable(f);
verifyEqual(testCase, height(T), 5);
% Validity 1 on both eyes must survive as valid, and position must be the
% average of the two eyes -- not NaN, which is what a missed leaf looks like.
verifyEqual(testCase, T.gaze_validity, ones(5, 1));
verifyTrue(testCase, all(~isnan(T.gaze_x_norm)));
verifyEqual(testCase, T.gaze_x_norm(1), 0.41, 'AbsTol', 1e-5);
verifyEqual(testCase, T.pupil_diameter(1), 3.2, 'AbsTol', 1e-5);
end

function testWrappedValidityExportsIdentically(testCase)
% The spelling divergence that hid the gazeToPixels bug fixed in d1cd402: the
% fake stores a numeric, the rig an object with .value. Both must read as valid.
d = testCase.TestData.dir;
runId = 'sub-00013_ses-01_task-auction_dom-houses';
writeRun(d, runId, 'houses', 4, 'wrapped', false);

export_gaze_csv(d);

T = readtable(fullfile(d, 'gaze_qc', [runId '_houses_gaze.csv']));
verifyEqual(testCase, height(T), 4);
verifyEqual(testCase, T.gaze_validity, ones(4, 1), ...
    'wrapped Validity must not read as invalid');
verifyTrue(testCase, all(~isnan(T.gaze_x_norm)));
end

function testUnknownPhaseSurvivesExport(testCase)
% phase=unknown is the signal that clockSync failed and the block cannot be
% tied to trials. It must reach the CSV, not be dropped or relabelled.
d = testCase.TestData.dir;
runId = 'sub-00014_ses-01_task-auction_dom-houses';
writeRun(d, runId, 'houses', 3, 'plain', true);

export_gaze_csv(d);

T = readtable(fullfile(d, 'gaze_qc', [runId '_houses_gaze.csv']));
verifyEqual(testCase, height(T), 3);
verifyTrue(testCase, all(strcmp(string(T.phase), "unknown")));
end

function testMetadataSidecarsExport(testCase)
d = testCase.TestData.dir;
runId = 'sub-00015_ses-01_task-auction_dom-houses';
writeRun(d, runId, 'houses', 2, 'plain', false);

export_gaze_csv(d);

et = readtable(fullfile(d, 'gaze_qc', [runId '_houses_et.csv']));
verifyEqual(testCase, et.requestedSampleRateHz(1), 60);
verifyEqual(testCase, et.actualSampleRateHz(1), 60);

aoi = readtable(fullfile(d, 'aoi', [runId '_houses_aoi.csv']));
verifyEqual(testCase, height(aoi), 2);
% The TOO CLOSE verdict is the one an RA has to see; it must not be dropped.
verifyTrue(testCase, any(contains(string(aoi.verdict), "TOO CLOSE")));

stim = readtable(fullfile(d, 'stimuli', [runId '_houses_stimuli_shown.csv']));
verifyEqual(testCase, height(stim), 2);
verifyEqual(testCase, stim.stimIdx, [1; 2]);
end

function testTrialPlanFlattens(testCase)
d = testCase.TestData.dir;
rawRoot = fullfile(testCase.TestData.dir, 'raw');
runId = 'sub-00016_ses-01_task-auction_dom-houses';
writeRun(d, runId, 'houses', 2, 'plain', false);
writeRawPlan(rawRoot, runId, 'houses');

export_gaze_csv(d, 'rawRoot', rawRoot);

T = readtable(fullfile(d, 'plan', [runId '_houses_trial_plan.csv']));
% Two trials x three planned options: the full presented set, which the
% auction CSV never carries.
verifyEqual(testCase, height(T), 6);
verifyEqual(testCase, sort(unique(T.stimIdx))', [5 9 12]);
verifyEqual(testCase, numel(unique(T.trial)), 2);
end

function testMissingGazeTreeWarns(testCase)
d = testCase.TestData.dir;
mkdir(fullfile(d, 'gaze'));
verifyWarning(testCase, @() export_gaze_csv(d), 'hw:exportGaze:nothing');
end

function testPrefPlanDoesNotAbortExport(testCase)
% Every task freezes its own shape into <domain>-plan.mat. The preference
% plan (buildPhotoPreferencePlan) is a scalar struct with no stimIdx, and on
% Moon's 2026-10-22 session reading it as the auction plan threw
% MATLAB:nonExistentField and aborted the WHOLE derivation -- permanently,
% since the same file re-throws on every later sweep. A pref run must export
% its gaze and simply produce no trial-plan CSV.
d = testCase.TestData.dir;
rawRoot = fullfile(d, 'raw');
auctionId = 'sub-00017_ses-01_task-auction_dom-houses';
prefId = 'sub-00017_ses-01_task-pref_dom-houses';
writeRun(d, auctionId, 'houses', 2, 'plain', false);
writeRawPlan(rawRoot, auctionId, 'houses');
writeRun(d, prefId, 'houses', 2, 'plain', false);
prefPlan = struct('photoTable', table((1:3)', 'VariableNames', {'row'}), ...
    'ratingPhotoRows', (1:3)', 'pwcPairs', [1 2; 2 3]);
utils.checkpointIO('write', fullfile(rawRoot, 'runs', prefId, 'houses-plan.mat'), ...
    struct('frozen', struct('plan', prefPlan, 'blockCount', 1)));

export_gaze_csv(d, 'rawRoot', rawRoot);

verifyTrue(testCase, isfile(fullfile(d, 'plan', [auctionId '_houses_trial_plan.csv'])), ...
    'the auction plan CSV must still be written');
verifyFalse(testCase, isfile(fullfile(d, 'plan', [prefId '_houses_trial_plan.csv'])), ...
    'a pref run has no auction plan and must not produce a plan CSV');
verifyTrue(testCase, isfile(fullfile(d, 'gaze_qc', [prefId '_houses_gaze.csv'])), ...
    'the pref run''s gaze must still export');
end

function testOneBadRunDoesNotAbortOthers(testCase)
% The exporter sweeps the whole derived tree, and exportSession's catch is
% derivation-wide: before per-run isolation existed, one malformed run meant
% NOTHING exported, for this session and every later one. The bad run sorts
% first so that, without isolation, it would take the good run down with it.
d = testCase.TestData.dir;
badId = 'sub-00001_ses-01_task-auction_dom-houses';
goodId = 'sub-00018_ses-01_task-auction_dom-houses';
mkdir(fullfile(d, 'gaze'));
fid = fopen(fullfile(d, 'gaze', [badId '_houses_gaze.mat']), 'w');
fwrite(fid, 'this is not a MAT-file'); fclose(fid);
writeRun(d, goodId, 'houses', 2, 'plain', false);

export_gaze_csv(d);

verifyTrue(testCase, isfile(fullfile(d, 'gaze_qc', [goodId '_houses_gaze.csv'])), ...
    'a malformed run must not abort the runs after it');
end
