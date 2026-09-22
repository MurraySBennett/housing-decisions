%PHOTO_PREFERENCE_TASK  Standalone house-photo style preference task.
%
% Runs independently from auction_task and continuous_DC_task. The stimulus
% unit is one photo from the six house-photo areas, not a full listing.

clear; clc;
KbName('UnifyKeyNames');

%% ---- Task switches ----------------------------------------------------
TASK_MODE = 'both';        % 'rating' | 'pwc' | 'both'
N_RATING = 80;            % number of direct photo ratings
N_PWC = 160;              % number of pairwise comparisons
SECTION_ORDER = 'counterbalanced';  % for TASK_MODE='both'

% Editable area quotas. Defaults sum to 80 and are as balanced as possible.
AREA_QUOTAS = struct( ...
    'extPic',  14, ...
    'kitPic',  14, ...
    'bedPic',  13, ...
    'bathPic', 13, ...
    'livPic',  13, ...
    'outPic',  13);

RIG = 'dev';              % 'dev' | 'lab'
TESTING = true;
EYETRACKING = false;      % not used by this task, but kept explicit
PARTICIPANT = 9999;
SESSION = 1;

%% ---- Session ----------------------------------------------------------
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

% A checkout-local run should use checkout-local stimuli/images when present.
cfg.paths.experiment = here;
cfg.paths.stimuli    = fullfile(here, 'stimuli');
cfg.paths.images     = fullfile(cfg.paths.stimuli, 'house_images');
cfg.stimFiles.houses = fullfile(cfg.paths.stimuli, 'house_stimuli.csv');
cfg.paths.data       = fullfile(here, 'Data');
cfg.paths.sessions   = fullfile(cfg.paths.data, 'sessions');
cfg.paths.taskData.photo_pref = fullfile(cfg.paths.data, 'photo_pref');
cfg.paths.gaze       = fullfile(cfg.paths.data, 'gaze');
cfg.paths.crashed    = fullfile(cfg.paths.data, 'Crashes');
dirs = {cfg.paths.sessions, cfg.paths.taskData.photo_pref, cfg.paths.gaze, cfg.paths.crashed};
for k = 1:numel(dirs)
    if ~exist(dirs{k}, 'dir'), mkdir(dirs{k}); end
end
sess.cfg = cfg;
sess.domains = {'houses'};
sess.domainOrderStr = 'houses';
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

run = utils.beginRun(sess, 'photo_pref', {'houses'});
rs = RandStream('twister', 'Seed', run.seed);

%% ---- Stimuli ----------------------------------------------------------
stimTbl = utils.readStimuli(cfg, 'houses');
plan = utils.buildPhotoPreferencePlan(stimTbl, N_RATING, N_PWC, AREA_QUOTAS, rs);

if ~exist(cfg.paths.images, 'dir')
    error('hw:photoPref:noImages', ...
        'House image directory not found: %s', cfg.paths.images);
end

%% ---- Display ----------------------------------------------------------
AssertOpenGL;
Screen('Preference', 'SkipSyncTests', cfg.display.skipSyncTests);
screens = Screen('Screens');
screenNumber = max(screens);
if cfg.testing.windowed
    [window, winRect] = PsychImaging('OpenWindow', screenNumber, cfg.style.bg, [50 50 1330 770]);
else
    [window, winRect] = PsychImaging('OpenWindow', screenNumber, cfg.style.bg);
end
cfg.style = utils.resolveFonts(window, cfg.style);
sess.cfg = cfg;
s = cfg.style;
ShowCursor('Arrow', window);

dataMat = struct();
dataMat.taskMode = TASK_MODE;
dataMat.sectionOrder = {};
dataMat.photoTable = plan.photoTable;
dataMat.rating = struct('trials', []);
dataMat.pwc = struct('trials', []);
dataMat.areaQuotas = plan.areaQuotas;
dataMat.theme = s.themeName;

try
    tex = loadPhotoTextures(window, cfg, plan.photoTable, unique([plan.ratingPhotoRows; plan.pwcPairs(:)]));

    sections = resolveSections(TASK_MODE, SECTION_ORDER, sess.participant);
    dataMat.sectionOrder = sections;
    showMessage(window, cfg, introText(sections));

    for k = 1:numel(sections)
        switch sections{k}
            case 'rating'
                showMessage(window, cfg, ['House photo ratings\n\n' ...
                    'You will see one house photo at a time.\n\n' ...
                    'Use the line to show how much you like the style of the house in the photo.\n\n' ...
                    'Click to begin.']);
                dataMat.rating.trials = runRatingTrials(window, cfg, plan, tex);
            case 'pwc'
                showMessage(window, cfg, ['House photo choices\n\n' ...
                    'You will see two house photos at a time.\n\n' ...
                    'Click the photo with the house style you prefer.\n\n' ...
                    'Click to begin.']);
                dataMat.pwc.trials = runPwcTrials(window, cfg, plan, tex);
            otherwise
                error('hw:photoPref:badSection', 'Unknown section "%s".', sections{k});
        end
        if k < numel(sections)
            showMessage(window, cfg, 'That section is finished.\n\nClick for the next section.');
        end
    end

    showMessage(window, cfg, 'This task is finished.\n\nThank you.');
    utils.saveRun(sess, run, dataMat, buildTrialTable(dataMat));
    utils.endRun(sess, run, 'complete');
    releaseTextures(window, tex);
    Screen('CloseAll');
catch ME
    try
        dataMat.error = getReport(ME, 'extended', 'hyperlinks', 'off'); %#ok<NASGU>
        save([run.fileStem '_crash.mat'], 'dataMat', 'ME', '-v7.3');
        utils.endRun(sess, run, 'crashed');
    catch
    end
    Screen('CloseAll');
    rethrow(ME);
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
                error('hw:photoPref:badOrder', 'Unknown SECTION_ORDER "%s".', orderMode);
        end
    otherwise
        error('hw:photoPref:badMode', 'Unknown TASK_MODE "%s".', taskMode);
end
end


%% =====================================================================
function txt = introText(sections)
if numel(sections) == 1 && strcmp(sections{1}, 'rating')
    txt = ['House photo style ratings\n\nThis is a short standalone task ' ...
           'about how much you like different house styles.\n\nClick to continue.'];
elseif numel(sections) == 1 && strcmp(sections{1}, 'pwc')
    txt = ['House photo style choices\n\nThis is a short standalone task ' ...
           'about which house styles you prefer.\n\nClick to continue.'];
else
    txt = ['House photo style task\n\nThis standalone task has two short sections: ' ...
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
        error('hw:photoPref:missingImage', 'Missing house photo: %s', p);
    end
    img = imread(p);
    tex(r) = Screen('MakeTexture', window, img);
end
end


%% =====================================================================
function releaseTextures(window, tex)
if isempty(tex), return; end
handles = tex(isfinite(tex));
for k = 1:numel(handles)
    Screen('Close', handles(k));
end
ShowCursor('Arrow', window);
end


%% =====================================================================
function trials = runRatingTrials(window, cfg, plan, tex)
s = cfg.style;
scr = Screen('Rect', window);
W = scr(3); H = scr(4);
lineY = H * 0.82;
lineLeft = W * 0.18;
lineRight = W * 0.82;
lineLen = lineRight - lineLeft;
imgRect = [W*0.25, H*0.13, W*0.75, H*0.66];
trials = repmat(ratingTrialTemplate(), numel(plan.ratingPhotoRows), 1);

for t = 1:numel(plan.ratingPhotoRows)
    pr = plan.ratingPhotoRows(t);
    t0 = GetSecs;
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
        Screen('Flip', window);
        utils.checkForQuit;

        if buttons(1)
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
function trials = runPwcTrials(window, cfg, plan, tex)
s = cfg.style;
scr = Screen('Rect', window);
W = scr(3); H = scr(4);
leftRect = [W*0.08, H*0.20, W*0.47, H*0.72];
rightRect = [W*0.53, H*0.20, W*0.92, H*0.72];
trials = repmat(pwcTrialTemplate(), size(plan.pwcPairs, 1), 1);

for t = 1:size(plan.pwcPairs, 1)
    leftRow = plan.pwcPairs(t,1);
    rightRow = plan.pwcPairs(t,2);
    t0 = GetSecs;
    choice = '';
    while isempty(choice)
        [mx, my, buttons] = utils.getMouse(window);
        Screen('FillRect', window, s.bg);
        Screen('TextFont', window, s.fontContent);
        Screen('TextSize', window, s.sizeHeading);
        DrawFormattedText(window, 'Which house style do you prefer?', ...
            'center', H*0.08, s.text);
        drawPhoto(window, tex(leftRow), leftRect);
        drawPhoto(window, tex(rightRow), rightRect);
        Screen('TextSize', window, s.sizeLabel);
        DrawFormattedText(window, 'LEFT', mean(leftRect([1 3])) - 30, H*0.75, s.textDim);
        DrawFormattedText(window, 'RIGHT', mean(rightRect([1 3])) - 38, H*0.75, s.textDim);
        drawProgress(window, cfg, t, size(plan.pwcPairs, 1));
        Screen('Flip', window);
        utils.checkForQuit;

        if buttons(1)
            if inRect(leftRect, mx, my)
                choice = 'left';
            elseif inRect(rightRect, mx, my)
                choice = 'right';
            end
            while any(buttons), [~,~,buttons] = utils.getMouse(window); end
        end
    end

    chosenRow = leftRow;
    unchosenRow = rightRow;
    if strcmp(choice, 'right')
        chosenRow = rightRow;
        unchosenRow = leftRow;
    end

    trials(t).section = 'pwc';
    trials(t).trial = t;
    trials(t).leftPhotoId = char(plan.photoTable.photoId(leftRow));
    trials(t).rightPhotoId = char(plan.photoTable.photoId(rightRow));
    trials(t).chosenPhotoId = char(plan.photoTable.photoId(chosenRow));
    trials(t).unchosenPhotoId = char(plan.photoTable.photoId(unchosenRow));
    trials(t).leftPhotoRow = leftRow;
    trials(t).rightPhotoRow = rightRow;
    trials(t).chosenPhotoRow = chosenRow;
    trials(t).unchosenPhotoRow = unchosenRow;
    trials(t).responseSide = choice;
    trials(t).rt = GetSecs - t0;
    trials(t).leftAreaVar = char(plan.photoTable.areaVar(leftRow));
    trials(t).rightAreaVar = char(plan.photoTable.areaVar(rightRow));
    trials(t).leftImageFile = char(plan.photoTable.imageFile(leftRow));
    trials(t).rightImageFile = char(plan.photoTable.imageFile(rightRow));
end
end


%% =====================================================================
function drawPhoto(window, tex, box)
src = Screen('Rect', tex);
dst = fitRect(src, box);
Screen('DrawTexture', window, tex, [], dst);
end


%% =====================================================================
function dst = fitRect(src, box)
sw = src(3) - src(1);
sh = src(4) - src(2);
bw = box(3) - box(1);
bh = box(4) - box(2);
scale = min(bw / sw, bh / sh);
w = sw * scale;
h = sh * scale;
cx = mean(box([1 3]));
cy = mean(box([2 4]));
dst = [cx-w/2, cy-h/2, cx+w/2, cy+h/2];
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
function tf = inRect(rect, x, y)
tf = x >= rect(1) && x <= rect(3) && y >= rect(2) && y <= rect(4);
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
    'leftPhotoId', '', 'rightPhotoId', '', ...
    'chosenPhotoId', '', 'unchosenPhotoId', '', ...
    'leftPhotoRow', NaN, 'rightPhotoRow', NaN, ...
    'chosenPhotoRow', NaN, 'unchosenPhotoRow', NaN, ...
    'responseSide', '', 'rt', NaN, ...
    'leftAreaVar', '', 'rightAreaVar', '', ...
    'leftImageFile', '', 'rightImageFile', '');
end


%% =====================================================================
function T = buildTrialTable(dataMat)
rows = {};
R = dataMat.rating.trials;
for t = 1:numel(R)
    rows{end+1} = {R(t).section, R(t).trial, R(t).photoId, R(t).houseIdx, ...
        R(t).areaVar, R(t).imageFile, R(t).rating, R(t).rt, ...
        "", "", "", "", NaN, NaN, NaN, NaN, "", "", ""}; %#ok<AGROW>
end

P = dataMat.pwc.trials;
for t = 1:numel(P)
    rows{end+1} = {P(t).section, P(t).trial, "", NaN, "", "", NaN, P(t).rt, ...
        P(t).leftPhotoId, P(t).rightPhotoId, P(t).chosenPhotoId, P(t).unchosenPhotoId, ...
        P(t).leftPhotoRow, P(t).rightPhotoRow, P(t).chosenPhotoRow, P(t).unchosenPhotoRow, ...
        P(t).responseSide, P(t).leftAreaVar, P(t).rightAreaVar}; %#ok<AGROW>
end

if isempty(rows)
    T = table();
else
    T = cell2table(vertcat(rows{:}), 'VariableNames', {'section','trial', ...
        'photoId','houseIdx','areaVar','imageFile','rating','rt', ...
        'leftPhotoId','rightPhotoId','chosenPhotoId','unchosenPhotoId', ...
        'leftPhotoRow','rightPhotoRow','chosenPhotoRow','unchosenPhotoRow', ...
        'responseSide','leftAreaVar','rightAreaVar'});
end
end
