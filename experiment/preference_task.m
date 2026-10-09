function dataMat = preference_task(sess, run)
%PREFERENCE_TASK  Style/category preference task, per domain.
%   dataMat = preference_task(sess, run); with no arguments it runs standalone.
%   Houses: photo ratings plus within-area pairwise choices. Jobs: pairwise
%   choices, always from the ECOLOGICAL file -- synthetic titles never reach a screen.

%% ---- Task constants ---------------------------------------------------
TASK_MODE = 'both';        % houses only: 'rating' | 'pwc' | 'both'
N_RATING = 60;             % houses: 10 direct photo ratings per area
N_PWC_HOUSES = 160;        % houses: within-area pairwise comparisons
N_PWC_JOBS = 160;          % jobs: cross-industry pairwise comparisons
SECTION_ORDER = 'counterbalanced';  % houses, TASK_MODE='both'
FIX_SEC = 0.5;             % centered fixation cue before every trial
ISI_RANGE_SEC = [0.4 0.7]; % blank inter-trial interval, uniform jitter

% Editable area quotas (houses). Defaults sum to 60.
AREA_QUOTAS = struct( ...
    'extPic',  10, ...
    'kitPic',  10, ...
    'bedPic',  10, ...
    'bathPic', 10, ...
    'livPic',  10, ...
    'outPic',  10);

%% ---- Session ----------------------------------------------------------
if nargin < 1 || isempty(sess)
    sess = bootstrapStandaloneSession();
end
if nargin < 2 || isempty(run)
    run = utils.beginRun(sess, 'pref');
    standalone = true;
else
    standalone = false;
end

if isfield(run, 'domains') && ~isempty(run.domains)
    domainList = run.domains;
else
    domainList = sess.domains;
end

cfg = sess.cfg;
rs  = RandStream('twister', 'Seed', run.seed);
tl  = utils.timeline('start');

dataMat = struct();
dataMat.domains = domainList;
dataMat.theme = cfg.style.themeName;
dataMat.trialsPerCell = cfg.rehearsal.trialsPerCell;
dataMat.taskMode = TASK_MODE;
dataMat.fixSec = FIX_SEC;
dataMat.isiRangeSec = ISI_RANGE_SEC;

window = [];
et = struct('enabled', false, 'obj', [], 'showGaze', false, 'analyzable', false);

utils.progressLog(run, 'TASK ENTER');
try
    %% ---- Display ------------------------------------------------------
    clear PsychImaging;
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', double(cfg.display.skipSyncTests));
    screenNumber = max(Screen('Screens'));
    if cfg.testing.windowed
        [window, ~] = PsychImaging('OpenWindow', screenNumber, cfg.style.bg, [50 50 1330 770]);
    else
        [window, ~] = PsychImaging('OpenWindow', screenNumber, cfg.style.bg);
    end
    Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
    cfg.style = utils.resolveFonts(window, cfg.style);
    sess.cfg = cfg;
    ShowCursor('Arrow', window);

    %% ---- Eye tracking -------------------------------------------------
    et = utils.setupEyeTracker(cfg, window, ~cfg.testing.enabled);
    dataMat.eyeTracking = struct('enabled', et.enabled, ...
        'calibrated', et.calibrated, 'positioned', et.positioned, ...
        'analyzable', et.analyzable, ...
        'requestedSampleRateHz', et.requestedSampleRateHz, ...
        'actualSampleRateHz', et.actualSampleRateHz, ...
        'setupFailureStage', et.setupFailureStage, ...
        'setupFailureMessage', et.setupFailureMessage, ...
        'operatorChoice', et.operatorChoice);

    G = prefLayout(window);

    for d = 1:numel(domainList)
        domain = lower(domainList{d});
        tl = utils.timeline('section', tl, sprintf('%s:load', domain));
        frozen = utils.runCheckpoint('peek', sess, run, domain);
        if isempty(frozen)
            switch domain
                case 'houses'
                    stimTbl = utils.readStimuli(cfg, 'houses');
                    plan = utils.buildPhotoPreferencePlan(stimTbl, N_RATING, N_PWC_HOUSES, AREA_QUOTAS, rs);
                    sections = resolveSections(TASK_MODE, SECTION_ORDER, sess.participant);
                    chunks = utils.preferenceChunks(sections, numel(plan.ratingPhotoRows), size(plan.pwcPairs, 1));
                case 'jobs'
                    prefCfg = cfg;
                    prefCfg.stimFiles.jobs = fullfile(cfg.paths.prepared, 'job_stimuli_ecological.csv');
                    stimTbl = utils.readStimuli(prefCfg, 'jobs');
                    plan = utils.buildJobPreferencePlan(stimTbl, N_PWC_JOBS, rs);
                    sections = {'pwc'};
                    chunks = utils.preferenceChunks(sections, 0, size(plan.pwcPairs, 1));
                otherwise
                    error('hw:pref:badDomain', 'Unknown domain "%s".', domain);
            end
            frozen = struct('plan', plan, 'sections', {sections}, 'chunks', chunks, ...
                'blockCount', numel(chunks), 'rsState', rs.State, 'globalState', rng, 'layout', G);
            utils.runCheckpoint('freeze', sess, run, domain, frozen);
        end
        plan = frozen.plan; sections = frozen.sections; chunks = frozen.chunks;
        assert(isequal(G, frozen.layout), 'hw:pref:displayChanged', 'Display geometry changed on resume.');
        rs.State = frozen.rsState; rng(frozen.globalState);
        tex = [];
        dataMat.(domain).layout = G;
        dataMat.(domain).sectionOrder = sections;
        dataMat.(domain).rating = struct('trials', []);
        dataMat.(domain).pwc = struct('trials', []);
        if strcmp(domain, 'houses')
            tex = loadPhotoTextures(window, cfg, plan.photoTable, unique([plan.ratingPhotoRows; plan.pwcPairs(:)]));
            dataMat.houses.photoTable = plan.photoTable;
            dataMat.houses.areaQuotas = plan.areaQuotas;
            dataMat.houses.pwcPairsPerArea = plan.pwcPairsPerArea;
            showMessage(window, cfg, introText(sections));
        else
            dataMat.jobs.jobTable = plan.jobTable;
            showMessage(window, cfg, ['Job choices\n\nYou will see two jobs at a time, showing only the industry ' ...
                'and the job title.\n\nPress Z to choose the left job, or M to choose the right job.\n\nClick to begin.']);
        end
        recovery = utils.taskBlock('recover', sess, run, domain);
        for k = 1:numel(recovery.blocks)
            prior = recovery.blocks{k}; section = prior.metadata.section;
            dataMat.(domain).(section).trials = [dataMat.(domain).(section).trials; prior.trials(:)];
        end
        domainEvents = recovery.events; parentAttempt = recovery.parentAttemptId;
        if ~isempty(recovery.entryState)
            rs.State = recovery.entryState.rsState; rng(recovery.entryState.globalState);
        end
        for b = recovery.nextBlock:numel(chunks)
            chunk = chunks(b); section = chunk.section;
            if strcmp(domain, 'houses') && (b == recovery.nextBlock || ~strcmp(chunks(b-1).section, section))
                if strcmp(section, 'rating')
                    showMessage(window, cfg, ['House photo ratings\n\nYou will see one house photo at a time.\n\n' ...
                        'Use the line to show how much you like the style of the house in the photo.\n\nClick to begin.']);
                else
                    showMessage(window, cfg, ['House photo choices\n\nYou will see two photos of the same room or area at a time\n' ...
                        '(kitchen with kitchen, bathroom with bathroom, and so on).\n\n' ...
                        'Press Z to choose the left photo, or M to choose the right photo.\n\nClick to begin.']);
                end
            end
            entryState = struct('rsState', rs.State, 'globalState', rng);
            attempt = utils.taskBlock('begin', sess, run, domain, b, entryState, parentAttempt);
            log = utils.eventLog('init');
            log = utils.eventLog('context', log, struct('block', b, 'attemptId', attempt.attemptId, 'section', section));
            recording = utils.blockRecording('start', et);
            gazeStore = recording.store;
            blockInfo = struct('run', run, 'block', b, 'nBlocks', numel(chunks));
            if strcmp(section, 'rating')
                [blockTrials, log, gazeStore] = runRatingTrials(window, cfg, plan, tex, ...
                    et, log, gazeStore, rs, FIX_SEC, ISI_RANGE_SEC, chunk.indices, blockInfo);
            else
                [blockTrials, log, gazeStore] = runPwcTrials(window, cfg, plan, tex, domain, ...
                    et, log, gazeStore, rs, FIX_SEC, ISI_RANGE_SEC, chunk.indices, blockInfo);
            end
            log = utils.eventLog('add', log, 'recording_stop', GetSecs, struct('trial', 0));
            blockData = struct(); blockData.(domain).(section).trials = blockTrials;
            payload = struct('trials', blockTrials, 'trialTable', buildTrialTable(blockData), ...
                'events', utils.eventLog('table', log), 'clockSync', recording.clockSync);
            payload.trialTable.globalTrial = chunk.globalIndices(:);
            payload.metadata = struct('frozenPlan', frozen, 'section', section, 'layout', G, 'eyeTracking', dataMat.eyeTracking);
            payload.nextState = struct('rsState', rs.State, 'globalState', rng);
            utils.savingScreen(window, cfg, 0.1, 'Saving completed block', utils.didYouKnow(run.seed));
            receipt = utils.taskBlock('finish', sess, run, domain, attempt, payload, et, gazeStore);
            parentAttempt = receipt.attemptId; domainEvents{end+1} = payload.events;
            dataMat.(domain).(section).trials = [dataMat.(domain).(section).trials; blockTrials(:)];
            clear gazeStore recording payload blockTrials;
        end
        dataMat.(domain).events = utils.stackTables(domainEvents);
        dataMat.(domain).checkpointRun = [run.runId '_' domain];
        releaseTextures(tex);
    end

    utils.progressLog(run, 'BEGIN end-of-task message');
    showMessage(window, cfg, 'This task is finished.\n\nThank you.\n\nClick to continue.', 60);
    utils.progressLog(run, 'END end-of-task message');
    tl = utils.timeline('stop', tl);
    dataMat.timing = utils.timeline('table', tl);
    utils.progressLog(run, 'BEGIN trial table construction');
    trialTable = buildTrialTable(dataMat);
    utils.progressLog(run, 'END trial table construction rows=%d', height(trialTable));
    try
        utils.saveRun(sess, run, dataMat, trialTable);
    catch summaryError
        utils.progressLog(run, 'Optional summary save failed: %s; block receipts remain authoritative', summaryError.message);
    end
    utils.progressLog(run, 'END behavioral saves');
    utils.progressLog(run, 'BEGIN display cleanup');
    % Match auction_task:476 and continuous_DC_task:434. This path was the odd
    % one out at Screen('CloseAll') alone, and both omissions bite the NEXT
    % module, not this one:
    %   ListenChar(0) -- without it the keyboard stays captured after this task
    %     returns, so MATLAB's Command Window silently ignores typing. A battery
    %     waiting at run_battery:144's "continue anyway? (y/n)" then looks hung,
    %     which is why operators have been force-quitting MATLAB.
    %   clear PsychImaging -- sca resets Screen state but not PsychImaging's
    %     persistent config, so the next task's OpenWindow can return a handle
    %     that looks valid and is not, surfacing as a generic Screen "Usage:"
    %     error on its first real draw rather than at OpenWindow. README.md
    %     "Known gotchas" documents this and says both task files were fixed --
    %     this third one was missed.
    ListenChar(0); ShowCursor; Priority(0); sca; clear PsychImaging;
    utils.progressLog(run, 'END display cleanup; task returning');
    if standalone, utils.endRun(sess, run, 'complete'); end

catch ME
    utils.preserveGazeFailure(sess, run, et);
    utils.progressLog(run, 'TASK ERROR before cleanup\n%s', getReport(ME, 'extended', 'hyperlinks', 'off'));
    try
        tl = utils.timeline('stop', tl);
        dataMat.timing = utils.timeline('table', tl);
        dataMat.error = getReport(ME, 'extended', 'hyperlinks', 'off'); %#ok<NASGU>
        save([run.fileStem '_' utils.checkpointIO('id') '_crash.mat'], 'dataMat', 'ME', '-v7.3');
        if standalone, utils.endRun(sess, run, 'crashed'); end
    catch
    end
    if et.enabled && ~isempty(et.obj)
        try, et.obj.stop_gaze_data(); catch, end
    end
    sca;
    clear PsychImaging;
    rethrow(ME);
end
end


function sess = bootstrapStandaloneSession()
% Checkout-local standalone run: dev rig, no eye tracking, local paths.
RIG = 'dev';
TESTING = true;
EYETRACKING = false;
PARTICIPANT = 9999;
SESSION = 1;
DOMAIN = 'houses';         % 'houses' | 'jobs' for a standalone run

here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
addpath(here);

bootstrapRoot = fullfile(tempdir, 'housing_photo_pref_bootstrap', utils.checkpointIO('id'));
sess = utils.startSession( ...
    'participant', PARTICIPANT, ...
    'session', SESSION, ...
    'domain', 2, ...
    'testing', TESTING, ...
    'projRoot', bootstrapRoot, ...
    'localDataRoot', fullfile(bootstrapRoot,'data'), ...
    'rig', RIG, ...
    'eyeTracking', EYETRACKING);
cfg = sess.cfg;
cfg.paths.experiment = here;
cfg.paths.stimuli = fullfile(here, 'stimuli');
cfg.paths.prepared = fullfile(cfg.paths.stimuli, 'prepared');
cfg.paths.images = fullfile(cfg.paths.stimuli, 'house_images');
cfg.stimFiles.houses = fullfile(cfg.paths.stimuli, 'house_stimuli.csv');
sess.cfg = cfg;
sess.domains = {DOMAIN};
sess.domainOrderStr = DOMAIN;
end


function sections = resolveSections(taskMode, orderMode, participant)
switch lower(char(taskMode))
    case 'rating'
        sections = {'rating'};
    case 'pwc'
        sections = {'pwc'};
    case 'both'
        switch lower(char(orderMode))
            case 'counterbalanced'
                if mod(participant, 2) == 0
                    sections = {'rating','pwc'};
                else
                    sections = {'pwc','rating'};
                end
            case 'rating_first'
                sections = {'rating','pwc'};
            case 'pwc_first'
                sections = {'pwc','rating'};
            otherwise
                error('hw:pref:badOrder', 'Unknown SECTION_ORDER "%s".', orderMode);
        end
    otherwise
        error('hw:pref:badMode', 'Unknown TASK_MODE "%s".', taskMode);
end
end


function txt = introText(sections)
if numel(sections) == 1 && strcmp(sections{1}, 'rating')
    txt = ['House photo style ratings\n\nThis is a short task ' ...
           'about how much you like different house styles.\n\nClick to continue.'];
elseif numel(sections) == 1 && strcmp(sections{1}, 'pwc')
    txt = ['House photo style choices\n\nThis is a short task ' ...
           'about which house styles you prefer.\n\nClick to continue.'];
else
    txt = ['House photo style task\n\nThis task has two short sections: ' ...
           'one with single-photo ratings and one with two-photo choices.\n\nClick to continue.'];
end
end


function tex = loadPhotoTextures(window, cfg, photoTable, photoRows)
tex = nan(height(photoTable), 1);
photoRows = unique(photoRows(:))';
for k = 1:numel(photoRows)
    r = photoRows(k);
    p = fullfile(cfg.paths.images, char(photoTable.imageFile(r)));
    if ~exist(p, 'file')
        error('hw:pref:missingImage', 'Missing house photo: %s', p);
    end
    img = imread(p);
    tex(r) = Screen('MakeTexture', window, img);
end
end


function releaseTextures(tex)
if isempty(tex), return; end
handles = tex(isfinite(tex));
for k = 1:numel(handles)
    Screen('Close', handles(k));
end
end


function [tFix, log, gazeStore] = fixationAndIsi(window, cfg, et, log, ...
    gazeStore, rs, fixSec, isiRange, info)
% Blank ISI then fixation, passive and timed, not click-gated; one gaze poll
% per wait loses no samples.
s = cfg.style;
scr = Screen('Rect', window);
cx = scr(3)/2; cy = scr(4)/2;

Screen('FillRect', window, s.bg);
tIsi = Screen('Flip', window);
log = utils.eventLog('add', log, 'isi_on', tIsi, info);
isi = isiRange(1) + diff(isiRange) * rand(rs);
WaitSecs(isi);
gazeStore = utils.gazeBuffer('poll', et, gazeStore);
utils.checkForQuit;

armLen = 18;
Screen('FillRect', window, s.bg);
Screen('DrawLine', window, s.interactive, cx-armLen, cy, cx+armLen, cy, 3);
Screen('DrawLine', window, s.interactive, cx, cy-armLen, cx, cy+armLen, 3);
tFix = Screen('Flip', window);
log = utils.eventLog('add', log, 'fixation_on', tFix, info);
WaitSecs(fixSec);
gazeStore = utils.gazeBuffer('poll', et, gazeStore);
utils.checkForQuit;
end


function [trials, log, gazeStore] = runRatingTrials(window, cfg, plan, tex, ...
    et, log, gazeStore, rs, fixSec, isiRange, indices, blockInfo)
s = cfg.style;
G = prefLayout(window);
H = G.H;
lineY = G.lineY;
lineLeft = G.lineLeft;
lineRight = G.lineRight;
lineLen = lineRight - lineLeft;
imgRect = G.imgRect;
trials = repmat(ratingTrialTemplate(), numel(indices), 1);

for i = 1:numel(indices)
    t = indices(i);
    pr = plan.ratingPhotoRows(t);
    info = struct('trial', t, 'photoRow', pr);
    HideCursor(window);
    [~, log, gazeStore] = fixationAndIsi(window, cfg, et, log, gazeStore, ...
        rs, fixSec, isiRange, info);
    ShowCursor('Arrow', window);
    t0 = NaN;
    while true
        [mx, ~, buttons] = utils.getMouse(window);
        mx = min(max(mx, lineLeft), lineRight);

        Screen('FillRect', window, s.bg);
        Screen('TextFont', window, s.fontContent);
        Screen('TextSize', window, s.sizeHeading);
        DrawFormattedText(window, 'How much do you like the style of this house?', ...
            'center', H*0.06, s.text);
        drawPhoto(window, tex(pr), imgRect);

        Screen('DrawLine', window, s.track, lineLeft, lineY, lineRight, lineY, 4);
        Screen('DrawLine', window, s.track, lineLeft, lineY-16, lineLeft, lineY+16, 4);
        Screen('DrawLine', window, s.track, lineRight, lineY-16, lineRight, lineY+16, 4);
        Screen('TextSize', window, s.sizeLabel);
        DrawFormattedText(window, 'Not at all', lineLeft - 30, lineY + 46, s.textDim);
        b = Screen('TextBounds', window, 'Very much');
        DrawFormattedText(window, 'Very much', lineRight - b(3) + 30, lineY + 46, s.textDim);
        Screen('DrawLine', window, s.interactive, mx, lineY-24, mx, lineY+24, 5);
        drawProgress(window, cfg, t, numel(plan.ratingPhotoRows));
        vbl = Screen('Flip', window);
        if isnan(t0)
            t0 = vbl;
            log = utils.eventLog('add', log, 'rating_stim_on', vbl, info);
        end
        utils.checkForQuit;
        gazeStore = utils.gazeBuffer('poll', et, gazeStore);

        if buttons(1)
            log = utils.eventLog('add', log, 'rating_response', GetSecs, info);
            while any(buttons), [~,~,buttons] = utils.getMouse(window); end
            break
        end
    end

    trials(i).section = 'rating';
    trials(i).trial = t;
    trials(i).photoRow = pr;
    trials(i).photoId = char(plan.photoTable.photoId(pr));
    trials(i).houseIdx = plan.photoTable.houseIdx(pr);
    trials(i).areaVar = char(plan.photoTable.areaVar(pr));
    trials(i).imageFile = char(plan.photoTable.imageFile(pr));
    trials(i).rating = (mx - lineLeft) / lineLen;
    trials(i).rt = GetSecs - t0;

    utils.progressLog(blockInfo.run, ['TRIAL section=rating block=%d/%d ' ...
        'trial=%d/%d photo=%s rating=%.3f rt=%.3f'], ...
        blockInfo.block, blockInfo.nBlocks, i, numel(indices), ...
        trials(i).photoId, trials(i).rating, trials(i).rt);
end
end


function [trials, log, gazeStore] = runPwcTrials(window, cfg, plan, tex, ...
    domain, et, log, gazeStore, rs, fixSec, isiRange, indices, blockInfo)
s = cfg.style;
G = prefLayout(window);
H = G.H;
leftRect = G.leftRect;
rightRect = G.rightRect;
leftKey = KbName('z');
rightKey = KbName('m');
% Key responses; hide the cursor for the section. showMessage re-shows.
HideCursor(window);
trials = repmat(pwcTrialTemplate(), numel(indices), 1);

for i = 1:numel(indices)
    t = indices(i);
    leftRow = plan.pwcPairs(t,1);
    rightRow = plan.pwcPairs(t,2);
    info = struct('trial', t, 'leftRow', leftRow, 'rightRow', rightRow);
    switch domain
        case 'houses'
            prompt = sprintf('Which %s do you prefer?', ...
                lower(char(plan.photoTable.areaLabel(leftRow))));
        case 'jobs'
            prompt = 'Which job would you rather have?';
    end

    [~, log, gazeStore] = fixationAndIsi(window, cfg, et, log, gazeStore, ...
        rs, fixSec, isiRange, info);
    t0 = NaN;
    choice = '';
    KbReleaseWait;
    while isempty(choice)
        Screen('FillRect', window, s.bg);
        Screen('TextFont', window, s.fontContent);
        Screen('TextSize', window, s.sizeHeading);
        DrawFormattedText(window, prompt, 'center', H*0.08, s.text);
        switch domain
            case 'houses'
                drawPhoto(window, tex(leftRow), leftRect);
                drawPhoto(window, tex(rightRow), rightRect);
            case 'jobs'
                drawJobCard(window, cfg, plan.jobTable, leftRow, leftRect);
                drawJobCard(window, cfg, plan.jobTable, rightRow, rightRect);
        end
        Screen('TextSize', window, s.sizeLabel);
        DrawFormattedText(window, 'Z', mean(leftRect([1 3])) - 8, H*0.75, s.textDim);
        DrawFormattedText(window, 'M', mean(rightRect([1 3])) - 10, H*0.75, s.textDim);
        drawProgress(window, cfg, t, size(plan.pwcPairs, 1));
        vbl = Screen('Flip', window);
        if isnan(t0)
            t0 = vbl;
            log = utils.eventLog('add', log, 'pwc_stim_on', vbl, info);
        end
        utils.checkForQuit;
        gazeStore = utils.gazeBuffer('poll', et, gazeStore);

        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(leftKey)
                choice = 'left';
            elseif keyCode(rightKey)
                choice = 'right';
            end
        end
    end
    log = utils.eventLog('add', log, 'pwc_response', GetSecs, info);

    chosenRow = leftRow;
    unchosenRow = rightRow;
    if strcmp(choice, 'right')
        chosenRow = rightRow;
        unchosenRow = leftRow;
    end

    trials(i).section = 'pwc';
    trials(i).trial = t;
    trials(i).responseSide = choice;
    trials(i).rt = GetSecs - t0;
    switch domain
        case 'houses'
            trials(i).leftPhotoId = char(plan.photoTable.photoId(leftRow));
            trials(i).rightPhotoId = char(plan.photoTable.photoId(rightRow));
            trials(i).chosenPhotoId = char(plan.photoTable.photoId(chosenRow));
            trials(i).unchosenPhotoId = char(plan.photoTable.photoId(unchosenRow));
            trials(i).leftPhotoRow = leftRow;
            trials(i).rightPhotoRow = rightRow;
            trials(i).chosenPhotoRow = chosenRow;
            trials(i).unchosenPhotoRow = unchosenRow;
            trials(i).leftAreaVar = char(plan.photoTable.areaVar(leftRow));
            trials(i).rightAreaVar = char(plan.photoTable.areaVar(rightRow));
            trials(i).leftImageFile = char(plan.photoTable.imageFile(leftRow));
            trials(i).rightImageFile = char(plan.photoTable.imageFile(rightRow));
        case 'jobs'
            trials(i).leftJobIdx = leftRow;
            trials(i).rightJobIdx = rightRow;
            trials(i).chosenJobIdx = chosenRow;
            trials(i).unchosenJobIdx = unchosenRow;
            trials(i).leftIndustry = char(plan.jobTable.industry(leftRow));
            trials(i).rightIndustry = char(plan.jobTable.industry(rightRow));
            trials(i).leftTitle = char(plan.jobTable.title(leftRow));
            trials(i).rightTitle = char(plan.jobTable.title(rightRow));
            trials(i).chosenTitle = char(plan.jobTable.title(chosenRow));
    end

    % Only domain-independent fields: the switch above names entirely
    % different photo/job fields per domain.
    utils.progressLog(blockInfo.run, ['TRIAL section=pwc block=%d/%d ' ...
        'trial=%d/%d domain=%s side=%s rt=%.3f'], ...
        blockInfo.block, blockInfo.nBlocks, i, numel(indices), ...
        domain, trials(i).responseSide, trials(i).rt);
end
ShowCursor('Arrow', window);
end


function G = prefLayout(window)
% Single source of screen geometry, saved as dataMat.(domain).layout for gaze
% mapping -- AOI geometry must never exist in two copies.
scr = Screen('Rect', window);
G.W = scr(3); G.H = scr(4);
G.imgRect   = [G.W*0.25, G.H*0.13, G.W*0.75, G.H*0.66];
G.leftRect  = [G.W*0.08, G.H*0.20, G.W*0.47, G.H*0.72];
G.rightRect = [G.W*0.53, G.H*0.20, G.W*0.92, G.H*0.72];
G.fixPoint  = [G.W/2, G.H/2];
G.lineY     = G.H*0.82;
G.lineLeft  = G.W*0.18;
G.lineRight = G.W*0.82;
end


function drawJobCard(window, cfg, jobTable, row, rect)
s = cfg.style;
utils.roundRect(window, rect, s.radiusPanel, s.bgPanel, s.border, s.hairlinePx);
cx = mean(rect([1 3]));
industry = char(jobTable.industry(row));
title = char(jobTable.title(row));

Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeLabel);
b = Screen('TextBounds', window, industry);
DrawFormattedText(window, industry, cx - b(3)/2, rect(2) + (rect(4)-rect(2))*0.32, s.textDim);

Screen('TextSize', window, s.sizeTitle);
DrawFormattedText(window, title, 'center', 'center', s.text, ...
    24, 0, 0, 1.3, 0, rect);
end


function drawPhoto(window, tex, box)
% Center-crop to the box aspect so every photo fills the identical rect.
src = Screen('Rect', tex);
Screen('DrawTexture', window, tex, cropSrcRect(src, box), box);
end


function srcRect = cropSrcRect(src, box)
sw = src(3) - src(1);
sh = src(4) - src(2);
boxAspect = (box(3) - box(1)) / (box(4) - box(2));
if sw / sh > boxAspect
    w = sh * boxAspect; h = sh;
else
    w = sw; h = sw / boxAspect;
end
cx = mean(src([1 3]));
cy = mean(src([2 4]));
srcRect = [cx-w/2, cy-h/2, cx+w/2, cy+h/2];
end


function drawProgress(window, cfg, t, n)
s = cfg.style;
scr = Screen('Rect', window);
Screen('TextSize', window, s.sizeLabel);
DrawFormattedText(window, sprintf('%d / %d', t, n), scr(3) - 130, scr(4) - 54, s.textDim);
DrawFormattedText(window, 'Press Q to stop', 42, scr(4) - 54, s.textDim);
end


function showMessage(window, cfg, msg, maxSecs)
% maxSecs is a safety net, not a design choice. Default Inf leaves the five
% instruction screens click-gated exactly as before; only the end-of-task
% screen passes a finite value. On 2026-10-09 a participant sat on that screen
% indefinitely: its text was the one showMessage call in this file that did not
% end in "Click to continue", so nothing on screen said an action was needed,
% and the operator read a waiting task as a hung one.
if nargin < 4 || isempty(maxSecs), maxSecs = Inf; end
s = cfg.style;
ShowCursor('Arrow', window);
t0 = GetSecs;
while true
    [~, ~, buttons] = utils.getMouse(window);
    Screen('FillRect', window, s.bg);
    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeHeading);
    DrawFormattedText(window, msg, 'center', 'center', s.text, 78, 0, 0, 1.4);
    Screen('Flip', window);
    utils.checkForQuit;
    if buttons(1)
        while any(buttons), [~,~,buttons] = utils.getMouse(window); end
        break
    end
    if GetSecs - t0 >= maxSecs, break; end
end
end


function tr = ratingTrialTemplate()
tr = struct('section', '', 'trial', NaN, 'photoRow', NaN, ...
    'photoId', '', 'houseIdx', NaN, 'areaVar', '', 'imageFile', '', ...
    'rating', NaN, 'rt', NaN);
end


function tr = pwcTrialTemplate()
tr = struct('section', '', 'trial', NaN, ...
    'responseSide', '', 'rt', NaN, ...
    'leftPhotoId', '', 'rightPhotoId', '', ...
    'chosenPhotoId', '', 'unchosenPhotoId', '', ...
    'leftPhotoRow', NaN, 'rightPhotoRow', NaN, ...
    'chosenPhotoRow', NaN, 'unchosenPhotoRow', NaN, ...
    'leftAreaVar', '', 'rightAreaVar', '', ...
    'leftImageFile', '', 'rightImageFile', '', ...
    'leftJobIdx', NaN, 'rightJobIdx', NaN, ...
    'chosenJobIdx', NaN, 'unchosenJobIdx', NaN, ...
    'leftIndustry', '', 'rightIndustry', '', ...
    'leftTitle', '', 'rightTitle', '', 'chosenTitle', '');
end


function T = buildTrialTable(dataMat)
rows = {};
for dom = {'houses','jobs'}
    domain = dom{1};
    if ~isfield(dataMat, domain), continue; end
    D = dataMat.(domain);
    % string() everywhere so each column holds one type; mixed cells break cell2table.
    if isfield(D, 'rating') && ~isempty(D.rating.trials)
        R = D.rating.trials;
        for t = 1:numel(R)
            rows{end+1} = {string(domain), string(R(t).section), R(t).trial, ...
                string(R(t).photoId), R(t).houseIdx, string(R(t).areaVar), ...
                string(R(t).imageFile), R(t).rating, R(t).rt, ...
                "", "", "", "", NaN, NaN, NaN, NaN, "", "", "", ...
                "", "", "", "", ""}; %#ok<AGROW>
        end
    end
    if isfield(D, 'pwc') && ~isempty(D.pwc.trials)
        P = D.pwc.trials;
        for t = 1:numel(P)
            rows{end+1} = {string(domain), string(P(t).section), P(t).trial, ...
                "", NaN, "", "", NaN, P(t).rt, ...
                string(P(t).leftPhotoId), string(P(t).rightPhotoId), ...
                string(P(t).chosenPhotoId), string(P(t).unchosenPhotoId), ...
                P(t).leftPhotoRow, P(t).rightPhotoRow, P(t).chosenPhotoRow, P(t).unchosenPhotoRow, ...
                string(P(t).responseSide), string(P(t).leftAreaVar), string(P(t).rightAreaVar), ...
                string(P(t).leftIndustry), string(P(t).leftTitle), string(P(t).rightIndustry), ...
                string(P(t).rightTitle), string(P(t).chosenTitle)}; %#ok<AGROW>
        end
    end
end

if isempty(rows)
    T = table();
else
    T = cell2table(vertcat(rows{:}), 'VariableNames', {'domain','section','trial', ...
        'photoId','houseIdx','areaVar','imageFile','rating','rt', ...
        'leftPhotoId','rightPhotoId','chosenPhotoId','unchosenPhotoId', ...
        'leftPhotoRow','rightPhotoRow','chosenPhotoRow','unchosenPhotoRow', ...
        'responseSide','leftAreaVar','rightAreaVar', ...
        'leftIndustry','leftTitle','rightIndustry','rightTitle','chosenTitle'});
end
end
