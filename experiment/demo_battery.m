%DEMO_BATTERY  A short, self-contained walkthrough of every element of the battery.
%
% PURPOSE: showing someone (an RA, a collaborator, yourself) what a session
% actually looks like, end to end, in ~5-8 minutes instead of ~45. It touches
% every participant-facing element in order:
%
%   1. anchor elicitation (budget / reservation wage)
%   2. attribute importance ratings (VAS), and industry ratings for jobs
%   3. task instructions
%   4. comprehension checks
%   5. auction: practice episode, then 2 real search episodes (one per
%      competition level)
%   6. contdc: choice block then pricing block, at 2 attribute levels
%   7. the end-of-run summary / payout screen
%
% THIS IS NOT A PILOT AND NOT A DRESS REHEARSAL.
% It deliberately distorts the design to fit in a demo slot:
%   - 2 trials per type instead of 12 / 6-10 pairs
%   - the auction market runs FAST (see DEMO_FAST below) -- real sessions do
%     not, and `cfg.auction` timing is deliberately NOT scaled by testing
%     mode anywhere else in this codebase
% For a real timing/duration check, use `preflight.m` and a TESTING run of
% `run_battery.m`, not this.
%
% WHERE THE DATA GOES: a sandbox, `experiment/Data_demo/`, never the real
% `Data/` tree and never the OSU share. Every saved file is stamped
% `dataMat.demo = true`. The analysis scripts in `analysis/` read this
% sandbox by default, so you can run the demo and then immediately produce
% descriptive plots from it.
%
% USAGE
%   demo_battery                 % jobs, both tasks, no eye tracker
%   then edit the switches below for houses / eye tracking / a slower market.

clear; clc;
KbName('UnifyKeyNames');

%% ---- Demo switches ----------------------------------------------------
DEMO_DOMAIN  = 'jobs';   % 'jobs' | 'houses'. Houses need the ~605MB image
                         % set (see STIMULI.md); if it isn't found this
                         % falls back to jobs rather than crashing.
DEMO_TASKS   = {'auction', 'contdc'};  % drop one to shorten further;
                                       % add 'pref' to demo the preference task
DEMO_FAST    = true;     % compress the auction market clock so a search
                         % episode resolves in ~20s instead of up to 90s.
                         % Set false to show real market pacing.
SHOW_INTAKE  = true;     % false = skip elicitation + instructions +
                         % comprehension + practice, straight to trials.
                         % Use false for a 2-minute "here are the screens"
                         % pass; true to show the whole intake.
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
% The demo runs entirely out of this repository so it works on a laptop with
% no access to the OSU share. utils.config defaults to the share; everything
% below re-points it at the checkout.
here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
addpath(here);

utils.trace(utils.ternary(TRACE, 'on', 'off'));

% utils.config defaults projRoot to the OSU share and CREATES its data
% directories as a side effect of being called. On a laptop with no share
% that either errors or hangs on a network timeout, so resolve a root that
% actually exists before calling startSession rather than repairing it after.
% isfolder, not exist(...,'dir'): exist searches the MATLAB path for the name
% first and is unreliable on UNC paths, which is exactly what this is. Note
% this call can block for ~20s on the SMB timeout if the machine is off the
% OSU network -- that is the network, not a hang.
shareRoot = '\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4';
if isfolder(shareRoot)
    demoRoot = shareRoot;           % lab machine: keep the real Tobii path
    fprintf('Lab share found; using it for the Tobii SDK path.\n');
else
    demoRoot = fullfile(here, 'Data_demo', 'root');
    fprintf('Lab share not reachable; running entirely from the checkout.\n');
end

%% ---- Session ----------------------------------------------------------
sess = utils.startSession( ...
    'participant', DEMO_PARTICIPANT, ...
    'session',     DEMO_SESSION, ...
    'domain',      1, ...           % overridden per run below
    'testing',     true, ...
    'rig',         RIG, ...
    'projRoot',    demoRoot, ...
    'jobsArm',     JOBS_ARM, ...
    'eyeTracking', EYETRACKING, ...
    'showEyePos',  SHOW_GAZE);

% startSession already wrote a manifest under the root resolved above. The
% data paths get re-pointed at the sandbox below, so that one is stray.
strayManifest = sess.manifestFile;

cfg = sess.cfg;

%% ---- Re-point every path at the checkout ------------------------------
cfg.paths.experiment = here;
cfg.paths.stimuli    = fullfile(here, 'stimuli');
cfg.paths.prepared   = fullfile(cfg.paths.stimuli, 'prepared');

% Images: prefer a local copy, fall back to whatever cfg already resolved
% (the share, if this is the lab machine and it's mounted).
localImages = fullfile(cfg.paths.stimuli, 'house_images');
if isfolder(localImages)
    cfg.paths.images = localImages;
end

cfg.stimFiles.houses = fullfile(cfg.paths.stimuli, 'house_stimuli.csv');
cfg.stimFiles.jobs   = fullfile(cfg.paths.prepared, ...
    sprintf('job_stimuli_%s.csv', cfg.stimuli.jobsArm));

% Data sandbox. Never the real Data/ tree, never the share.
demoData = fullfile(here, 'Data_demo');
cfg.paths.data             = demoData;
cfg.paths.sessions         = fullfile(demoData, 'sessions');
cfg.paths.taskData.auction = fullfile(demoData, 'auction');
cfg.paths.taskData.contdc  = fullfile(demoData, 'cont_dc');
cfg.paths.taskData.pref    = fullfile(demoData, 'pref');
cfg.paths.gaze             = fullfile(demoData, 'gaze');
cfg.paths.crashed          = fullfile(demoData, 'Crashes');
demoDirs = {cfg.paths.sessions, cfg.paths.taskData.auction, ...
            cfg.paths.taskData.contdc, cfg.paths.taskData.pref, ...
            cfg.paths.gaze, cfg.paths.crashed};
for k = 1:numel(demoDirs)
    if ~isfolder(demoDirs{k}), mkdir(demoDirs{k}); end
end

% startSession computed the manifest path from the OLD cfg, so it has to be
% recomputed now or the demo would append to the real manifest.
sess.manifestFile = fullfile(cfg.paths.sessions, ...
    sprintf('sub-%05d_manifest.mat', sess.participant));
if ~strcmp(strayManifest, sess.manifestFile) && isfile(strayManifest)
    delete(strayManifest);          % only ever the demo ID's, just created
end
if isfile(sess.manifestFile), delete(sess.manifestFile); end
manifest = struct('participant', sess.participant, ...
    'createdAt', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
    'runs', struct('task',{},'sessionNum',{},'runId',{},'domainOrderStr',{}, ...
                   'startedAt',{},'finishedAt',{},'status',{},'dataFile',{}, ...
                   'seed',{},'codeVersion',{}));
save(sess.manifestFile, 'manifest');
sess.manifest = manifest;

%% ---- Domain availability check ----------------------------------------
domain = lower(char(DEMO_DOMAIN));
if strcmp(domain, 'houses') && ~isfolder(cfg.paths.images)
    fprintf(2, ['\n*** House images not found at:\n      %s\n' ...
        '    Falling back to the jobs domain for this demo. See STIMULI.md\n' ...
        '    for where the ~605MB image set lives.\n\n'], cfg.paths.images);
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
    % Loud, because this is the one thing the demo changes that a viewer
    % could mistake for the real design.
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
%MARKDEMOFILE  Stamp demo = true on a saved run so it can never be mistaken
%   for pilot or participant data, even if the file is moved out of the
%   sandbox directory.
if ~isfile(matFile), return; end
S = load(matFile, 'dataMat');
dataMat = S.dataMat;
dataMat.demo = true;                                        %#ok<STRNU>
save(matFile, 'dataMat', '-v7.3');
end
