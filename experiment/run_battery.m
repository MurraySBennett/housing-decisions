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

% Each row: which task, which domain(s), and which session number it
% belongs to. Rows with the same session number run back to back in one
% sitting; different session numbers are for a between-session design and
% are simply run on separate days by calling this script again with the
% same participant ID -- utils.startSession resumes from the manifest.
PLAN = { ...
    struct('task', 'auction', 'domains', {{'jobs'}},   'session', 1), ...
    struct('task', 'contdc',  'domains', {{'jobs'}},   'session', 1), ...
    struct('task', 'auction', 'domains', {{'houses'}}, 'session', 2), ...
    struct('task', 'contdc',  'domains', {{'houses'}}, 'session', 2), ...
};

COUNTERBAL = true;   % flip within-session task order for odd participants
EYETRACKING = true;
SHOW_EYEPOS = false; % gaze dot overlay -- demo only, off for testing

utils.trace(utils.ternary(TRACE, 'on', 'off'));

%% ---- Session ------------------------------------------------------------
sess = utils.startSession( ...
    'rig',         RIG, ...
    'testing',     TESTING, ...
    'jobsArm',     JOBS_ARM, ...
    'eyeTracking', EYETRACKING, ...
    'showEyePos',  SHOW_EYEPOS, ...
    'domain',      3);   % value is irrelevant here -- PLAN decides domain
                          % for every run_battery-driven session, not this.
                          % Passing anything just skips a prompt that would
                          % otherwise ask a question with no effect.

thisSession = PLAN(cellfun(@(r) r.session == sess.sessionNum, PLAN));
if isempty(thisSession)
    error('run_battery:noPlanForSession', ...
        'No PLAN rows have session == %d. Check PLAN or the session number entered.', ...
        sess.sessionNum);
end

if ~isempty(FORCE_DOMAIN)
    assert(ismember(FORCE_DOMAIN, {'jobs','houses'}), ...
        'FORCE_DOMAIN must be '''', ''jobs'', or ''houses''.');
    for k = 1:numel(thisSession)
        thisSession{k}.domains = {FORCE_DOMAIN};
    end
    fprintf('*** FORCE_DOMAIN active: every run this session uses "%s" regardless of PLAN. ***\n', ...
        FORCE_DOMAIN);
end

if COUNTERBAL && numel(thisSession) > 1 && mod(sess.participant, 2) == 1
    thisSession = fliplr(thisSession);
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
