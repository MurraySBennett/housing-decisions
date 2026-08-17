clear; clc;


cfg = setupCfg();
[jobsTbl, jobAttrCols]   = loadStimTable(fullfile(cfg.paths.stim,'job_stimuli.csv'));
[housesTbl, houseAttrCols] = loadStimTable(fullfile(cfg.paths.stim,'house_stimuli.csv'));

%% 
RIE_main()

%%
function RIE_main()
% RIE_main — Jobs/Houses decision & pricing task with optional eye-tracking.
% Single-file refactor adapted from the Risky/Intertemporal script.
%
% WHAT’S NEW vs. the gamble version:
% - Loads JOB / HOUSE stimuli from CSV(s) and displays their attributes.
% - Choice blocks: choose left/right option (job vs job, or house vs house).
% - Price blocks: report WTP (house) or desired salary (job) on a semicircle scale.
% - Bonus/payment: base compensation only (no lottery bonus).
%
% Folder layout expected:
%   <project root>/
%     RIE_main.m
%     stimuli/
%        job_stimuli.csv
%        house_stimuli.csv
%     Data/

KbName('UnifyKeyNames');
ListenChar(2);
try
    % ===================== Config & Paths =====================
    cfg   = setupCfg(); % see bottom of script
    addpath(genpath(cfg.paths.tobii));
    addpath(genpath(cfg.paths.task));
    if ~exist(cfg.paths.data, 'dir'), mkdir(cfg.paths.data); end

    subjectNum = 1; %input('Participant #: ');
    sessionNum = 1; %input('Session #: ');
    % ===================== Screen =============================
    AssertOpenGL;
    Screen('Preference','SkipSyncTests', 1);   % consider 0 in production
    Screen('Preference','SuppressAllWarnings',1);
    [w, winRect] = Screen('OpenWindow', 0, 0);
    Screen('BlendFunction', w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('TextSize', w, cfg.font.size);
    Screen('TextStyle', w, cfg.font.style);
    scr = screenStruct(winRect);

    cfg.scr = scr;  % make available to helpers that only get cfg
    scrWidth = scr.rect(3) - scr.rect(1);
    scrHeight= scr.rect(4) - scr.rect(2);
    yTop = 0.25; yBottom = 0.8;

    cfg.positions.left   = [scrWidth*0.30, scrHeight*yTop, scrWidth*0.45, scrHeight*yBottom];
    cfg.positions.center = [scrWidth*0.45, scrHeight*yTop, scrWidth*0.55, scrHeight*yBottom];
    cfg.positions.right  = [scrWidth*0.55, scrHeight*yTop, scrWidth*0.70, scrHeight*yBottom];

    % ===================== Eye Tracker (optional) =============
    et = setupEyeTracker(cfg);

    % ===================== Participant & RNG ==================
    if subjectNum == cfg.debugSubject
        cfg.practice.choiceN        = cfg.debugChoiceN;
        cfg.practice.scaleN         = cfg.debugScaleN;
        cfg.nBlocksEachCond         = 2;
    end
    s = rng('shuffle');
    data = initData(subjectNum, sessionNum, s, cfg, scr);

    % ===================== Geometry (precompute) ==============
    geom = precomputeGeometry(scr, cfg);  % scale, etc.

    % ===================== Load Stimuli =======================
    [jobsTbl, jobAttrCols]   = loadStimTable(fullfile(cfg.paths.stim,'job_stimuli.csv'));
    [housesTbl, houseAttrCols] = loadStimTable(fullfile(cfg.paths.stim,'house_stimuli.csv'));

    % Derive labels from column names (prettified)
    jobAttrLabels   = prettifyLabels(jobAttrCols);
    houseAttrLabels = prettifyLabels(houseAttrCols);

    % ===================== Block Planning =====================
    %   Session 1: Jobs (choice, price)
    %   Session 2: Houses (choice, price)
    % The pair order is randomized per session.
    eachCond = computeEachCond_jobs_houses(sessionNum); % returns e.g., [1 2] or [3 4] randomized
    % 1 = Jobs Choice;  2 = Jobs Price
    % 3 = Houses Choice;4 = Houses Price

    % ===================== Instructions & Practice ============
    showWelcome(w, scr, cfg);
    if sessionNum == 1
        showIntro(w, scr, cfg);
    else
        showRefresher(w, scr, cfg);
    end

    % ===================== Trial Plan Counters =====================
    nSubBlocks = cfg.nSubBlocks;
    trialNum   = 1;

    % Track whether we already did practice per kind
    practiced.choice = false;
    practiced.price  = false;

    % ===================== Main Blocks =============================
    for bN = 1:cfg.nBlocksEachCond
        blockType = eachCond(bN);

        % Which domain & kind is this block?
        [domain, kind] = blockMeta(blockType);

        % Select the correct stimuli & labels for the domain
        switch domain
            case 'jobs'
                tbl      = jobsTbl;
                attrCols = jobAttrCols;
                labels   = jobAttrLabels;
            case 'houses'
                tbl      = housesTbl;
                attrCols = houseAttrCols;
                labels   = houseAttrLabels;
            otherwise
                error('Unknown domain: %s', domain);
        end

        didRating.jobs   = false;
        didRating.houses = false;
        if ~didRating.(domain)
            if strcmp(domain,'jobs')
                data.prefRating.jobs = runAttributeRatingTask( ...
                    w, scr, cfg, jobAttrLabels, ...
                    'Prompt', 'How important is each attribute when considering a JOB?', ...
                    'LeftAnchor', 'Entirely unimportant', ...
                    'RightAnchor','Extremely important', ...
                    'ShowHistory', true);
            else
                data.prefRating.houses = runAttributeRatingTask( ...
                    w, scr, cfg, houseAttrLabels, ...
                    'Prompt', 'How important is each attribute when considering a HOME?', ...
                    'LeftAnchor', 'Entirely unimportant', ...
                    'RightAnchor','Extremely important', ...
                    'ShowHistory', true);
            end
            didRating.(domain) = true;
        end

        if strcmp(kind, 'choice') && ~practiced.choice    
            showPracticeHeader(w, scr, cfg, domain, kind);
            runChoicePractice(w, scr, cfg, tbl, attrCols, labels);
            practiced.choice = true;
        elseif strcmp(kind, 'price') && ~practiced.price
            showPracticeHeader(w, scr, cfg, domain, kind);
            runScalePractice(w, scr, cfg, geom, domain, tbl, attrCols, labels);
            practiced.price = true;
        end

        % ---- Main block ----
        showBlockHeader(w, scr, cfg, blockType);

        % Determine trials per block by kind (ALWAYS set this)
        if strcmp(kind, 'choice')
            nTrialsPerBlock = cfg.nTrialsPerChoiceBlock;
        else
            nTrialsPerBlock = cfg.nTrialsPerPriceBlock;
        end
        nPerSub = round(nTrialsPerBlock / nSubBlocks);

        % ---- Subblocks & trials ----
        for sbi = 1:nSubBlocks
            for tN = 1:nPerSub
                checkForQuit();

                % Fixation
                waitFixationClick(w, scr, cfg);

                % ----- Select stimuli for this trial -----
                switch blockType
                    case 1    % Jobs Choice
                        [leftOpt, rightOpt, leftLabels, rightLabels] = sampleTwoOptions(jobsTbl, jobAttrCols, jobAttrLabels);
                        dom = 'jobs';
                    case 2    % Jobs Price
                        [singleOpt, singleLabels] = sampleOneOption(jobsTbl, jobAttrCols, jobAttrLabels);
                        dom = 'jobs';
                    case 3    % Houses Choice
                        [leftOpt, rightOpt, leftLabels, rightLabels] = sampleTwoOptions(housesTbl, houseAttrCols, houseAttrLabels);
                        dom = 'houses';
                    otherwise % 4: Houses Price
                        [singleOpt, singleLabels] = sampleOneOption(housesTbl, houseAttrCols, houseAttrLabels);
                        dom = 'houses';
                end

                % ----- Trial -----
                switch blockType
                    case {1, 3}  % CHOICE
                        [choice, thisRT, gaze] = runChoiceTrial_Attributes(w, cfg, et, leftOpt, leftLabels, rightOpt, rightLabels);
                        respOut  = choice;      % -1 (left) or +1 (right)
                        trajOut  = [];
                        stimOut  = struct('left',leftOpt,'right',rightOpt,'leftLabels',{leftLabels},'rightLabels',{rightLabels},'domain',dom);
                        typeText = 'choice';
                    otherwise     % PRICE
                        priceRange = moneyRangeForDomain(cfg, dom);
                        [resp, thisRT, traj, gaze] = runPriceTrial_Attributes(w, cfg, geom, et, singleOpt, singleLabels, dom, priceRange);
                        respOut = resp; trajOut = traj;
                        stimOut = struct('option',singleOpt,'labels',{singleLabels},'domain',dom);
                        typeText = 'price';
                end

                % ----- Record -----
                data.trial(trialNum).type          = blockType;
                data.trial(trialNum).typeText      = typeText;
                data.trial(trialNum).domain        = dom;
                data.trial(trialNum).resp          = respOut;
                data.trial(trialNum).rt            = thisRT;
                data.trial(trialNum).stim          = stimOut;
                data.trial(trialNum).traj          = trajOut;
                data.trial(trialNum).blockNum      = bN;
                data.trial(trialNum).trialInBlock  = tN;
                data.trial(trialNum).gazeData      = gaze;

                trialNum = trialNum + 1;

                Screen('Flip', w);
                pause(0.3);
            end
        end

        % Autosave per block
        drawCenterText(w, scr, 'Saving your data... please wait.', cfg);
        Screen('Flip', w);
        save(fullfile(cfg.paths.data, data.fileShort), 'data');
        save(data.fileFull, 'data', '-v7.3');
    end

    % ===================== Final Save & End =====================
    drawCenterText(w, scr, 'Saving your data... please wait.', cfg);
    Screen('Flip', w);
    save(fullfile(cfg.paths.data, data.fileShort), 'data');
    save(data.fileFull, 'data', '-v7.3');

    % Payment: base only (no bonus logic for jobs/houses)
    Payment = cfg.basePay;
    data.payment.Total = Payment;
    save(fullfile(cfg.paths.data, data.fileShort), 'data');
    save(data.fileFull, 'data', '-v7.3');

    drawCenterText(w, scr, 'You are all done with this session! Please inform the experimenter.', cfg);
    Screen('Flip', w); WaitSecs(2); waitAnyClick();

    ListenChar(0);
    Screen('CloseAll');
    fprintf('Session complete. Compensation: $%d\n', Payment);

catch ME
    ListenChar(0);
    Screen('CloseAll');
    warning('RIE_main crashed: %s', ME.message);
    rethrow(ME);
end
end

% ======================================================================
% ============================== HELPERS ===============================
% ======================================================================

function cfg = setupCfg()
cfg.debug                   = false;
cfg.eyeEnabled              = true;

% ---- Fonts/Colors ----
cfg.font.size               = 22;
cfg.font.style              = 1;  % 0 normal, 1 bold
cfg.colors.white            = [255 255 255];
cfg.colors.accent           = [255 255 125];
cfg.colors.good             = [55  255 55];
cfg.colors.bad              = [255 55  55];
cfg.colors.optionBG = [45 45 45];   % subtle gray
cfg.colors.optionBGHover = [65 65 65]; % optional later


% ---- Practice/Structure ----
cfg.nBlocksEachCond         = 2;   % two blocks per session: choice and pricing
cfg.nSubBlocks              = 6;   % blocks per condition
cfg.nTrialsPerChoiceBlock   = 2; % 42;  % 
cfg.nTrialsPerPriceBlock    = 2; % 84;  % 
cfg.practice.choiceN        = 2;
cfg.practice.scaleN         = 2;

% ---- Scale ---- (geometry params; monetary range set per domain)
cfg.scale.majorN            = 11;  % tick count on semicircle
cfg.scale.minorN            = 21;
cfg.scale.innerFrac         = 0.80;
cfg.scale.outerFrac         = 0.85;
cfg.scale.minorFrac         = 0.815;
cfg.scale.textFrac          = 0.915;
cfg.scale.checkRate         = 0.2; % seconds
cfg.scale.offsetY           = 100; % px shift down (bigger = more down)

cfg.positions.left   = [];
cfg.positions.center = [];
cfg.positions.right  = [];

% ---- Default money ranges by domain (needs override) ----
cfg.money.job.min           = 0;
cfg.money.job.max           = 200000;   % desired annual salary
cfg.money.house.min         = 0;
cfg.money.house.max         = 1000000;  % house WTP

cfg.basePay                 = 15;       % base wage

% ---- Paths ----
cfg.paths.task              = pwd;
cfg.paths.tobii             = fullfile(cfg.paths.task, '..', 'TobiiPro.SDK.Matlab_1.9.0.59');
cfg.paths.stim              = fullfile(cfg.paths.task, 'stimuli');
cfg.paths.data              = fullfile(cfg.paths.task, 'Data');

% ---- Debug subject ----
cfg.debugSubject            = 9999;
cfg.debugChoiceN            = 2;
cfg.debugScaleN             = 2;
end

function scr = screenStruct(winRect)
scr.rect = winRect;
scr.cx   = (winRect(3) - winRect(1))/2;
scr.cy   = (winRect(4) - winRect(2))/2;
end

function et = setupEyeTracker(cfg)
et.enabled = cfg.eyeEnabled;
et.obj     = [];
if ~cfg.eyeEnabled, return; end
try
    tobii = EyeTrackingOperations();
    found = tobii.find_all_eyetrackers();
    if isempty(found)
        warning('No eye tracker found; disabling eye tracking.');
        et.enabled = false;
        return;
    end
    et.obj = found(1);
    disp(["Address: ", et.obj.Address]);
    disp(["Model: ", et.obj.Model]);
    disp(["Name: ", et.obj.Name]);
    disp(["Serial number: ", et.obj.SerialNumber]);
catch ME
    warning('Eye tracker setup failed (%s). Disabling eye tracking.', ME.message);
    et.enabled = false;
end
end

function data = initData(subjectNum, sessionNum, s, cfg, scr)
data.randomSeed     = s;
data.SubjectNumber  = subjectNum;
data.SessionNumber  = sessionNum;
data.startTime      = GetSecs;
data.fileShort      = sprintf('RIE%d-%d', subjectNum, sessionNum);
data.fileFull       = fullfile(cfg.paths.data, ['RIE' num2str(subjectNum) '_' datestr(now,'yyyymmdd_HHMMSS')]);
data.trial          = struct([]);
data.cfgSnapshot    = cfg;
end

function showWelcome(w, scr, cfg)
HideCursor();
drawWrappedText(w, scr, cfg, 'Welcome! Click to begin.', 0.0);
Screen('Flip', w);
waitAnyClick();
end

function showIntro(w, scr, cfg)
drawWrappedText(w, scr, cfg, ...
    ['In this session, you will evaluate ' ...
    'jobs and/or houses by comparing their attributes, and sometimes ' ...
    'enter a price (salary you would accept or how much you''d pay for a house).'], -0.15);
drawWrappedText(w, scr, cfg, ...
    'On DECIDE trials, pick the option you prefer (left or right). On PRICE trials, enter your price on a semicircle scale.', 0.15);
Screen('Flip', w);
waitAnyClick();
end

function showRefresher(w, scr, cfg)
HideCursor();
drawWrappedText(w, scr, cfg, ...
    'Welcome back! Click when ready.', 0.0);
Screen('Flip', w);
waitAnyClick();
end

function eachCond = computeEachCond_jobs_houses(sessionNum)
    % Session mapping:
    %   1 -> [Jobs Choice, Jobs Price]
    %   2 -> [Houses Choice, Houses Price]
    switch sessionNum
        case 1, pair = [1 2];
        case 2, pair = [3 4];
        otherwise, pair = [1 2];
    end
    eachCond = pair(randperm(2)); % randomize within session
end


function [tbl, attrCols] = loadStimTable(csvPath)
    if ~exist(csvPath, 'file')
        error('Stimuli CSV not found: %s', csvPath);
    end
    tbl = readtable(csvPath);
    
    % Detect numeric attribute columns
    [attrCols, explain] = detectAttributeColumns(tbl);
    if isempty(attrCols)
        error('No numeric attribute columns detected in %s. %s', csvPath, explain);
    end
    
    % Remove rows with NaN in any attribute column
    tbl = rmmissing(tbl, 'DataVariables', attrCols);
end


function [attrCols, explain] = detectAttributeColumns(tbl)
    % Heuristic: keep NUMERIC columns; drop typical ID/meta columns by name.
    varNames = string(tbl.Properties.VariableNames);
    isNumeric = varfun(@isnumeric, tbl, 'OutputFormat','uniform');
    drop = ismember(lower(varNames), ["id","idx","company","industry","name","city","state","zipcode","address","description","notes"]);
    keep = isNumeric & ~drop;
    attrCols = varNames(keep);
    if isempty(attrCols)
        explain = 'Ensure the table has numeric attribute columns (e.g., workLife, culture, management).';
    else
        explain = '';
    end
    % Optional: domain-specific pruning could go here
end

function labels = prettifyLabels(attrCols)
    labels = cellstr(attrCols);
    for i=1:numel(labels)
        labels{i} = prettifyVarName(labels{i});
    end
end


function out = prettifyVarName(s)
    % prettifyVarName
    % Convert variable names from camelCase / snake_case / kebab-case / mixed
    % to Title Case with spaces, and replace the word "and" with "&".
    
    % Normalize input to char
    if isstring(s), s = char(s); end
    if ~ischar(s)
        out = s;
        return;
    end
    
    s = strrep(s, '_', ' ');
    s = strrep(s, '-', ' ');
    s = regexprep(s, '([a-z])([A-Z])', '$1 $2');
    s = regexprep(s, '([0-9])([A-Za-z])', '$1 $2');
    s = regexprep(s, '([A-Za-z])([0-9])', '$1 $2');
    s = regexprep(s, '([A-Z]+)([A-Z][a-z])', '$1 $2');
    s = regexprep(s, '\s+', ' ');
    s = strtrim(s);
    if isempty(s)
        out = s;
        return;
    end
    tokens = split(s, ' ');
    for i = 1:numel(tokens)
        t = tokens{i};
        if ~isempty(t)
            tokens{i} = [upper(t(1)) lower(t(2:end))];
        end
    end
    for i = 1:numel(tokens)
        if strcmp(tokens{i}, 'And')
            tokens{i} = '&';
        end
    end
    out = strjoin(tokens, ' ');
end


function [leftOpt, rightOpt, leftLabels, rightLabels] = sampleTwoOptions(tbl, attrCols, labels)
    n = height(tbl);
    if n < 2, error('Need at least 2 rows to present two options.'); end
    idx = randperm(n,2);
    leftOpt  = table2array(tbl(idx(1), attrCols));
    rightOpt = table2array(tbl(idx(2), attrCols));
    leftLabels  = labels;
    rightLabels = labels;
end

function [singleOpt, singleLabels] = sampleOneOption(tbl, attrCols, labels)
    n = height(tbl);
    idx = randi(n);
    singleOpt   = table2array(tbl(idx, attrCols));
    singleLabels= labels;
end

% ==================== Practice helpers ====================

function runChoicePractice(w, scr, cfg, tbl, attrCols, labels)
    n = cfg.practice.choiceN;
    for k = 1:n
        checkForQuit();
        waitFixationClick(w, scr, cfg);
        [leftOpt, rightOpt, leftLabels, rightLabels] = sampleTwoOptions(tbl, attrCols, labels);
        runChoiceTrial_Attributes(w, cfg, struct('enabled',false), leftOpt, leftLabels, rightOpt, rightLabels);
        Screen('Flip', w); pause(0.4);
    end
end



function runScalePractice(w, scr, cfg, geom, domain, tbl, attrCols, labels)
    n = cfg.practice.scaleN;
    priceRange = moneyRangeForDomain(cfg, domain);
    
    for k = 1:n
        checkForQuit();
        waitFixationClick(w, scr, cfg);
    
        [singleOpt, singleLabels] = sampleOneOption(tbl, attrCols, labels);
    
        stage = 'preview';          % 'preview' → 'scale'
        clickConfirmed = false;
    
        resp = NaN;
        traj = [0,0];
        t0 = NaN;
        lastCheck = NaN;
    
        ShowCursor('Arrow');
        WaitMouseRelease();          % start clean
    
        while ~clickConfirmed
            checkForQuit();
            Screen('TextSize', w, 18);
    
            % ===================== DRAW COMMON ELEMENTS =====================
            DrawFormattedText(w, 'Practice Trial', ...
                'center', scr.cy * 0.10, cfg.colors.white, 80,0,0,1.4);
    
            drawOptionAttributes(w, singleOpt, singleLabels, 'single', cfg);
    
            Screen('TextSize', w, cfg.font.size);
    
            % ===================== PREVIEW STAGE =====================
            if strcmp(stage, 'preview')
    
                DrawFormattedText(w, ...
                    'Click anywhere to view the scale and enter your response.', ...
                    'center', scr.cy * 0.2, cfg.colors.accent, 80,0,0,1.5);
    
                Screen('Flip', w);
    
                [~,~,buttons] = GetMouse;
                if buttons(1)
                    WaitMouseRelease();   % consume click
                    stage = 'scale';
    
                    % Start RT only once scale is visible
                    t0 = GetSecs;
                    lastCheck = t0;
                end
    
                continue;   % go to next frame
    
            end
    
            % ===================== SCALE STAGE =====================
            DrawFormattedText(w, ...
                sprintf('Enter a %s for this %s on the scale (left-click to confirm).', ...
                    domainScaleName(domain), domain), ...
                'center', scr.cy * 0.20, cfg.colors.white, 80,0,0,1.5,0);
    
            drawScaleMoney(w, cfg, geom, priceRange);
    
            % Cursor → value
            [resp01, xDist, yDist, isOnScale] = readScaleCursor(scr, geom);
    
            if ~isnan(resp01) && isOnScale
                resp = scaleToMoney(resp01, priceRange);
                drawCenterText(w, scr, sprintf('$%.0f', resp), ...
                    cfg, cfg.colors.accent, 0.75);
            end
    
            Screen('Flip', w);
    
            % Trajectory tracking
            if GetSecs - lastCheck > cfg.scale.checkRate
                traj = [traj; xDist, yDist]; %#ok<AGROW>
                lastCheck = GetSecs;
            end
    
            % Confirm
            [~,~,buttons] = GetMouse;
            if buttons(1) && isOnScale
                clickConfirmed = true;
                WaitMouseRelease();
            end
        end
    
        fprintf('Practice %d: Response = $%.0f\n', k, resp);
    end
    
    % End-of-practice screen
    drawWrappedText(w, scr, cfg, 'Click to begin the main experiment.', +0.40);
    Screen('Flip', w);
    waitAnyClick();
end



% ==================== Trial Runners (Attributes) ====================


function [choice, thisRT, gaze] = runChoiceTrial_Attributes(w, cfg, et, leftOpt, leftLabels, rightOpt, rightLabels)
    scr = cfg.scr;
    % Shaded clickable columns
    drawColumnBackground(w, cfg.positions.left,  cfg.colors.optionBG);
    drawColumnBackground(w, cfg.positions.right, cfg.colors.optionBG);
    
    % Text
    Screen('TextSize', w, 18);
    drawAttributeValues(w, leftOpt,  'left',  cfg);
    drawAttributeLabels(w, leftLabels, cfg);   % labels are the same for both
    drawAttributeValues(w, rightOpt, 'right', cfg);
    Screen('TextSize', w, cfg.font.size);
    
    ShowCursor('Arrow');
    Screen('Flip', w);
    
    t0 = GetSecs;
    if cfg.eyeEnabled && ~isempty(et), startGaze(et); end
    
    % Wait for click in a column
    while true
        checkForQuit();
        [x,y,buttons] = GetMouse;
        if buttons(1)
            if pointInRect(x,y,cfg.positions.left)
                choice = -1; thisRT = GetSecs - t0; WaitMouseRelease(); break;
            elseif pointInRect(x,y,cfg.positions.right)
                choice =  1; thisRT = GetSecs - t0; WaitMouseRelease(); break;
            end
        end
        WaitSecs(0.01);
    end
    
    if cfg.eyeEnabled && ~isempty(et), gaze = stopAndGetGaze(et); else, gaze = []; end
end


function [resp, thisRT, traj, gaze] = runPriceTrial_Attributes(w, cfg, geom, et, optValues, labels, domain, priceRange)
    scr = cfg.scr;
    
    % --- Draw attributes ---
    Screen('TextSize', w, 18);
    drawAttributeLabels(w, labels, cfg);
    drawAttributeValues(w, optValues, 'center', cfg);
    Screen('TextSize', w, cfg.font.size);
    
    % Instruction
    DrawFormattedText(w, sprintf('Enter a %s for this %s on the scale (left-click to confirm).', ...
        domainScaleName(domain), domain), ...
        'center', scr.cy*0.10, cfg.colors.white, 80,0,0,1.5,0);
    
    Screen('Flip', w);
    ShowCursor('Arrow');
    
    
    if et.enabled, startGaze(et); end
    t0 = GetSecs;
    
    % Stage: Scale interaction
    traj = [0,0];
    lastCheck = t0;
    resp = NaN;
    
    while true
        checkForQuit();
        drawScaleMoney(w, cfg, geom, priceRange);
        [resp01, xDist, yDist, isOnScale] = readScaleCursor(scr, geom);
    
        % bottomLimit = scr.cy + geom.innerR; % bottom of the arc
        % isAboveBottom = (GetMouseY() < bottomLimit);
    
        if ~isnan(resp01) && isOnScale
            resp = scaleToMoney(resp01, priceRange);
            DrawFormattedText(w, sprintf('Response:\n$%.0f', resp), 'center', scr.cy*0.80, cfg.colors.accent, 80,0,0,1.5,0);
        end
    
        Screen('Flip', w);
    
        % Track trajectory
        if GetSecs - lastCheck > cfg.scale.checkRate
            traj = [traj; xDist, yDist];
            lastCheck = GetSecs;
        end
    
        % Confirm only if left-click AND on scale AND above bottom
        [~,~,buttons] = GetMouse;
        if buttons(1) && isOnScale
            thisRT = GetSecs - t0;
            break;
        end
    end
    
    if et.enabled, gaze = stopAndGetGaze(et); else, gaze = []; end
end


% ==================== Drawing (Attributes & Scale) ====================

function drawOptionAttributes(w, values, labels, side, cfg)
    switch side
        case 'left',  colRect = cfg.positions.left;
        case 'right', colRect = cfg.positions.right;
        otherwise,    colRect = cfg.positions.center;
    end
    
    N = numel(values);
    rowRects = splitVertically(colRect, N, 0.05);
    for i = 1:N
        text = sprintf('%s\n%.0f', labels{i}, values(i));
        xCenter = (colRect(1) + colRect(3)) / 2;  % horizontal center of column
        yCenter = (rowRects{i}(2) + rowRects{i}(4)) / 2;  % vertical center of row
        if strcmp(side, 'single')
            DrawFormattedText(w, text, 'center', yCenter, [255 255 255], 80, 0, 0, 1.4);
        else
            DrawFormattedText(w, text, xCenter, yCenter, [255 255 255], 80, 0, 0, 1.4);
        end
    end
end


function cells = splitVertically(rect, n, gapFrac)
    if n<1, cells = {}; return; end
    if nargin<3, gapFrac = 0.05; end
    x1=rect(1); y1=rect(2); x2=rect(3); y2=rect(4);
    H = y2 - y1;
    gaps = (n-1) * gapFrac * H / n;
    rowH = (H - gaps) / n;
    cells = cell(n,1);
    y = y1;
    for i=1:n
        cells{i} = [x1, y, x2, y + rowH];
        y = y + rowH + gapFrac*H/n;
    end
end


function drawScaleMoney(w, cfg, geom, priceRange)
    scr = cfg.scr;
    % Recompute label ticks for money range (e.g., $0..$200k)
    majorN = cfg.scale.majorN;
    ticks  = linspace(priceRange.min, priceRange.max, majorN);
    % Draw arcs & tick lines already in geom
    Screen('DrawLines', w, geom.majorRL, 3, cfg.colors.white);
    Screen('DrawLines', w, geom.minorRL, 2, cfg.colors.white);
    
    offsetY = cfg.scale.offsetY;
    Screen('FrameArc', w, cfg.colors.white, ...
        [scr.cx-geom.innerR, scr.cy-geom.innerR+offsetY, scr.cx+geom.innerR, scr.cy+geom.innerR+offsetY], 270, 180, 5, 5);
    % Draw money labels along the arc angles (use geom.tickAng slots count)
    angs = linspace(pi, 2*pi, majorN);
    for n=1:majorN
        textLocX = round(geom.textFrac * scr.cy * cos(angs(n)) + scr.cx);
        textLocY = round(geom.textFrac * 0.95 * scr.cy * sin(angs(n)) + scr.cy + offsetY);
        Screen('DrawText', w, ['$' formatMoney(ticks(n))], textLocX, textLocY, cfg.colors.white);
    end
    ShowCursor('Arrow');
end

function s = formatMoney(x)
    % 0..1e6 -> human readable without commas (Psychtoolbox Text has no commas)
    if x >= 1000
        s = sprintf('%.0fk', x/1000);
    else
        s = sprintf('%.0f', x);
    end
end



function [resp01, xDist, yDist, isOnScale] = readScaleCursor(scr, geom)
    tolPix = 50; % tolerance band for click
    offsetY = geom.offsetY; % vertical shift applied to scale center
    
    [xMouse, yMouse, ~] = GetMouse;
    xDist = xMouse - scr.cx;
    yDist = (scr.cy + offsetY) - yMouse; % adjust for offset
    r     = sqrt(xDist^2 + yDist^2);
    th    = atan2(abs(yDist), xDist);
    
    innerR = geom.innerR;
    isOnScale = (r >= innerR) && (r <= innerR + tolPix);
    
    resp01 = NaN;
    if isOnScale
        resp01 = (pi - th) / pi;
        resp01 = max(0, min(1, resp01));
    end
end


function money = scaleToMoney(resp01, priceRange)
    if isnan(resp01), money = NaN; return; end
    money = priceRange.min + resp01 * (priceRange.max - priceRange.min);
    money = round(money);
end

function nm = domainPrompt(dom)
    switch lower(dom)
        case 'jobs',   nm = 'salary would you accept for this job';
        case 'houses', nm = 'maximum price you would pay for this house';
        otherwise, nm = 'price';
    end
end

function nm = domainScaleName(dom)
    switch lower(dom)
        case 'jobs',   nm = 'salary';
        case 'houses', nm = 'bid';
        otherwise, nm = 'price';
    end
end

function priceRange = moneyRangeForDomain(cfg, dom)
    switch lower(dom)
        case 'jobs',   priceRange = struct('min',cfg.money.job.min,'max',cfg.money.job.max);
        case 'houses', priceRange = struct('min',cfg.money.house.min,'max',cfg.money.house.max);
        otherwise,     priceRange = struct('min',0,'max',20000);
    end
end

% ==================== Geometry/Scale precompute ====================

function geom = precomputeGeometry(scr, cfg)
    innerR      = cfg.scale.innerFrac * scr.cy;
    outerR      = cfg.scale.outerFrac * scr.cy;
    minorR      = cfg.scale.minorFrac * scr.cy;
    textFrac    = cfg.scale.textFrac;
    tickAng     = linspace(pi, 2*pi, cfg.scale.majorN);
    mtickAng    = linspace(pi, 2*pi, cfg.scale.minorN);
    offsetY     = cfg.scale.offsetY;
    
    majorRL = zeros(2, cfg.scale.majorN*2);
    minorRL = zeros(2, cfg.scale.minorN*2);
    for n=1:cfg.scale.majorN
        majorRL(1,2*n-1) = round(innerR * cos(tickAng(n)) + scr.cx);
        majorRL(2,2*n-1) = round(innerR * sin(tickAng(n)) + scr.cy + offsetY);
        majorRL(1,2*n)   = round(outerR * cos(tickAng(n)) + scr.cx);
        majorRL(2,2*n)   = round(outerR * sin(tickAng(n)) + scr.cy + offsetY);
    end
    for n=1:cfg.scale.minorN
        minorRL(1,2*n-1) = round(innerR * cos(mtickAng(n)) + scr.cx);
        minorRL(2,2*n-1) = round(innerR * sin(mtickAng(n)) + scr.cy + offsetY);
        minorRL(1,2*n)   = round(minorR * cos(mtickAng(n)) + scr.cx);
        minorRL(2,2*n)   = round(minorR * sin(mtickAng(n)) + scr.cy + offsetY);
    end
    
    geom.innerR   = innerR;
    geom.outerR   = outerR;
    geom.minorR   = minorR;
    geom.textFrac = textFrac;
    geom.tickAng  = tickAng;
    geom.mtickAng = mtickAng;
    geom.majorRL  = majorRL;
    geom.minorRL  = minorRL;
    geom.offsetY  = offsetY;

end

% ==================== UI/Flow helpers ====================

function waitFixationClick(w, scr, cfg)
    DrawFormattedText(w, '+', 'center', 'center', cfg.colors.white, 80, 0, 0, 1.4);
    DrawFormattedText(w, '(Click on the + to start)', 'center', scr.cy+150, cfg.colors.white, 80, 0, 0, 1.4);
    ShowCursor('Arrow');
    Screen('Flip', w);

    % Ensure we start with no buttons down
    WaitMouseRelease();

    while true
        checkForQuit();
        [x,y,buttons] = GetMouse;
        if any(buttons) && abs(x - scr.cx) <= 40 && abs(y - scr.cy) <= 40
            break;
        end
        WaitSecs(0.01);
    end

    WaitMouseRelease();
    Screen('Flip', w);
    WaitSecs(0.2);
end


function WaitMouseRelease()
    while true
        [~,~,b] = GetMouse;
        if ~any(b), break; end
        WaitSecs(0.01);
    end
end


function drawCenterText(w, scr, txt, cfg, color, yShift)
    if nargin < 5, color = cfg.colors.white; end
    if nargin < 6, yShift = 0; end
    y = scr.cy + yShift * scr.cy;
    DrawFormattedText(w, txt, 'center', y, color, 80, 0, 0, 1.4);
end

function drawWrappedText(w, scr, cfg, txt, yShift)
    if nargin < 5, yShift = 0; end
    y = scr.cy + yShift * scr.cy;
    DrawFormattedText(w, txt, 'center', y, cfg.colors.white, 80, 0, 0, 1.4);
end


function waitAnyClick()
    % Wait for all buttons to be up first (consume any carry-over)
    while true
        [~, ~, buttons] = GetMouse;
        if ~any(buttons), break; end
        WaitSecs(0.01);
    end
    
    % Now wait for a fresh press
    while true
        [~, ~, buttons] = GetMouse;
        if any(buttons), break; end
        WaitSecs(0.01);
    end
    
    % And wait for release to avoid bleeding into the next screen
    while true
        [~, ~, buttons] = GetMouse;
        if ~any(buttons), break; end
        WaitSecs(0.01);
    end
    
    % Tiny debounce to allow OS event queue to settle
    WaitSecs(0.05);
end


% ==================== Eyetracking wrappers ====================

function startGaze(et)
    try et.obj.get_gaze_data(); catch, end
end

function gaze = stopAndGetGaze(et)
    try
        gaze = et.obj.get_gaze_data();
        et.obj.stop_gaze_data();
    catch
        gaze = [];
    end
end

% ==================== Safety quit ('ESCAPE') ====================


function checkForQuit()
    [keyIsDown, ~, keyCode] = KbCheck;
    if keyIsDown
        escIdx = KbName('ESCAPE');
        if keyCode(escIdx)
            ListenChar(0);
            Screen('CloseAll');
            fprintf('Experiment terminated by user.\n');
            error('User quit the experiment.');
        end
    end
end


function tf = pointInRect(x,y,rect)
    tf = x >= rect(1) && x <= rect(3) && y >= rect(2) && y <= rect(4);
end


function y = GetMouseY()
[   ~, y, ~] = GetMouse;
end


function drawColumnBackground(w, rect, color)
    radius = 25; % px rounding
    Screen('FillRect', w, color, rect);
    % Optional rounding (Psychtoolbox style workaround)
    Screen('FrameRect', w, color, rect, radius);
end

function drawAttributeLabels(w, labels, cfg)
    colRect = cfg.positions.center;
    N = numel(labels);
    rowRects = splitVertically(colRect, N, 0.05);
    
    Screen('TextStyle', w, 1); % bold
    for i = 1:N
        yCenter = mean(rowRects{i}([2 4]));
        DrawFormattedText( ...
            w, labels{i}, 'center', yCenter, ...
            cfg.colors.white, 80, 0, 0, 1.4);
    end
end



function drawAttributeValues(w, values, side, cfg)
    % Determine column rect based on side
    switch side
        case 'left'
            colRect = cfg.positions.left;
        case 'right'
            colRect = cfg.positions.right;
        case 'center'
            colRect = cfg.positions.center;
        otherwise
            error('drawAttributeValues_precise: unknown side "%s"', side);
    end
    
    N = numel(values);
    rowRects = splitVertically(colRect, N, 0.05);
    
    % Column center (for horizontal centering)
    xColCenter = (colRect(1) + colRect(3)) / 2;
    
    Screen('TextStyle', w, 0); % normal
    for i = 1:N
        txt = sprintf('%.0f', values(i));
    
        % Measure text width/height
        bbox = Screen('TextBounds', w, txt);
        textW = bbox(3) - bbox(1);
        textH = bbox(4) - bbox(2);
    
        % Row vertical center
        yRowCenter = (rowRects{i}(2) + rowRects{i}(4)) / 2;
    
        % Compute top-left so that text is centered in the row and column
        xText = round(xColCenter - textW/2);
        yText = round(yRowCenter - textH/2);
    
        % Draw
        Screen('DrawText', w, txt, xText, yText, cfg.colors.white);
    end
end

function showPracticeHeader(w, scr, cfg, domain, kind)
    switch lower(domain)
        case 'jobs',   domTitle = 'JOBS';
        case 'houses', domTitle = 'HOUSES';
        otherwise,     domTitle = upper(domain);
    end
    switch lower(kind)
        case 'choice'
            kindTitle = 'DECIDE';
            prompt = ['You will now complete a short practice block.\nDuring this block, you will see attributes for competing ', domain, '. Please click the column of attributes that you prefer.'];
        otherwise % 'price'
            kindTitle = 'PRICE';
            prompt = sprintf('During this block, you will see a set of attributes for a %s. Enter your %s by clicking on the scale.', ...
                domain(1:end-1), domainScaleName(domain));
    end
    Screen('FillRect', w, 0);
    DrawFormattedText(w, sprintf('%s — %s', domTitle, kindTitle), ...
        'center', scr.cy * 0.75, cfg.colors.white, 80, 0, 0, 1.4);
    DrawFormattedText(w, prompt, ...
        'center', scr.cy * 0.85, cfg.colors.white, 80, 0, 0, 1.5);
    DrawFormattedText(w, 'Click to begin.', ...
            'center', scr.cy * 1.5, cfg.colors.accent, 80, 0, 0, 1.5);
    Screen('Flip', w);
    waitAnyClick();
end


function showBlockHeader(w, scr, cfg, blockType)
    [domain, kind] = blockMeta(blockType);
    switch lower(domain)
        case 'jobs',   domTitle = 'JOBS';
        case 'houses', domTitle = 'HOUSES';
        otherwise,     domTitle = upper(domain);
    end
    
    switch lower(kind)
        case 'choice'
            kindTitle = 'DECIDE';
            prompt = 'During this block, you will see two sets of attributes. Click the column you prefer.';
        otherwise % 'price'
            kindTitle = 'PRICE';
            prompt = sprintf('During this block, you will see a set of attributes. Enter your %s by clicking on the scale.', ...
                domainScaleName(domain));
    end
    
    Screen('FillRect', w, 0); % clear to black (or your bg color)
    DrawFormattedText(w, sprintf('%s — %s', domTitle, kindTitle), ...
        'center', scr.cy * 0.75, cfg.colors.white, 80, 0, 0, 1.4);
    DrawFormattedText(w, prompt, ...
        'center', scr.cy * 0.85, cfg.colors.white, 80, 0, 0, 1.5);
    DrawFormattedText(w, 'Click to begin this block', ...
            'center', scr.cy * 0.95, cfg.colors.accent, 80, 0, 0, 1.5);
    Screen('Flip', w);
    waitAnyClick();
end


function [domain, kind] = blockMeta(blockType)
    % Returns domain ('jobs'/'houses') and kind ('choice'/'price')
    switch blockType
        case 1, domain = 'jobs';   kind = 'choice';
        case 2, domain = 'jobs';   kind = 'price';
        case 3, domain = 'houses'; kind = 'choice';
        case 4, domain = 'houses'; kind = 'price';
        otherwise, error('Unknown blockType: %d', blockType);
    end
end


function tf = isChoiceBlock(blockType)
    tf = (blockType == 1) || (blockType == 3);
end



function ratingOut = runAttributeRatingTask(w, scr, cfg, attrLabels, varargin)
    % runAttributeRatingTask
    % Collect importance ratings for a set of attributes using a horizontal line.
    %
    % USAGE:
    %   ratingOut = runAttributeRatingTask(w, scr, cfg, attrLabels)
    %   ratingOut = runAttributeRatingTask(w, scr, cfg, attrLabels, ...
    %                 'Prompt', 'Please rate...', ...
    %                 'LeftAnchor', 'Entirely unimportant', ...
    %                 'RightAnchor','Extremely important', ...
    %                 'TopTextYFrac', 0.50, ...
    %                 'AttrTextYFrac', 0.75, ...
    %                 'LineYFrac', 1.20, ...
    %                 'LineHalfWidthXFrac', 0.80, ...
    %                 'DotSize', 25, ...
    %                 'ShowHistory', true);
    %
    % INPUTS:
    %   w, scr, cfg      : your usual Psychtoolbox handles/structs.
    %   attrLabels       : cellstr of attribute names to rate (e.g., jobAttrLabels).
    %
    % NAME-VALUE OPTIONS:
    %   'Prompt'         : top instruction text (default provided).
    %   'LeftAnchor'     : left label under the scale.
    %   'RightAnchor'    : right label under the scale.
    %   'TopTextYFrac'   : y location for prompt as a fraction of scr.cy.
    %   'AttrTextYFrac'  : y for current attribute label (fraction of scr.cy).
    %   'LineYFrac'      : y for the rating line (fraction of scr.cy).
    %   'LineHalfWidthXFrac': half-width of the rating line as fraction of scr.cx.
    %   'DotSize'        : size of the rating dot.
    %   'ShowHistory'    : show previous choices as stems + faint labels (true/false).
    %
    % OUTPUT:
    %   ratingOut struct with fields:
    %     .attNames      : attribute labels (cellstr)
    %     .attRatingsX   : raw x positions (pixels)
    %     .attRatings01  : normalized [0..1] along the line
    %     .attRatingRTs  : RTs (seconds)
    %
    % BEHAVIOR:
    %   - Requires a left-click near the line to confirm a rating.
    %   - Uses fresh-click semantics (no carry-over).
    %   - Draws everything each frame, then Screen('Flip') once.
    
    % -------- Options & defaults --------
    p = inputParser;
    p.addParameter('Prompt', 'Please place this attribute on the line in terms of how important it would be to you when considering a home purchase.', @ischar);
    p.addParameter('LeftAnchor',  'Entirely unimportant', @ischar);
    p.addParameter('RightAnchor', 'Extremely important', @ischar);
    p.addParameter('TopTextYFrac',  0.50, @isnumeric);
    p.addParameter('AttrTextYFrac', 0.75, @isnumeric);
    p.addParameter('LineYFrac',     1.20, @isnumeric);
    p.addParameter('LineHalfWidthXFrac', 0.80, @isnumeric); % abs(x - cx) < cx*0.80
    p.addParameter('DotSize', 25, @isnumeric);
    p.addParameter('ShowHistory', true, @islogical);
    p.parse(varargin{:});
    opt = p.Results;
    
    % -------- Geometry for the line --------
    cx = scr.cx; cy = scr.cy;
    lineY  = cy * opt.LineYFrac;
    halfW  = scr.cx * opt.LineHalfWidthXFrac;      % half-width in px
    xLeft  = cx - halfW;
    xRight = cx + halfW;
    
    % output containers
    N = numel(attrLabels);
    attRatingsX  = nan(1,N);
    attRatings01 = nan(1,N);
    attRTs       = nan(1,N);
    
    ptsToDraw = []; % [2 x k] prior choices
    
    % Ensure we start with buttons up
    WaitMouseRelease();
    
    for n = 1:N
        respEntered = false;
    
        % pre-draw intro for this attribute (optional brief exposure)
        DrawFormattedText(w, opt.Prompt, 'center', cy*opt.TopTextYFrac, cfg.colors.white, 80, 0, 0, 1.4);
        DrawFormattedText(w, attrLabels{n}, 'center', cy*opt.AttrTextYFrac, cfg.colors.white, 80, 0, 0, 1.4);
        Screen('Flip', w);
        WaitSecs(0.25);  % brief exposure, tweak if desired
    
        t0 = GetSecs;
        ShowCursor('Arrow');
    
        while ~respEntered
            % ----- Draw full frame -----
            % Instruction & current attribute
            DrawFormattedText(w, opt.Prompt, 'center', cy*opt.TopTextYFrac, cfg.colors.white, 80, 0, 0, 1.4);
            DrawFormattedText(w, attrLabels{n}, 'center', cy*opt.AttrTextYFrac, cfg.colors.white, 80, 0, 0, 1.4);
    
            % Rating line
            Screen('DrawLines', w, [xLeft, xRight; lineY, lineY], 6, cfg.colors.white);
    
            % Anchors (constrained to left/right halves)
            DrawFormattedText(w, opt.LeftAnchor,  'center', cy*1.15, cfg.colors.white, 80, 0, 0, 1.4, 0, [0, 0, cx*0.8, cy*2]);
            DrawFormattedText(w, opt.RightAnchor, 'center', cy*1.15, cfg.colors.white, 80, 0, 0, 1.4, 0, [cx*1.2, 0, cx*2.1, cy*2]);
    
            % Prior points + stems + faint labels (history)
            if opt.ShowHistory && ~isempty(ptsToDraw)
                Screen('DrawDots', w, ptsToDraw, opt.DotSize, [155 155 155], [0,0], 1, 1);
                for m = 1:size(ptsToDraw,2)
                    xpm = ptsToDraw(1,m);
                    % stem downwards (offset by 20 px each prior)
                    Screen('DrawLines', w, [xpm, xpm; lineY, lineY + 20 + 20*m], 3, [155 155 155]);
                    DrawFormattedText(w, attrLabels{m}, xpm + 3, lineY + 20 + 20*m, [155 155 155], 80, 0, 0, 1.2);
                end
            end
    
            % Mouse
            [xMouse, yMouse, buttons] = GetMouse;
    
            % Show live dot only when near the line in x and y
            if abs(xMouse - cx) < halfW && abs(yMouse - lineY) < 100
                Screen('DrawDots', w, [xMouse; lineY], opt.DotSize, cfg.colors.white, [0,0], 1, 1);
            end
    
            Screen('Flip', w);
    
            % Confirm logic: left click, near the line in x and y
            if buttons(1) && abs(xMouse - cx) < halfW && abs(yMouse - lineY) < 100
                respEntered = true;
                attRTs(n)   = GetSecs - t0;
    
                % clamp x to the line extents
                xClamped = min(max(xMouse, xLeft), xRight);
    
                attRatingsX(n)  = xClamped;
                attRatings01(n) = (xClamped - xLeft) / (xRight - xLeft);
    
                ptsToDraw = [ptsToDraw, [xClamped; lineY]]; %#ok<AGROW>
    
                WaitMouseRelease();  % consume click to avoid carry-over
            end
    
            WaitSecs(0.01);
        end
    end
    
    % Pack results
    ratingOut = struct();
    ratingOut.attNames     = attrLabels(:);
    ratingOut.attRatingsX  = attRatingsX;
    ratingOut.attRatings01 = attRatings01;
    ratingOut.attRatingRTs = attRTs;
    
    % brief end frame
    Screen('Flip', w);
    WaitSecs(0.2);

end
