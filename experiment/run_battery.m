%RUN_BATTERY  Single entry point for the housing/wages experiments.
%
% The only file the RA touches: participant identity, counterbalancing, crash
% recovery. Each PLAN row becomes one run and one tagged data file.

clear; clc;
KbName('UnifyKeyNames');

%% ---- Experimenter settings -------------------------------------------
RIG      = 'lab';     % 'lab' or 'dev' -- see utils.rigProfiles
TESTING  = false;      % true = windowed, no prompts, participant 9999

% Rehearsal knob. [] = the full study. An integer = that many trials in EVERY
% design cell, and nothing else changes (full screen, real pacing, elicitation,
% practice, participant number, eye tracker on). A cell is one combination of
% the manipulated factors: auction = competition low/high; contdc = 3 attribute
% levels x 2 task types per domain. Real sessions use [].
TRIALS_PER_CELL = [];   % <-- [] IS the full participant run; an integer shortens it
JOBS_ARM = 'synthetic'; % 'synthetic' | 'ecological' | 'attenuated'
TRACE    = false;       % true = print a timestamped line at every major
                        % checkpoint. Console-only; off for real sessions.
FORCE_DOMAIN = '';      % '' = use PLAN as written | 'jobs' | 'houses'
                        % Forces every run onto one domain, silently
                        % overriding PLAN; leave '' for real sessions.

% PLAN lives in utils.batteryPlan so preflight.m and the live run resolve the
% same rows; same session number = one sitting, different = separate days.
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
% Session timing CSV is rewritten after every run, so a crash mid-session
% still leaves the completed runs' timing on disk.
timingRows = {};
timingFile = fullfile(sess.cfg.paths.sessions, ...
    sprintf('sub-%05d_ses-%02d_timing.csv', sess.participant, sess.sessionNum));

for k = 1:numel(thisSession)
    row = thisSession{k};

    run = utils.beginRun(sess, row.task, row.domains);
    tRunStart = GetSecs;
    try
        switch row.task
            case 'auction'
                dataMat = auction_task(sess, run);
            case 'contdc'
                dataMat = continuous_DC_task(sess, run);
            case 'pref'
                dataMat = preference_task(sess, run);
            otherwise
                error('run_battery:unknownTask', 'Unknown task "%s".', row.task);
        end
        utils.endRun(sess, run, 'complete');
        timingRows = appendTiming(timingRows, sess, run, dataMat, ...
            GetSecs - tRunStart, timingFile);

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

if ~isempty(timingRows)
    fprintf('\nTiming breakdown (also in %s):\n', timingFile);
    T = vertcat(timingRows{:});
    disp(T);
    fprintf('Session total: %.1f min\n', sum(T.seconds(T.section == "total")) / 60);
end


%% =====================================================================
function rows = appendTiming(rows, sess, run, dataMat, totalSec, timingFile)
%APPENDTIMING  Fold one run's section timing into the session CSV.
%   Adds a 'total' row per run and rewrites the CSV after every run.
new = {};
if isstruct(dataMat) && isfield(dataMat, 'timing') && ~isempty(dataMat.timing)
    tt = dataMat.timing;
    for r = 1:height(tt)
        new{end+1} = table(string(run.task), string(run.domainStr), ...
            tt.section(r), tt.seconds(r), ...
            'VariableNames', {'task','domains','section','seconds'}); %#ok<AGROW>
    end
end
new{end+1} = table(string(run.task), string(run.domainStr), "total", totalSec, ...
    'VariableNames', {'task','domains','section','seconds'});
rows = [rows, new];

T = vertcat(rows{:});
T.participant = repmat(sess.participant, height(T), 1);
T.session = repmat(sess.sessionNum, height(T), 1);
try
    writetable(T, timingFile);
catch werr
    warning('run_battery:timingWrite', ...
        'Could not write timing CSV: %s', werr.message);
end
fprintf('  %s [%s] took %.1f min.\n', run.task, run.domainStr, totalSec / 60);
end
