%RUN_BATTERY  Single entry point for the housing/wages experiments.
%
% The only file the RA touches: runtime switches and crash recovery. Participant
% identity, domain assignment, and task order are proposed at startup and can be
% edited there when recovery requires it.

clear; clc;
KbName('UnifyKeyNames');

%% ---- Experimenter settings -------------------------------------------
RIG      = 'lab';     % 'lab' or 'dev' -- see utils.rigProfiles
TESTING  = false;      % true = windowed, no prompts, participant 9999
RUN_KIND = 'participant'; % 'participant' = HW_DATA_ROOT | 'practice' = HW_PRACTICE_DATA_ROOT

% Rehearsal knob. [] = the full study. An integer = that many trials in EVERY
% design cell, and nothing else changes (full screen, real pacing, elicitation,
% practice, participant number, eye tracker on). A cell is one combination of
% the manipulated factors: auction = competition low/high; contdc = 3 attribute
% levels x 2 task types per domain. Real sessions use [].
TRIALS_PER_CELL = [];   % <-- [] IS the full participant run; an integer shortens it
JOBS_ARM = 'synthetic'; % 'synthetic' | 'ecological' | 'attenuated'
TRACE    = false;       % true = print a timestamped line at every major
                        % checkpoint. Console-only; off for real sessions.
FORCE_DOMAIN = '';      % '' = use participant parity | 'jobs' | 'houses'
                        % Quick testing/recovery only; leave '' for real sessions.

% PLAN lives in utils.batteryPlan so preflight.m and the live run resolve the
% same rows. Real between-subject sessions are session 1 only.
EYETRACKING = true;
SHOW_EYEPOS = false; % gaze dot overlay -- demo only, off for testing

utils.trace(utils.ternary(TRACE, 'on', 'off'));

%% ---- Session ------------------------------------------------------------
sess = utils.startSession( ...
    'rig',         RIG, ...
    'testing',     TESTING, ...
    'trialsPerCell', TRIALS_PER_CELL, ...
    'jobsArm',     JOBS_ARM, ...
    'runKind',     RUN_KIND, ...
    'eyeTracking', EYETRACKING, ...
    'showEyePos',  SHOW_EYEPOS);

if ~isempty(TRIALS_PER_CELL)
    fprintf(2, ['\n*** REHEARSAL RUN: %d trial(s) per design cell. ***\n' ...
                '    Everything else is the real thing -- full screen, real pacing,\n' ...
                '    real elicitation and practice, saving into the selected data root.\n' ...
                '    ONLY the trial counts are short. Set TRIALS_PER_CELL = [] for a\n' ...
                '    full participant run.\n\n'], TRIALS_PER_CELL);
end
if strcmpi(RUN_KIND, 'practice')
    fprintf(2, ['\n*** PRACTICE DATA ROOT ACTIVE. ***\n' ...
                '    This run writes to the local practice root, not the participant\n' ...
                '    data root. Set RUN_KIND = ''participant'' for collection.\n\n']);
end

thisSession = utils.batteryPlan(sess.participant, sess.sessionNum, ...
    FORCE_DOMAIN, sess.assignment.taskOrder);
utils.sessionContext('battery', sess, thisSession);
if ~isempty(FORCE_DOMAIN)
    fprintf('*** FORCE_DOMAIN active: every run this session uses "%s" regardless of PLAN. ***\n', ...
        FORCE_DOMAIN);
end

fprintf('Session %d plan: ', sess.sessionNum);
for k = 1:numel(thisSession)
    fprintf('%s[%s]  ', thisSession{k}.task, strjoin(thisSession{k}.domains, '+'));
end
fprintf('\n\n');

%% ---- Consent and intake ----------------------------------------------
% BLOCKING. Consent must precede participation, so this runs before any task
% and aborts the session if consent was not obtained. The participant consents
% here, minimises the browser, and comes back to the SAME tab after the battery
% to finish the survey -- so the tab stays open all session.
utils.launchSurvey(sess);

%% ---- Run ------------------------------------------------------------
% Session timing CSV is rewritten after every run, so a crash mid-session
% still leaves the completed runs' timing on disk.
timingRows = {};
timingFile = fullfile(sess.cfg.paths.sessions, ...
    sprintf('sub-%05d_ses-%02d_timing.csv', sess.participant, sess.sessionNum));

for k = 1:numel(thisSession)
    row = thisSession{k};

    run = utils.beginRun(sess, row.task, row.domains);
    if utils.runCheckpoint('complete', sess, run)
        fprintf('Skipping verified completed task: %s\n', run.runId);
        utils.endRun(sess, run, 'complete');
        continue;
    end
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
        utils.progressLog(run, 'BEGIN timing CSV save: %s', timingFile);
        timingRows = appendTiming(timingRows, sess, run, dataMat, ...
            GetSecs - tRunStart, timingFile);
        utils.progressLog(run, 'END timing CSV save; RUN COMPLETE');

    catch ME
        utils.progressLog(run, 'BATTERY ERROR before cleanup\n%s', getReport(ME, 'extended', 'hyperlinks', 'off'));
        % Display first, before anything that can throw. The tasks clean up in
        % their own catch, but an error raised out here -- endRun at the top of
        % the try, appendTiming, or a task failing before its try opens -- would
        % otherwise reach this handler with PTB still up.
        sca; clear PsychImaging; ListenChar(0); ShowCursor;

        % Then bookkeeping, each step guarded. Both of these were bare, so
        % either one failing replaced ME with its own error and skipped the
        % "continue anyway?" prompt below -- turning one bad run into the end of
        % the battery, and destroying the richest record of why it died.
        try
            utils.endRun(sess, run, 'crashed');
        catch manifestME
            fprintf(2, 'Could not mark the run crashed in the manifest: %s\n', manifestME.message);
        end

        try
            crashFile = fullfile(sess.cfg.paths.crashed, [run.runId '_battery_' utils.checkpointIO('id') '_crash.mat']);
            save(crashFile, 'ME', 'sess', 'run');
            fprintf(2, '\n*** %s [%s] crashed. Details saved to:\n    %s\n', ...
                row.task, strjoin(row.domains, '+'), crashFile);
        catch dumpME
            % The dump is how a crash gets diagnosed after the fact, so if it
            % cannot be written, put the original report on screen instead.
            fprintf(2, '\n*** %s [%s] crashed, and the crash dump could not be written (%s).\n', ...
                row.task, strjoin(row.domains, '+'), dumpME.message);
            fprintf(2, '%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
        end

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

% Last thing on the console deliberately: the session is not over. The intake
% half of the Qualtrics response is still unanswered, and the participant is
% about to be thanked and walked out. Printed after the timing table so it is
% what the RA is looking at, not something scrolled past.
if ~TESTING
    fprintf(2, ['\n*** NOT FINISHED: the participant still owes the survey. ***\n' ...
                '    Restore the minimised browser tab (do NOT open a new one --\n' ...
                '    a fresh link starts a separate response) and let them\n' ...
                '    complete the rest of it. Participant number is %d.\n\n'], ...
            sess.participant);
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

T = vertcat(new{:});
T.participant = repmat(sess.participant, height(T), 1);
T.session = repmat(sess.sessionNum, height(T), 1);
T.run_id = repmat(string(run.runId), height(T), 1);
T.timing_id = repmat(string(utils.checkpointIO('id')), height(T), 1);
try
    if isfile(timingFile)
        previous = readtable(timingFile, 'TextType', 'string');
        T = [previous; T];
    end
    tmp = [timingFile '.' utils.checkpointIO('id') '.partial.csv'];
    writetable(T, tmp);
    [ok,msg] = movefile(tmp, timingFile, 'f');
    assert(ok, 'hw:timing:rename', '%s', msg);
catch werr
    warning('run_battery:timingWrite', ...
        'Could not write timing CSV: %s', werr.message);
end
fprintf('  %s [%s] took %.1f min.\n', run.task, run.domainStr, totalSec / 60);
end
