%RUN_BATTERY  Single entry point for the housing/wages experiments.
%
% This is the only file the RA touches. It handles participant identity,
% counterbalancing, and crash recovery; the tasks themselves stay
% self-contained and can still be run individually.
%
% Domain and task are now independent choices per run, so any of these is
% just a different PLAN below -- nothing in the task code changes:
%
%   Jobs only, one task:        {task:'auction', domains:{'jobs'}}
%   Houses only, one task:      {task:'contdc',  domains:{'houses'}}
%   Jobs, both tasks:           two PLAN rows, both domains:{'jobs'}
%   Houses, both tasks:         two PLAN rows, both domains:{'houses'}
%   Everything, one sitting:    four PLAN rows, session 1 throughout
%   Everything, two sessions:   split the four rows across 'session' 1 and 2
%
% Each PLAN row becomes one call to utils.beginRun / utils.endRun and one saved
% data file, tagged with both its task and its domain set in the filename
% and in the manifest -- so a participant who does jobs-auction today and
% houses-contdc next week is fully reconstructable from the manifest alone.

clear; clc;
KbName('UnifyKeyNames');

%% ---- Experimenter settings -------------------------------------------
RIG      = 'lab';     % 'lab' or 'dev' -- see utils.rigProfiles
TESTING  = false;      % true = windowed, no prompts, participant 9999

% Dress-rehearsal knob. [] = the full study. An integer = that many trials
% in EVERY design cell, and nothing else changes: full screen, real
% pacing, real elicitation, real instructions, real practice, real
% participant number, eye tracker on. Going to a full participant run is
% exactly one edit -- set this back to [].
%
% "Cell" means one combination of the manipulated factors, so the number
% means the same thing in both tasks:
%   auction -- competition low/high      -> 2 trials each = 4 total
%   contdc  -- 3 attribute levels x 2 task types, per domain
%              -> 2 pairs per level = 2 choice + 4 price trials per level
%                 (a price block prices both options of every pair)
%
% This is NOT cfg.testing.nTrialsPerType, which is a developer knob that
% sets the auction's TOTAL rather than its per-cell count, and which only
% applies when TESTING is on and therefore drags windowed mode and skipped
% elicitation along with it.
TRIALS_PER_CELL = 2;   % <-- set to [] for a full participant run
JOBS_ARM = 'synthetic'; % 'synthetic' | 'ecological' | 'attenuated'
TRACE    = false;       % true = print a timestamped line at every major
                        % checkpoint (window open, stimuli loaded, each
                        % block, etc.) -- turn on when debugging a crash,
                        % leave off for real sessions. Console-only, not
                        % saved to any data file.
FORCE_DOMAIN = '';      % '' = use PLAN as written | 'jobs' | 'houses'
                        % PLAN's domains are keyed to session number, NOT
                        % to anything you'd answer at a prompt -- there
                        % used to be a "Jobs/Houses/both" prompt that
                        % LOOKED like it controlled this but didn't; it
                        % only ever mattered for a task called standalone,
                        % never for a run_battery-driven session. This is
                        % the actual control: set it to force every run
                        % this session onto one domain regardless of what
                        % PLAN says, for quick manual testing. Leave empty
                        % for real sessions -- it silently overrides your
                        % carefully-assigned PLAN if left on by accident.

% The concrete PLAN lives in utils.batteryPlan so preflight.m and the live
% run resolve the same rows. Rows with the same session number run back to
% back in one sitting; different session numbers are run on separate days
% with the same participant ID.
EYETRACKING = true;
SHOW_EYEPOS = false; % gaze dot overlay -- demo only, off for testing

utils.trace(utils.ternary(TRACE, 'on', 'off'));

%% ---- Session ------------------------------------------------------------
sess = utils.startSession( ...
    'rig',         RIG, ...
    'testing',     TESTING, ...
    'trialsPerCell', TRIALS_PER_CELL, ...
    'jobsArm',     JOBS_ARM, ...
    'eyeTracking', EYETRACKING, ...
    'showEyePos',  SHOW_EYEPOS, ...
    'domain',      3);   % value is irrelevant here -- PLAN decides domain
                          % for every run_battery-driven session, not this.
                          % Passing anything just skips a prompt that would
                          % otherwise ask a question with no effect.

if ~isempty(TRIALS_PER_CELL)
    fprintf(2, ['\n*** REHEARSAL RUN: %d trial(s) per design cell. ***\n' ...
                '    Everything else is the real thing -- full screen, real pacing,\n' ...
                '    real elicitation and practice, saving into the real Data tree.\n' ...
                '    ONLY the trial counts are short. Set TRIALS_PER_CELL = [] for a\n' ...
                '    full participant run.\n\n'], TRIALS_PER_CELL);
end

thisSession = utils.batteryPlan(sess.participant, sess.sessionNum, FORCE_DOMAIN);
if ~isempty(FORCE_DOMAIN)
    fprintf('*** FORCE_DOMAIN active: every run this session uses "%s" regardless of PLAN. ***\n', ...
        FORCE_DOMAIN);
end

fprintf('Session %d plan: ', sess.sessionNum);
for k = 1:numel(thisSession)
    fprintf('%s[%s]  ', thisSession{k}.task, strjoin(thisSession{k}.domains, '+'));
end
fprintf('\n\n');

%% ---- Run ------------------------------------------------------------
for k = 1:numel(thisSession)
    row = thisSession{k};

    run = utils.beginRun(sess, row.task, row.domains);
    try
        switch row.task
            case 'auction'
                auction_task(sess, run);
            case 'contdc'
                continuous_DC_task(sess, run);
            otherwise
                error('run_battery:unknownTask', 'Unknown task "%s".', row.task);
        end
        utils.endRun(sess, run, 'complete');

    catch ME
        utils.endRun(sess, run, 'crashed');
        sca; clear PsychImaging; ListenChar(0); ShowCursor;

        crashFile = fullfile(sess.cfg.paths.crashed, [run.runId '_crash.mat']);
        save(crashFile, 'ME', 'sess', 'run');
        fprintf(2, '\n*** %s [%s] crashed. Details saved to:\n    %s\n', ...
            row.task, strjoin(row.domains, '+'), crashFile);

        if k < numel(thisSession)
            go = input('Continue to the next run anyway? (y/n): ', 's');
            if ~strcmpi(strtrim(go), 'y'), rethrow(ME); end
        else
            rethrow(ME);
        end
    end
end

fprintf('\nSession %d finished for participant %d.\n', sess.sessionNum, sess.participant);
