%DEMO_BATTERY  A short, self-contained walkthrough of every element of the battery.
%
% ~5-8 minute demo, NOT a pilot: trial counts are cut and DEMO_FAST distorts
% market pacing. Data go to the experiment/Data_demo/ sandbox, stamped demo = true.

clear; clc;
KbName('UnifyKeyNames');

%% ---- Demo switches ----------------------------------------------------
DEMO_DOMAIN  = 'jobs';   % 'jobs' | 'houses'. Houses need the ~605MB image
                         % set; if missing this falls back to jobs.
DEMO_TASKS   = {'auction', 'contdc'};  % drop one to shorten further;
                                       % add 'pref' to demo the preference task
DEMO_FAST    = true;     % compress the auction market clock so a search
                         % episode resolves in ~20s; false = real pacing.
SHOW_INTAKE  = true;     % false = skip elicitation + instructions +
                         % comprehension + practice, straight to trials.
RIG          = 'dev';    % 'dev' (laptop, windowed, no tracker) or 'lab'
EYETRACKING  = false;    % true only on the rig with the Tobii attached
SHOW_GAZE    = false;    % gaze dot overlay -- nice for a demo, needs
                         % EYETRACKING true; also tags the run non-analyzable
JOBS_ARM     = 'synthetic';
TRACE        = true;     % console checkpoints -- useful when demoing so you
                         % can narrate what the code is doing

DEMO_PARTICIPANT = 9999;
DEMO_SESSION     = 1;

%% ---- Locate the checkout ----------------------------------------------
% Runs entirely out of this repository; paths below re-point cfg at the checkout.
here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
addpath(here);

utils.trace(utils.ternary(TRACE, 'on', 'off'));

% utils.config defaults to the OSU share and creates data directories on call,
% so resolve an existing root first. isfolder, not exist: exist is unreliable
% on UNC paths. Off-network, isfolder can block ~20s on the SMB timeout.
shareRoot = '\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4';
if isfolder(shareRoot)
    demoRoot = shareRoot;           % lab machine: keep the real Tobii path
    fprintf('Lab share found; using it for the Tobii SDK path.\n');
else
    demoRoot = fullfile(here, 'Data_demo', 'root');
    fprintf('Lab share not reachable; running entirely from the checkout.\n');
end

%% ---- Session ----------------------------------------------------------
demoParent = fullfile(tempdir,'housing-wages-demo',utils.checkpointIO('id'));
sess = utils.startSession( ...
    'participant', DEMO_PARTICIPANT, ...
    'session',     DEMO_SESSION, ...
    'domain',      1, ...           % overridden per run below
    'testing',     true, ...
    'rig',         RIG, ...
    'projRoot',    demoRoot, ...
    'localDataRoot', demoParent, ...
    'jobsArm',     JOBS_ARM, ...
    'eyeTracking', EYETRACKING, ...
    'showEyePos',  SHOW_GAZE);

cfg = sess.cfg;

%% ---- Re-point every path at the checkout ------------------------------
cfg.paths.experiment = here;
cfg.paths.stimuli    = fullfile(here, 'stimuli');
cfg.paths.prepared   = fullfile(cfg.paths.stimuli, 'prepared');

% Images: prefer a local copy, fall back to whatever cfg already resolved.
localImages = fullfile(cfg.paths.stimuli, 'house_images');
if isfolder(localImages)
    cfg.paths.images = localImages;
end

cfg.stimFiles.houses = fullfile(cfg.paths.stimuli, 'house_stimuli.csv');
cfg.stimFiles.jobs   = fullfile(cfg.paths.prepared, ...
    sprintf('job_stimuli_%s.csv', cfg.stimuli.jobsArm));

% Session creation already used a unique local demo sandbox.
cfg.paths.shareData = '';

%% ---- Domain availability check ----------------------------------------
domain = lower(char(DEMO_DOMAIN));
if strcmp(domain, 'houses') && ~isfolder(cfg.paths.images)
    fprintf(2, ['\n*** House images not found at:\n      %s\n' ...
        '    Falling back to the jobs domain for this demo.\n' ...
        '    The ~605MB image set is not in git. It lives on the share at\n' ...
        '      \\\\asc-files.asc.ohio-state.edu\\projects\\PSY-kvam.4\\housing_wages\\\n' ...
        '        Experiment\\stimuli\\house_images\n' ...
        '    Point HW_ASSET_ROOT at a local copy to override.\n\n'], cfg.paths.images);
    domain = 'jobs';
end
if ~isfile(cfg.stimFiles.(domain))
    error('demo_battery:noStimuli', ...
        'Stimulus file missing for domain "%s":\n    %s', domain, cfg.stimFiles.(domain));
end
sess.domains        = {domain};
sess.domainNum      = utils.ternary(strcmp(domain,'jobs'), 1, 2);
sess.domainOrderStr = domain;

%% ---- Demo-mode task settings ------------------------------------------
cfg.testing.enabled          = true;   % short blocks, windowed, no calibration
cfg.testing.nTrialsPerType   = 2;
cfg.testing.skipInstructions = ~SHOW_INTAKE;
cfg.testing.skipElicitation  = ~SHOW_INTAKE;
cfg.testing.forceCompetition = [];     % keep both levels so the demo shows both
cfg.testing.forceAttrLevel   = [2 6];  % lowest and highest load, skip the middle

if DEMO_FAST
    fprintf(2, ['\n*** DEMO_FAST is on: the auction market clock is compressed.\n' ...
                '    Arrivals, dwell and the trial timeout are all shortened so an\n' ...
                '    episode resolves in ~20s. THIS IS NOT REAL SESSION PACING.\n' ...
                '    Set DEMO_FAST = false to show the market as participants see it.\n\n']);
    cfg.auction.trialTimeoutSec   = 25;
    cfg.auction.onMarketMean.low  = 4;
    cfg.auction.onMarketMean.high = 2.5;
    cfg.auction.dwellFactor       = 2.0;
    cfg.auction.vacancyGapMean    = 1.0;
    cfg.auction.feedbackSec       = 1.6;
    cfg.contdc.itiSec             = 0.3;
end

sess.cfg = cfg;

%% ---- Announce ---------------------------------------------------------
fprintf('\n=== DEMO BATTERY ===\n');
fprintf('  participant : %d (demo)\n', sess.participant);
fprintf('  domain      : %s\n', domain);
fprintf('  tasks       : %s\n', strjoin(DEMO_TASKS, ', '));
fprintf('  rig         : %s   eye tracking: %s\n', cfg.rig, ...
    utils.ternary(cfg.et.enabled, 'on', 'off'));
fprintf('  intake      : %s\n', ...
    utils.ternary(SHOW_INTAKE, 'shown (elicitation, instructions, checks, practice)', 'skipped'));
fprintf('  market      : %s\n', utils.ternary(DEMO_FAST, 'COMPRESSED (demo only)', 'real pacing'));
fprintf('  data -> %s\n', demoData);
fprintf('  NOT a pilot. Trial counts and (if DEMO_FAST) market timing are not the design.\n\n');

%% ---- Run --------------------------------------------------------------
for k = 1:numel(DEMO_TASKS)
    task = DEMO_TASKS{k};

    run = utils.beginRun(sess, task, {domain});
    try
        switch task
            case 'auction'
                auction_task(sess, run);
            case 'contdc'
                continuous_DC_task(sess, run);
            case 'pref'
                preference_task(sess, run);
            otherwise
                error('demo_battery:unknownTask', 'Unknown task "%s".', task);
        end
        utils.endRun(sess, run, 'complete');
        markDemoFile([run.fileStem '.mat']);

    catch ME
        utils.endRun(sess, run, 'crashed');
        sca; clear PsychImaging; ListenChar(0); ShowCursor;
        crashFile = fullfile(cfg.paths.crashed, [run.runId '_crash.mat']);
        save(crashFile, 'ME', 'sess', 'run');
        fprintf(2, '\n*** demo %s crashed. Details: %s\n', task, crashFile);
        rethrow(ME);
    end
end

fprintf('\n=== Demo finished. ===\n');
fprintf('Files written under %s\n', demoData);
fprintf('Next: produce descriptive plots from it with\n');
fprintf('    Rscript analysis/R/run_all.R --data %s\n\n', demoData);


%% ======================================================================
function markDemoFile(matFile)
%MARKDEMOFILE  Stamp demo = true on a saved run so it is never mistaken for real data.
if ~isfile(matFile), return; end
S = load(matFile, 'dataMat');
dataMat = S.dataMat;
dataMat.demo = true;                                        %#ok<STRNU>
save(matFile, 'dataMat', '-v7.3');
end
