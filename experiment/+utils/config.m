function cfg = config(varargin)
%UTILS.CONFIG  Single source of truth for paths, modes and shared constants.
%
%   cfg = utils.config()
%   cfg = utils.config('rig', 'dev', 'testing', true, 'jobsArm', 'synthetic')
%
%   Options: projRoot, rig ('lab'|'dev'), testing, trialsPerCell, jobsArm,
%   runKind ('participant'|'practice'), dataRoot, practiceDataRoot,
%   assetRoot, tobiiRoot.

p = inputParser;
p.addParameter('projRoot', '', @(x) ischar(x) || isstring(x));
p.addParameter('rig',      'lab', @(x) ismember(lower(char(x)), {'lab','dev'}));
p.addParameter('testing',  false, @islogical);
p.addParameter('trialsPerCell', [], @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && x >= 1 && x == round(x)));
p.addParameter('jobsArm',  'synthetic', @(x) ismember(lower(char(x)), ...
    {'synthetic','ecological','attenuated'}));
p.addParameter('runKind',  'participant', @(x) ismember(lower(char(x)), ...
    {'participant','practice'}));
p.addParameter('dataRoot', '', @(x) ischar(x) || isstring(x));
p.addParameter('practiceDataRoot', '', @(x) ischar(x) || isstring(x));
p.addParameter('assetRoot', '', @(x) ischar(x) || isstring(x));
p.addParameter('tobiiRoot', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opt = p.Results;

shareRoot = '\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4';
shareExperiment = fullfile(shareRoot, 'housing_wages', 'Experiment');

[repoRoot, checkoutExperiment] = checkoutRoots();
if isempty(opt.projRoot)
    projRoot = repoRoot;
    experimentRoot = checkoutExperiment;
    externalDefaults = true;
else
    projRoot = char(opt.projRoot);
    if isfolder(fullfile(projRoot, 'stimuli')) && isfolder(fullfile(projRoot, '+utils'))
        experimentRoot = projRoot;
        projRoot = fileparts(experimentRoot);
    else
        experimentRoot = fullfile(projRoot, 'housing_wages', 'Experiment');
    end
    externalDefaults = false;
end

rp = utils.rigProfiles(opt.rig);
cfg.rig = rp.name;
cfg.aoiEnforcement = rp.aoiEnforcement;
cfg.runKind = lower(char(opt.runKind));

% --- Display / PTB preferences -----------------------------------------
% Machine property, not a testing flag: Windows DWM often fails PTB's sync check
% outright; skipping is the documented workaround (photodiode if timing matters).
cfg.display.skipSyncTests = rp.skipSyncTests;

cfg.paths.root       = projRoot;
cfg.paths.experiment = experimentRoot;
if externalDefaults
    defaultTobii = fullfile(shareRoot, 'TobiiPro.SDK.Matlab_1.9.0.59');
else
    defaultTobii = fullfile(projRoot, 'TobiiPro.SDK.Matlab_1.9.0.59');
end
cfg.paths.tobii = optOrEnv(opt.tobiiRoot, 'HW_TOBII_ROOT', defaultTobii);

% Anchor stimuli paths to cfg.paths.experiment, not cfg.paths.root.
cfg.paths.stimuli    = fullfile(cfg.paths.experiment, 'stimuli');
cfg.paths.prepared   = fullfile(cfg.paths.stimuli, 'prepared');

% --- Runtime data and images --------------------------------------------
% Runtime data/assets live outside the checkout. Git carries code and stimulus
% definitions; the OSU share or environment variables carry large/runtime paths.
cfg.paths.local      = cfg.paths.experiment;
if externalDefaults
    defaultImages = fullfile(shareExperiment, 'stimuli', 'house_images');
else
    defaultImages = fullfile(cfg.paths.stimuli, 'house_images');
end
cfg.paths.images = optOrEnv(opt.assetRoot, 'HW_ASSET_ROOT', defaultImages);

if externalDefaults
    defaultData = fullfile(shareExperiment, 'Data');
    defaultPracticeData = fullfile(shareExperiment, 'Data_practice');
else
    defaultData = fullfile(cfg.paths.experiment, 'Data');
    defaultPracticeData = fullfile(cfg.paths.experiment, 'Data_practice');
end
participantData = optOrEnv(opt.dataRoot, 'HW_DATA_ROOT', defaultData);
practiceData = optOrEnv(opt.practiceDataRoot, 'HW_PRACTICE_DATA_ROOT', defaultPracticeData);
if strcmp(cfg.runKind, 'practice')
    cfg.paths.data = practiceData;
else
    cfg.paths.data = participantData;
end
cfg.paths.fallbackData = fullfile(cfg.paths.local, 'Data_fallback', cfg.runKind);
cfg.paths.sessions         = fullfile(cfg.paths.data, 'sessions');
cfg.paths.taskData.auction = fullfile(cfg.paths.data, 'auction');
cfg.paths.taskData.contdc  = fullfile(cfg.paths.data, 'cont_dc');
cfg.paths.taskData.pref    = fullfile(cfg.paths.data, 'pref');
cfg.paths.gaze             = fullfile(cfg.paths.data, 'gaze');
cfg.paths.crashed          = fullfile(cfg.paths.data, 'Crashes');
cfg.paths = dataPathSet(cfg.paths, cfg.paths.fallbackData, 'fallback');

primaryDirs = writeDirsFor(cfg.paths, '');
fallbackDirs = writeDirsFor(cfg.paths, 'fallback');
if ~ensureWriteDirs(primaryDirs)
    warning('hw:config:dataRootFallback', ...
        ['Could not create or write to the configured data root:\n    %s\n' ...
         'Using local fallback data root:\n    %s'], ...
        cfg.paths.data, cfg.paths.fallbackData);
    cfg.paths.primaryData = cfg.paths.data;
    cfg.paths.data = cfg.paths.fallbackData;
    cfg.paths.sessions         = fullfile(cfg.paths.data, 'sessions');
    cfg.paths.taskData.auction = fullfile(cfg.paths.data, 'auction');
    cfg.paths.taskData.contdc  = fullfile(cfg.paths.data, 'cont_dc');
    cfg.paths.taskData.pref    = fullfile(cfg.paths.data, 'pref');
    cfg.paths.gaze             = fullfile(cfg.paths.data, 'gaze');
    cfg.paths.crashed          = fullfile(cfg.paths.data, 'Crashes');
    primaryDirs = writeDirsFor(cfg.paths, '');
end

if ~ensureWriteDirs(primaryDirs) || ~ensureWriteDirs(fallbackDirs)
    error('hw:config:dataRootMissing', ...
        ['Could not create writable data directories under either:\n' ...
         '    %s\n    %s\n' ...
         'Set HW_DATA_ROOT or HW_PRACTICE_DATA_ROOT to a writable location.'], ...
        cfg.paths.data, cfg.paths.fallbackData);
end

% --- Stimulus files -----------------------------------------------------
% Jobs file is named by arm to keep the link to prepare_stimuli.py's provenance JSON.
cfg.stimuli.jobsArm  = lower(char(opt.jobsArm));
cfg.stimFiles.houses = fullfile(cfg.paths.stimuli, 'house_stimuli.csv');
cfg.stimFiles.jobs   = fullfile(cfg.paths.prepared, ...
    sprintf('job_stimuli_%s.csv', cfg.stimuli.jobsArm));

provFile = fullfile(cfg.paths.prepared, ...
    sprintf('job_stimuli_%s_provenance.json', cfg.stimuli.jobsArm));
if exist(provFile, 'file')
    cfg.stimuli.jobsProvenance = jsondecode(fileread(provFile));
else
    cfg.stimuli.jobsProvenance = [];
    if exist(cfg.stimFiles.jobs, 'file')
        warning('hw:config:noProvenance', ...
            'Found %s but no matching provenance file -- was it produced by prepare_stimuli.py?', ...
            cfg.stimFiles.jobs);
    end
end

% --- Domains --------------------------------------------------------------
cfg.domains.houses = utils.attributes('houses');
cfg.domains.jobs   = utils.attributes('jobs');

% --- Attribute-count manipulation ------------------------------------------
cfg.attrLevels    = [2 4 6];      % counts INCLUDE the core attribute
cfg.attrMethod    = 'stratified'; % 'stratified' | 'topk'
cfg.lateAtMaxOnly = true;         % Zone / work arrangement held to top level

% --- Stimulus sampling ------------------------------------------------
cfg.sampling.spread = [0.6 1.6];  % window around the participant's anchor
cfg.sampling.minN   = 12;         % widen until this many stimuli are inside

% Per domain: false selects in-window rows (sampleWindow), true rank-fits all
% values onto the window (fitToWindow). Houses need fitting: 80 items, 126:1 spread.
cfg.sampling.fitToWindow.houses = true;
cfg.sampling.fitToWindow.jobs   = false;
cfg.sampling.nTopIndustries = 4;

% --- Auction task -----------------------------------------------------
% ABBA blocking via utils.trialPlan; nTrials must divide evenly by nBlocks.
cfg.auction.nTrials          = 24;
cfg.auction.nBlocks          = 4;
cfg.auction.nAttrs           = 6;    % counts the core attribute
cfg.auction.nOptionsPerTrial = 12;   % ~10-15 is what the stimulus set supports
cfg.auction.trialTimeoutSec  = 90;
cfg.auction.feedbackSec      = 2.2;
cfg.auction.driftEvery       = 4;    % drift check every N trials
% Floor on market size after retireStimulus strikes won items.
cfg.auction.minOptionsAfterRetire = 6;

% Market dynamics. Not scaled by testing mode; tune here.
cfg.auction.onMarketMean.low  = 18;  % mean seconds between arrivals
cfg.auction.onMarketMean.high = 12;
cfg.auction.arrivalShape      = 2;   % gamma shape
cfg.auction.dwellFactor       = 3.0; % how long an option stays once it lands

% Vacancy gap: delay before an emptied box may receive the next queued option.
cfg.auction.vacancyGapMean  = 4;   % mean seconds a box stays empty
cfg.auction.vacancyShape    = 2;   % gamma shape
% Cap the gamma tail rather than lowering the mean; only outliers are cut.
cfg.auction.vacancyGapMax   = 10;  % seconds; hard ceiling on the draw

% Acceptance thresholds: multipliers on value, opposite directions per domain
% (buyer bids above, job seeker asks below).
cfg.auction.compHigh       = 1.10;
cfg.auction.compLow        = 0.90;
cfg.auction.thresholdNoise = 0.12;   % without this, high comp guarantees a loss

% --- Continuous / discrete-choice task ---------------------------------
% nPairs is per domain and per attribute level; each pair gives one choice
% trial and two pricing trials.
cfg.contdc.nPairs.houses     = 20;
cfg.contdc.nPairs.jobs       = 20;

% Across-level reuse only; within-level reuse (same pair chosen and priced) is
% required by the preference-reversal paradigm. False is a diagnostic switch.
cfg.contdc.allowCrossLevelReuse = true;

cfg.contdc.choiceTimeoutSec  = 25;
cfg.contdc.priceTimeoutSec   = 40;
cfg.contdc.itiSec            = 0.6;
cfg.contdc.driftEvery        = 2;    % drift check every N blocks

% --- Screen geometry ----------------------------------------------------
% AOI thresholds are in degrees; only the pixel conversion changes per rig.
cfg.geom = utils.geom(rp.geomArgs{:});

% --- Eye tracking -----------------------------------------------------
cfg.et.enabled       = rp.etEnabledDefault;
cfg.et.sampleRateHz  = 60;
cfg.et.driftCheck    = true;
cfg.et.driftTolDeg   = 1.5;
cfg.et.recalOnFail   = true;

% Per-participant calibration (utils.calibrate); distinct from the vendor's
% one-time hardware setup. Leave on unless an external harness calibrates.
cfg.et.useBuiltInCalibration = true;

% showGaze is ignored unless mediaMode is true; mediaMode runs are tagged
% non-analyzable in the saved file.
cfg.et.mediaMode = false;
cfg.et.showGaze  = false;

% --- Head-position guide ----------------------------------------------
% Disabled: rig gave no track-box feedback; run utils.diagnoseTrackBox before re-enabling.
cfg.et.positionGuide.enabled   = false;
cfg.et.positionGuide.tolerance = 0.12;  % deviation from track-box centre, normalised, per axis
cfg.et.positionGuide.holdSec   = 1.0;   % dwell in position before accepting
cfg.et.positionGuide.timeoutSec = 10;   % give up and continue, don't strand the session
cfg.et.positionGuide.mirrorX   = true;  % mirror display; flip if rig reads backwards

% --- Display options --------------------------------------------------
% Not cosmetic: under BDM a salient reference on the scale anchors stated values.
cfg.display.showValueMarker = false;

% Revert switch: 'drag' and 'sequential' are not the same measurement (see utils.elicitRatings).
cfg.elicit.ratingMode = 'drag';   % 'drag' | 'sequential'

% --- Consent and intake survey ----------------------------------------
% Qualtrics, opened BEFORE the first task and gated at the console (see
% utils.launchSurvey). The approved IRB document and its consent checkbox
% live inside this survey, so turning it off on a participant run means no
% consent record exists. baseUrl is the anonymous link; the participant number
% and assignment are appended as query parameters, which Qualtrics keeps ONLY
% if matching Embedded Data fields (pid, ses, domain, order, runkind, version)
% are declared and left blank in Survey Flow. Turn enabled off to run the
% battery alone.
cfg.survey.enabled = false;
cfg.survey.baseUrl = '';

% --- Testing mode -----------------------------------------------------
cfg.testing.enabled          = opt.testing;
cfg.testing.windowed         = rp.windowedDefault || opt.testing;
cfg.testing.skipInstructions = true;
cfg.testing.skipElicitation  = true;
cfg.testing.nTrialsPerType   = 2;
cfg.testing.forceCompetition = [];
cfg.testing.forceAttrLevel   = [];
cfg.testing.participant      = 9999;

% --- Rehearsal mode ---------------------------------------------------
% [] = full study; N = trials per design cell (auction: per competition level,
% contdc: nPairs). Only trial counts change, everything else is a real run.
cfg.rehearsal.trialsPerCell = opt.trialsPerCell;

% --- Incentives -------------------------------------------------------
cfg.incentives = utils.incentives('config');

% --- Styling ------------------------------------------------------------
% Built only here; mutated only in utils.resolveFonts after the window opens.
cfg.style = utils.style();

cfg.codeVersion = 'hw-2026.09';

end

function [repoRoot, experimentRoot] = checkoutRoots()
thisFile = mfilename('fullpath');
utilsDir = fileparts(thisFile);
experimentRoot = fileparts(utilsDir);
repoRoot = fileparts(experimentRoot);
end

function out = optOrEnv(optValue, envName, defaultValue)
if ~isempty(optValue)
    out = char(optValue);
    return
end
envValue = getenv(envName);
if ~isempty(envValue)
    out = envValue;
else
    out = defaultValue;
end
end

function paths = dataPathSet(paths, dataRoot, prefix)
if isempty(prefix)
    paths.sessions         = fullfile(dataRoot, 'sessions');
    paths.taskData.auction = fullfile(dataRoot, 'auction');
    paths.taskData.contdc  = fullfile(dataRoot, 'cont_dc');
    paths.taskData.pref    = fullfile(dataRoot, 'pref');
    paths.gaze             = fullfile(dataRoot, 'gaze');
    paths.crashed          = fullfile(dataRoot, 'Crashes');
else
    paths.([prefix 'Sessions']) = fullfile(dataRoot, 'sessions');
    taskData.auction = fullfile(dataRoot, 'auction');
    taskData.contdc  = fullfile(dataRoot, 'cont_dc');
    taskData.pref    = fullfile(dataRoot, 'pref');
    paths.([prefix 'TaskData']) = taskData;
    paths.([prefix 'Gaze'])    = fullfile(dataRoot, 'gaze');
    paths.([prefix 'Crashed']) = fullfile(dataRoot, 'Crashes');
end
end

function dirs = writeDirsFor(paths, prefix)
if isempty(prefix)
    dirs = {paths.sessions, paths.taskData.auction, ...
            paths.taskData.contdc, paths.taskData.pref, ...
            paths.gaze, paths.crashed};
else
    taskData = paths.([prefix 'TaskData']);
    dirs = {paths.([prefix 'Sessions']), taskData.auction, ...
            taskData.contdc, taskData.pref, ...
            paths.([prefix 'Gaze']), paths.([prefix 'Crashed'])};
end
end

function ok = ensureWriteDirs(dirs)
ok = true;
for k = 1:numel(dirs)
    if ~exist(dirs{k}, 'dir')
        [made, ~] = mkdir(dirs{k});
        if ~made
            ok = false;
            return
        end
    end
    probe = fullfile(dirs{k}, '.write_test');
    [fid, ~] = fopen(probe, 'w');
    if fid < 0
        ok = false;
        return
    end
    fclose(fid);
    delete(probe);
end
end
