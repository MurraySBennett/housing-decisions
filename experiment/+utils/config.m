function cfg = config(varargin)
%UTILS.CONFIG  Single source of truth for paths, modes and shared constants.
%
%   cfg = utils.config()
%   cfg = utils.config('rig', 'dev', 'testing', true, 'jobsArm', 'synthetic')
%
%   Name-value options:
%     'projRoot' override the project root
%     'rig'      'lab' (default) or 'dev' -- see utils.rigProfiles. Controls
%                screen geometry, eye-tracking default, and whether AOI
%                spacing failures are enforced or just informational.
%     'testing'  logical. THIS IS THE FIX for the bug where cfg.testing.
%                enabled stayed false regardless of what was passed to
%                utils.startSession: previously utils.config() took no testing
%                argument at all, so the flag never reached the struct
%                that auction_task/continuous_DC_task actually read.
%     'jobsArm'  'synthetic' (default), 'ecological', or 'attenuated' --
%                see stimgen/README.md. Selects which prepared job stimulus
%                file to load; see also the note on reproducibility below.

p = inputParser;
p.addParameter('projRoot', '', @(x) ischar(x) || isstring(x));
p.addParameter('rig',      'lab', @(x) ismember(lower(char(x)), {'lab','dev'}));
p.addParameter('testing',  false, @islogical);
p.addParameter('trialsPerCell', [], @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && x >= 1 && x == round(x)));
p.addParameter('jobsArm',  'synthetic', @(x) ismember(lower(char(x)), ...
    {'synthetic','ecological','attenuated'}));
p.parse(varargin{:});
opt = p.Results;

if isempty(opt.projRoot)
    projRoot = '\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4';
else
    projRoot = char(opt.projRoot);
end

rp = utils.rigProfiles(opt.rig);
cfg.rig = rp.name;
cfg.aoiEnforcement = rp.aoiEnforcement;

% --- Display / PTB preferences -----------------------------------------
% SkipSyncTests used to be tied to cfg.testing.enabled, which is the wrong
% lever: whether PTB can verify vblank timing is a property of THIS
% MACHINE (OS, driver, compositor), not of whether you're piloting or
% collecting real data. On Windows 10/11 with the DWM compositor active,
% PTB frequently cannot verify sync at all and Screen('OpenWindow') fails
% outright with a hard error rather than a warning -- skipping the test is
% the documented workaround, not a hack. This does mean sub-frame flip
% timing isn't independently verified; if that precision ever matters,
% validate separately with a photodiode rather than relying on PTB's
% internal check on this hardware.
cfg.display.skipSyncTests = rp.skipSyncTests;

cfg.paths.root       = projRoot;
cfg.paths.tobii      = fullfile(projRoot, 'TobiiPro.SDK.Matlab_1.9.0.59');
cfg.paths.experiment = fullfile(projRoot, 'housing_wages', 'Experiment');

% "root/stimuli/..." from earlier refers to your local checkout of
% housing_wages/Experiment (cfg.paths.experiment), NOT the outer network
% share root (cfg.paths.root) -- those are two different "roots" and this
% was pointed at the wrong one. Real path on the share:
%   \\...\PSY-kvam.4\housing_wages\Experiment\stimuli\prepared\...
% cfg.paths.experiment/stimuli holds the raw CSVs and prepare_stimuli.py,
% .../stimuli/house_images holds the house photos, .../stimuli/prepared
% holds prepare_stimuli.py's output (see .../stimuli/stimgen/configs for
% the configs that produce it).
cfg.paths.stimuli    = fullfile(cfg.paths.experiment, 'stimuli');
cfg.paths.prepared   = fullfile(cfg.paths.stimuli, 'prepared');
cfg.paths.images     = fullfile(cfg.paths.stimuli, 'house_images');

cfg.paths.data             = fullfile(cfg.paths.experiment, 'Data');
cfg.paths.sessions         = fullfile(cfg.paths.data, 'sessions');
cfg.paths.taskData.auction = fullfile(cfg.paths.data, 'auction');
cfg.paths.taskData.contdc  = fullfile(cfg.paths.data, 'cont_dc');
cfg.paths.gaze             = fullfile(cfg.paths.data, 'gaze');
cfg.paths.crashed          = fullfile(cfg.paths.data, 'Crashes');

writeDirs = {cfg.paths.sessions, cfg.paths.taskData.auction, ...
             cfg.paths.taskData.contdc, cfg.paths.gaze, cfg.paths.crashed};
for k = 1:numel(writeDirs)
    if ~exist(writeDirs{k}, 'dir'), mkdir(writeDirs{k}); end
end

% --- Stimulus files -----------------------------------------------------
% Houses need no preparation. Jobs are read from whichever arm the
% pipeline produced, named by convention rather than copied/renamed by
% hand -- prepare_stimuli.py always writes prepared/job_stimuli_<arm>.csv
% plus a _provenance.json alongside it. Pointing here at the arm name
% keeps the link to that provenance file intact; a manual copy-and-rename
% severs it, which is exactly the "how do I know which run produced this"
% problem this pipeline exists to avoid.
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
cfg.sampling.nTopIndustries = 4;

% --- Auction task -----------------------------------------------------
% A "trial" is a whole search episode, so 12 of them is roughly 12 minutes
% and yields a lot of gaze data per trial. Attribute count is FIXED here:
% 12 trials over 2 competition levels is 6 per level, which works, but
% adding 3 attribute levels would leave 2 per cell. That manipulation lives
% in continuous_DC_task, which has short trials and can afford it.
%
% These counts are the same for every participant -- personalization lives
% in WHICH stimuli and attributes are shown (via anchor + ratings), not in
% how many trials there are. See the project README for why that split is
% what makes participants comparable at all.
cfg.auction.nTrials          = 12;
cfg.auction.nAttrs           = 6;    % counts the core attribute
cfg.auction.nOptionsPerTrial = 12;   % ~10-15 is what the stimulus set supports
cfg.auction.trialTimeoutSec  = 90;
cfg.auction.feedbackSec      = 2.2;
cfg.auction.driftEvery       = 4;    % drift check every N trials

% Market dynamics. Competition drives turnover as well as price. THESE ARE
% NOT SCALED BY TESTING MODE -- cfg.testing.enabled never touches this
% section, so what you see in a dev/testing run is exactly what a real
% participant would see. If it feels too fast (or slow), that's this
% config, not a testing-only artifact -- tune it here.
%
% Initial pilot numbers were 14s / 7s mean and felt too frantic under high
% competition; slowed to the values below. Still worth another pass once
% you've watched a few real participants play through it.
cfg.auction.onMarketMean.low  = 18;  % mean seconds between arrivals
cfg.auction.onMarketMean.high = 12;
cfg.auction.arrivalShape      = 2;   % gamma shape
cfg.auction.dwellFactor       = 3.0; % how long an option stays once it lands

% Vacancy gap: how long a box stays empty after an option leaves (expired,
% rejected, or bid-rejected) before it's eligible to receive the NEXT
% queued option. Without this, a box that frees up while there's an
% arrival backlog gets refilled in the same frame -- rejecting or losing an
% option instantly produces a replacement, which doesn't read as "this job
% got filled / this house got listed elsewhere," it reads as an infinite
% shuffle. Real markets have a gap between a listing coming down and the
% next one appearing in roughly the same slot.
cfg.auction.vacancyGapMean  = 4;   % mean seconds a box stays empty
cfg.auction.vacancyShape    = 2;   % gamma shape

% Acceptance thresholds. MULTIPLIERS on the item's value, applied in
% opposite directions per domain: a house buyer must bid above the
% threshold, a job seeker must ask below it.
cfg.auction.compHigh       = 1.10;
cfg.auction.compLow        = 0.90;
cfg.auction.thresholdNoise = 0.12;   % without this, high comp guarantees a loss

% --- Continuous / discrete-choice task ---------------------------------
% nPairs is PER DOMAIN because the two domains have very different
% stimulus supply, and because reuse costs more in one than the other.
%
% Each level needs nPairs x 2 distinct stimuli, and by default a stimulus
% is never reused ACROSS attribute levels (see allowCrossLevelReuse). So
% the requirement is nLevels x nPairs x 2 distinct stimuli per domain.
%
% Houses: 80 total, but a budget-centred window holds only ~23-39 of them
% (23 at a $250k anchor, 38-39 mid-range, 28 at $900k). At 3 levels,
% 6 pairs needs 36 distinct houses -- feasible mid-range, tight at the
% extremes. 10 pairs would need 60, which no window can supply, forcing
% reuse. Hence 6.
%
% Jobs: 128 total, ~96 in a typical window, and a job is a handful of
% numeric ratings rather than six photographs -- far less episodically
% memorable, so a repeat is much less likely to be recognised. 10 pairs
% (60 distinct) fits comfortably.
cfg.contdc.nPairs.houses     = 6;
cfg.contdc.nPairs.jobs       = 10;

% Cross-level reuse. FALSE (default) means a given house/job appears at
% exactly one attribute level for a given participant, so their valuation
% at level 6 can't be contaminated by having already priced that same item
% at level 2. TRUE relaxes this when supply is tight -- reuse then gets
% logged per trial so it can be tested or excluded in analysis.
%
% Note this is about reuse ACROSS LEVELS only. Reuse WITHIN a level (the
% same pair being both chosen between and priced) is required by the
% preference-reversal paradigm and always happens.
cfg.contdc.allowCrossLevelReuse = false;

cfg.contdc.choiceTimeoutSec  = 15;
cfg.contdc.priceTimeoutSec   = 25;
cfg.contdc.itiSec            = 0.6;
cfg.contdc.driftEvery        = 2;    % drift check every N blocks

% --- Screen geometry ----------------------------------------------------
% Comes from the rig profile. AOI thresholds are defined in DEGREES, so the
% same numbers stay meaningful on the lab machine and on a laptop; only the
% pixel conversion changes.
cfg.geom = utils.geom(rp.geomArgs{:});

% --- Eye tracking -----------------------------------------------------
cfg.et.enabled       = rp.etEnabledDefault;
cfg.et.sampleRateHz  = 60;
cfg.et.driftCheck    = true;
cfg.et.driftTolDeg   = 1.5;
cfg.et.recalOnFail   = true;

% Built-in participant calibration (ScreenBasedCalibration via utils.calibrate)
% vs. any vendor/desktop calibration utility are two different things: the
% desktop tool is a one-time HARDWARE setup (lens/angle/lighting), while
% utils.calibrate is the PER-PARTICIPANT, per-session calibration every
% tracker needs regardless of hardware setup. Leave this on; turning it off
% only makes sense if calibration is being driven by an external harness
% that calls the Tobii SDK directly instead of through this code.
cfg.et.useBuiltInCalibration = true;

% Media mode: gaze dot visible for screen recording. Deliberately separate
% from 'testing' so it can't be left on by accident -- showGaze is ignored
% unless mediaMode is also true, and any run with it on is tagged
% non-analyzable in the saved file.
cfg.et.mediaMode = false;
cfg.et.showGaze  = false;

% --- Head-position guide ----------------------------------------------
% Shown once before calibration: live feedback on where the tracker sees
% the participant's eyes versus where they need to be. Calibration can
% succeed from a poor position and then drift or drop an eye mid-block,
% by which point the trials are spent.
cfg.et.positionGuide.enabled   = true;
cfg.et.positionGuide.tolerance = 0.12;  % allowed deviation from track-box
                                        % centre, in normalised units, on
                                        % each of x, y and z
cfg.et.positionGuide.holdSec   = 1.0;   % time in position before it
                                        % accepts -- stops a participant
                                        % passing through the right spot
                                        % from counting as settled in it
cfg.et.positionGuide.timeoutSec = 90;   % give up and continue rather than
                                        % strand a session on a setup screen
cfg.et.positionGuide.mirrorX   = true;  % display behaves like a mirror;
                                        % flip if the rig reads backwards

% --- Display options --------------------------------------------------
% Draw the advertised figure (listed price / offered wage) on the pricing
% scale, so the participant can see where it sits relative to the value
% they are about to state.
%
% THIS IS NOT COSMETIC. Under BDM the optimal bid is the participant's own
% valuation, and a salient reference point on the response scale is
% exactly the kind of cue that pulls stated values toward it. Turning this
% on is a deliberate design choice with a measurable cost in bid variance;
% turning it off restores the scale to an unanchored one.
cfg.display.showValueMarker = true;

% --- Testing mode -----------------------------------------------------
cfg.testing.enabled          = opt.testing;   % <-- now actually wired up
cfg.testing.windowed         = rp.windowedDefault || opt.testing;
cfg.testing.skipInstructions = true;
cfg.testing.skipElicitation  = true;
cfg.testing.nTrialsPerType   = 2;
cfg.testing.forceCompetition = [];
cfg.testing.forceAttrLevel   = [];
cfg.testing.participant      = 9999;

% --- Rehearsal mode ---------------------------------------------------
% A SHORT run that is otherwise a REAL run. Deliberately separate from
% cfg.testing, which is a developer mode: testing also goes windowed,
% skips elicitation, instructions and practice, and pins participant
% 9999. None of that is wanted for a dress rehearsal, where the point is
% to sit through the genuine article at genuine pacing and only stop
% sooner.
%
% [] means the full study. An integer means that many trials in EVERY
% design cell, and it is the ONLY thing that changes -- full screen, real
% pacing, real elicitation, real instructions, real practice, real
% participant number, eye tracker on.
%
% "Cell" means one combination of the manipulated factors, so the count
% is comparable across tasks, which cfg.testing.nTrialsPerType is not:
%   auction -- cells are the competition levels, so nTrials = N * 2
%   contdc  -- cells are attribute level x task type, so nPairs = N
%              (a price block prices both options of every pair, so it
%              still yields 2N trials to a choice block's N)
%
% Going to a full participant run is then exactly one edit: set this back
% to [].
cfg.rehearsal.trialsPerCell = opt.trialsPerCell;

% --- Incentives -------------------------------------------------------
cfg.incentives = utils.incentives('config');

% --- Styling ------------------------------------------------------------
% utils.style reads $HW_THEME. This is the only place it is built; the
% one place it is later MUTATED is utils.resolveFonts, called once per
% task after the window opens. Everything else reads cfg.style at draw time.
cfg.style = utils.style();

cfg.codeVersion = 'hw-2026.09';

end
