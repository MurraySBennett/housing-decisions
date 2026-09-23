function dataMat = preference_task(sess, run)
%PREFERENCE_TASK  Style/category preference task, per domain.
%
%   dataMat = preference_task(sess, run)
%
%   Houses: direct ratings of individual house photos plus pairwise
%   choices between photos of the SAME area (kitchen vs kitchen, ...).
%   Jobs: pairwise choices between jobs shown as industry + job title
%   only, mixed freely across industries. Jobs always reads the
%   ECOLOGICAL stimulus file regardless of the session's JOBS_ARM -- the
%   synthetic arm's titles are placeholders (title_001) and must never
%   reach a screen.
%
%   Battery-driven via run_battery ('pref' rows); called with no
%   arguments it bootstraps its own session and runs standalone.
%
%   Pairwise responses are the Z (left) / M (right) keys. Every trial is
%   preceded by a blank ISI and a brief centered fixation cue, and gaze
%   is recorded when the session has eye tracking on.

%% ---- Task constants ---------------------------------------------------
TASK_MODE = 'both';        % houses only: 'rating' | 'pwc' | 'both'
N_RATING = 80;             % houses: number of direct photo ratings
N_PWC_HOUSES = 160;        % houses: within-area pairwise comparisons
N_PWC_JOBS = 160;          % jobs: cross-industry pairwise comparisons
SECTION_ORDER = 'counterbalanced';  % houses, TASK_MODE='both'
FIX_SEC = 0.5;             % centered fixation cue before every trial
ISI_RANGE_SEC = [0.4 0.7]; % blank inter-trial interval, uniform jitter

% Editable area quotas (houses). Defaults sum to 80.
AREA_QUOTAS = struct( ...
    'extPic',  14, ...
    'kitPic',  14, ...
    'bedPic',  13, ...
    'bathPic', 13, ...
    'livPic',  13, ...
    'outPic',  13);

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
        'actualSampleRateHz', et.actualSampleRateHz);

    G = prefLayout(window);

    for d = 1:numel(domainList)
        domain = lower(domainList{d});
        tl = utils.timeline('section', tl, sprintf('%s:load', domain));
        log = utils.eventLog('init');
        gazeStore = utils.gazeBuffer('init');
        clockSync = struct();
        clockSync.start = utils.clockSync(et);

        switch domain
            case 'houses'
                stimTbl = utils.readStimuli(cfg, 'houses');
                plan = utils.buildPhotoPreferencePlan(stimTbl, N_RATING, ...
                    N_PWC_HOUSES, AREA_QUOTAS, rs);
                if ~exist(cfg.paths.images, 'dir')
                    error('hw:pref:noImages', ...
                        'House image directory not found: %s', cfg.paths.images);
                end
                tex = loadPhotoTextures(window, cfg, plan.photoTable, ...
                    unique([plan.ratingPhotoRows; plan.pwcPairs(:)]));

                sections = resolveSections(TASK_MODE, SECTION_ORDER, sess.participant);
                dataMat.houses.sectionOrder = sections;
                dataMat.houses.photoTable = plan.photoTable;
                dataMat.houses.areaQuotas = plan.areaQuotas;
                dataMat.houses.pwcPairsPerArea = plan.pwcPairsPerArea;
                dataMat.houses.rating = struct('trials', []);
                dataMat.houses.pwc = struct('trials', []);
                dataMat.houses.layout = G;
                tl = utils.timeline('section', tl, 'houses:instructions');
                showMessage(window, cfg, introText(sections));

                for k = 1:numel(sections)
                    switch sections{k}
                        case 'rating'
                            showMessage(window, cfg, ['House photo ratings\n\n' ...
                                'You will see one house photo at a time.\n\n' ...
                                'Use the line to show how much you like the style of the house in the photo.\n\n' ...
                                'Click to begin.']);
                            tl = utils.timeline('section', tl, 'houses:rating');
                            [dataMat.houses.rating.trials, log, gazeStore] = ...
                                runRatingTrials(window, cfg, plan, tex, et, log, ...
                                gazeStore, rs, FIX_SEC, ISI_RANGE_SEC);
                        case 'pwc'
                            showMessage(window, cfg, ['House photo choices\n\n' ...
                                'You will see two photos of the same room or area at a time\n' ...
                                '(kitchen with kitchen, bathroom with bathroom, and so on).\n\n' ...
                                'Press Z to choose the left photo, or M to choose the right photo.\n\n' ...
                                'Click to begin.']);
                            tl = utils.timeline('section', tl, 'houses:pwc');
                            [dataMat.houses.pwc.trials, log, gazeStore] = ...
                                runPwcTrials(window, cfg, plan, tex, 'houses', et, ...
                                log, gazeStore, rs, FIX_SEC, ISI_RANGE_SEC);
                    end
                    if k < numel(sections)
                        showMessage(window, cfg, ...
                            'That section is finished.\n\nClick for the next section.');
                    end
                end
                releaseTextures(tex);

            case 'jobs'
                prefCfg = cfg;
                prefCfg.stimFiles.jobs = fullfile(cfg.paths.prepared, ...
                    'job_stimuli_ecological.csv');
                stimTbl = utils.readStimuli(prefCfg, 'jobs');
                plan = utils.buildJobPreferencePlan(stimTbl, N_PWC_JOBS, rs);
                dataMat.jobs.jobTable = plan.jobTable;
                dataMat.jobs.pwc = struct('trials', []);
                dataMat.jobs.layout = G;

                tl = utils.timeline('section', tl, 'jobs:instructions');
                showMessage(window, cfg, ['Job choices\n\n' ...
                    'You will see two jobs at a time, showing only the industry ' ...
                    'and the job title.\n\n' ...
                    'Press Z to choose the left job, or M to choose the right job.\n\n' ...
                    'Click to begin.']);
                tl = utils.timeline('section', tl, 'jobs:pwc');
                [dataMat.jobs.pwc.trials, log, gazeStore] = ...
                    runPwcTrials(window, cfg, plan, [], 'jobs', et, log, ...
                    gazeStore, rs, FIX_SEC, ISI_RANGE_SEC);

            otherwise
                error('hw:pref:badDomain', 'Unknown domain "%s".', domain);
        end

        tl = utils.timeline('section', tl, sprintf('%s:saving', domain));
        dataMat.(domain).events = utils.eventLog('table', log);
        clockSync.end = utils.clockSync(et);
        gaze = utils.gazeBuffer('flush', et, gazeStore);
        if ~isempty(gaze)
            gf = strrep(run.gazeFile, '_gaze.mat', sprintf('_%s_gaze.mat', domain));
            eyeTracking = dataMat.eyeTracking; %#ok<NASGU>
            save(gf, 'gaze', 'clockSync', 'eyeTracking', '-v7.3');
            dataMat.(domain).gazeFile = gf;
            fprintf('Saved %d gaze samples.\n', numel(gaze));
        end
        dataMat.(domain).clockSync = clockSync;
        % The buffer was flushed and recording stopped for this domain's
        % file; a fresh store (and start) begins with the next domain.
        if d < numel(domainList) && et.enabled && ~isempty(et.obj)
            try, et.obj.get_gaze_data(); catch, end
        end
    end

    showMessage(window, cfg, 'This task is finished.\n\nThank you.');
    tl = utils.timeline('stop', tl);
    dataMat.timing = utils.timeline('table', tl);
    utils.saveRun(sess, run, dataMat, buildTrialTable(dataMat));
    Screen('CloseAll');
    if standalone, utils.endRun(sess, run, 'complete'); end

catch ME
    try
        tl = utils.timeline('stop', tl);
        dataMat.timing = utils.timeline('table', tl);
        dataMat.error = getReport(ME, 'extended', 'hyperlinks', 'off'); %#ok<NASGU>
        save([run.fileStem '_crash.mat'], 'dataMat', 'ME', '-v7.3');
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


%% =====================================================================
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

bootstrapRoot = fullfile(tempdir, 'housing_photo_pref_bootstrap');
sess = utils.startSession( ...
    'participant', PARTICIPANT, ...
    'session', SESSION, ...
    'domain', 2, ...
    'testing', TESTING, ...
    'projRoot', bootstrapRoot, ...
    'rig', RIG, ...
    'eyeTracking', EYETRACKING);
cfg = sess.cfg;
strayManifest = sess.manifestFile;

cfg.paths.experiment = here;
cfg.paths.stimuli    = fullfile(here, 'stimuli');
cfg.paths.prepared   = fullfile(cfg.paths.stimuli, 'prepared');
cfg.paths.images     = fullfile(cfg.paths.stimuli, 'house_images');
cfg.stimFiles.houses = fullfile(cfg.paths.stimuli, 'house_stimuli.csv');
cfg.paths.data       = fullfile(here, 'Data');
cfg.paths.sessions   = fullfile(cfg.paths.data, 'sessions');
cfg.paths.taskData.pref = fullfile(cfg.paths.data, 'pref');
cfg.paths.gaze       = fullfile(cfg.paths.data, 'gaze');
cfg.paths.crashed    = fullfile(cfg.paths.data, 'Crashes');
dirs = {cfg.paths.sessions, cfg.paths.taskData.pref, cfg.paths.gaze, cfg.paths.crashed};
for k = 1:numel(dirs)
    if ~exist(dirs{k}, 'dir'), mkdir(dirs{k}); end
end
sess.cfg = cfg;
sess.domains = {DOMAIN};
sess.domainOrderStr = DOMAIN;
sess.manifestFile = fullfile(cfg.paths.sessions, ...
    sprintf('sub-%05d_manifest.mat', sess.participant));
if ~strcmp(strayManifest, sess.manifestFile) && exist(strayManifest, 'file')
    delete(strayManifest);
end
if ~exist(sess.manifestFile, 'file')
    manifest = struct('participant', sess.participant, ...
        'createdAt', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
        'runs', struct('task',{},'sessionNum',{},'runId',{},'domainOrderStr',{}, ...
                       'startedAt',{},'finishedAt',{},'status',{},'dataFile',{}, ...
                       'seed',{},'codeVersion',{}));
    save(sess.manifestFile, 'manifest');
end
end


%% =====================================================================
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


%% =====================================================================
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


%% =====================================================================
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


%% =====================================================================
function releaseTextures(tex)
if isempty(tex), return; end
handles = tex(isfinite(tex));
for k = 1:numel(handles)
    Screen('Close', handles(k));
end
end


%% =====================================================================
function [tFix, log, gazeStore] = fixationAndIsi(window, cfg, et, log, ...
    gazeStore, rs, fixSec, isiRange, info)
% Blank ISI (uniform jitter), then a brief centered fixation cross.
% Passive and timed, not click-gated: with 160 fast key trials a
% click-to-start gate would dominate the task's duration. Tobii buffers
% between polls, so one poll after each wait loses no samples.
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


%% =====================================================================
function [trials, log, gazeStore] = runRatingTrials(window, cfg, plan, tex, ...
    et, log, gazeStore, rs, fixSec, isiRange)
s = cfg.style;
G = prefLayout(window);
H = G.H;
lineY = G.lineY;
lineLeft = G.lineLeft;
lineRight = G.lineRight;
lineLen = lineRight - lineLeft;
imgRect = G.imgRect;
trials = repmat(ratingTrialTemplate(), numel(plan.ratingPhotoRows), 1);

for t = 1:numel(plan.ratingPhotoRows)
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

    trials(t).section = 'rating';
    trials(t).trial = t;
    trials(t).photoRow = pr;
    trials(t).photoId = char(plan.photoTable.photoId(pr));
    trials(t).houseIdx = plan.photoTable.houseIdx(pr);
    trials(t).areaVar = char(plan.photoTable.areaVar(pr));
    trials(t).imageFile = char(plan.photoTable.imageFile(pr));
    trials(t).rating = (mx - lineLeft) / lineLen;
    trials(t).rt = GetSecs - t0;
end
end


%% =====================================================================
function [trials, log, gazeStore] = runPwcTrials(window, cfg, plan, tex, ...
    domain, et, log, gazeStore, rs, fixSec, isiRange)
s = cfg.style;
G = prefLayout(window);
H = G.H;
leftRect = G.leftRect;
rightRect = G.rightRect;
leftKey = KbName('z');
rightKey = KbName('m');
% Responses are keys, so a cursor parked over one option would be the only
% mouse trace on screen -- hide it for the section. showMessage re-shows.
HideCursor(window);
trials = repmat(pwcTrialTemplate(), size(plan.pwcPairs, 1), 1);

for t = 1:size(plan.pwcPairs, 1)
    leftRow = plan.pwcPairs(t,1);
    rightRow = plan.pwcPairs(t,2);
    info = struct('trial', t, 'leftRow', leftRow, 'rightRow', rightRow);
    switch domain
        case 'houses'
            % Within-area by construction; the prompt names the area.
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

    trials(t).section = 'pwc';
    trials(t).trial = t;
    trials(t).responseSide = choice;
    trials(t).rt = GetSecs - t0;
    switch domain
        case 'houses'
            trials(t).leftPhotoId = char(plan.photoTable.photoId(leftRow));
            trials(t).rightPhotoId = char(plan.photoTable.photoId(rightRow));
            trials(t).chosenPhotoId = char(plan.photoTable.photoId(chosenRow));
            trials(t).unchosenPhotoId = char(plan.photoTable.photoId(unchosenRow));
            trials(t).leftPhotoRow = leftRow;
            trials(t).rightPhotoRow = rightRow;
            trials(t).chosenPhotoRow = chosenRow;
            trials(t).unchosenPhotoRow = unchosenRow;
            trials(t).leftAreaVar = char(plan.photoTable.areaVar(leftRow));
            trials(t).rightAreaVar = char(plan.photoTable.areaVar(rightRow));
            trials(t).leftImageFile = char(plan.photoTable.imageFile(leftRow));
            trials(t).rightImageFile = char(plan.photoTable.imageFile(rightRow));
        case 'jobs'
            trials(t).leftJobIdx = leftRow;
            trials(t).rightJobIdx = rightRow;
            trials(t).chosenJobIdx = chosenRow;
            trials(t).unchosenJobIdx = unchosenRow;
            trials(t).leftIndustry = char(plan.jobTable.industry(leftRow));
            trials(t).rightIndustry = char(plan.jobTable.industry(rightRow));
            trials(t).leftTitle = char(plan.jobTable.title(leftRow));
            trials(t).rightTitle = char(plan.jobTable.title(rightRow));
            trials(t).chosenTitle = char(plan.jobTable.title(chosenRow));
    end
end
ShowCursor('Arrow', window);
end


%% =====================================================================
function G = prefLayout(window)
% Single source of the task's screen geometry. Stored per domain as
% dataMat.(domain).layout so gaze can be mapped onto rects later --
% AOI geometry must never exist in two copies.
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


%% =====================================================================
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


%% =====================================================================
function drawPhoto(window, tex, box)
% Center-crop the source to the box's aspect ratio so every photo fills
% the identical on-screen rect -- displayed size never varies by photo.
src = Screen('Rect', tex);
Screen('DrawTexture', window, tex, cropSrcRect(src, box), box);
end


%% =====================================================================
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


%% =====================================================================
function drawProgress(window, cfg, t, n)
s = cfg.style;
scr = Screen('Rect', window);
Screen('TextSize', window, s.sizeLabel);
DrawFormattedText(window, sprintf('%d / %d', t, n), scr(3) - 130, scr(4) - 54, s.textDim);
DrawFormattedText(window, 'Press Q to stop', 42, scr(4) - 54, s.textDim);
end


%% =====================================================================
function showMessage(window, cfg, msg)
s = cfg.style;
ShowCursor('Arrow', window);
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
end
end


%% =====================================================================
function tr = ratingTrialTemplate()
tr = struct('section', '', 'trial', NaN, 'photoRow', NaN, ...
    'photoId', '', 'houseIdx', NaN, 'areaVar', '', 'imageFile', '', ...
    'rating', NaN, 'rt', NaN);
end


%% =====================================================================
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


%% =====================================================================
function T = buildTrialTable(dataMat)
rows = {};
for dom = {'houses','jobs'}
    domain = dom{1};
    if ~isfield(dataMat, domain), continue; end
    D = dataMat.(domain);
    % Every text cell goes through string() so each column holds ONE type
    % -- a cell column mixing char trials with "" placeholders is exactly
    % what cell2table refuses at the end of a finished session.
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
