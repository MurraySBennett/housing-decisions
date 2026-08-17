clear; clc;
KbName('UnifyKeyNames');
testing = true;
eye_tracking = false;

%% --- INITIAL SETUP & CONFIG ---
cfg = setupCfg(); 

subID = input('Participant ID: ', 's');
sessionType = '';
while ~ismember(sessionType, {'house', 'job'})
    sessionType = lower(input('Enter Session Type (house/job): ', 's'));
end
dt = string(datetime('now', 'Format', 'yyyy-MM-dd-HH-mm'));
saveName = sprintf('p-%02d_task-%s_%s', str2double(subID), sessionType, dt);


Screen('Preference', 'SkipSyncTests', 1);
testingRect = [100 100 1200 900];

if testing
    [window, ScreenRect] = PsychImaging('OpenWindow', 0, BlackIndex(0), testingRect);
else
    [window, ScreenRect] = PsychImaging('OpenWindow', 0, BlackIndex(0));
end
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
% HideCursor;

% Load stimuli
if strcmpi(sessionType, 'house')
    [stimTbl, ~] = loadStimTable(fullfile(cfg.paths.stim, 'house_stimuli.csv'));
    fprintf('Loading house images...\n');
    houseTextures = loadHouseTextures(window, stimTbl, fullfile(cfg.paths.stim, 'house_images'));
else
    [stimTbl, ~] = loadStimTable(fullfile(cfg.paths.stim, 'job_stimuli.csv'));
    stimTbl = renamevars(stimTbl, ...
        ["workLife", "culture", "compensationBenefits", "jobSecurityAdvancement", "management", "wage"], ...
        ["Work-Life Balance", "Culture", "Compensation & Benefits", "Job Security & Advancement", "Management", "Wage"] ...
    );
    houseTextures = []; 
end

%%


% Start the Experiment
RIE_main(sessionType, stimTbl, houseTextures, window, ScreenRect, subID, saveName);

%% ===================== MAIN EXPERIMENT FUNCTION =====================

function RIE_main(type, stimTbl, allTextures, w, rect, subID, saveName)
    cfg = setupCfg();
    try
        cfg.screen.rect = rect;
        cfg.screen.centerX = rect(3)/2;
        cfg.screen.centerY = rect(4)/2;
        Screen('TextFont', w, 'Arial');
        Screen('TextSize', w, 24);

        allData = {};
        
        % Block-level Attribute Manipulation Setup
        attrLevels = [2, 4, 6]; 
        taskTypes = {'choice', 'pricing'};
        blockDesign = table();
        counter = 1;
        for a = 1:length(attrLevels)
            for t = 1:length(taskTypes)
                blockDesign.attr(counter) = attrLevels(a);
                blockDesign.task(counter) = taskTypes(t);
                counter = counter + 1;
            end
        end

        numBlocks = height(blockDesign);
        shuffleIdx = randperm(numBlocks);
        blockDesign = blockDesign(shuffleIdx, :);

        % per block
        nPriceTrials = 2;
        nChoiceTrials = 2;
       
        % --- EXPERIMENT LOOP ---
        for b = 1:numBlocks
            currentAttrs = blockDesign.attr(b);
            currentTask = blockDesign.task{b};

            introMsg = sprintf('Block %d of %d\n\nTask: %s\nAttributes: %d\n\nClick to start.', b, numBlocks, upper(currentTask), currentAttrs);
            % currentBlockAttrs = blockAttrCounts(b);
            DrawFormattedText(w, introMsg, 'center', 'center', [255 255 255]);
            Screen('Flip', w);
            
            buttons = [0 0 0]; 
            while ~any(buttons); [~,~,buttons] = GetMouse(w); end
            while any(buttons);  [~,~,buttons] = GetMouse(w); end
            
            if strcmpi(currentTask, 'choice')
                for t = 1:nChoiceTrials
                    idx = randperm(height(stimTbl), 2);
                    itemA = stimTbl(idx(1), :);
                    itemB = stimTbl(idx(2), :);
                    texA = []; texB = [];
                    if strcmpi(type, 'house')
                        texA = allTextures{idx(1)};
                        texB = allTextures{idx(2)};
                    end
                    runITI(w, cfg);
                    [choice, rt] = doChoiceTrial(w, cfg, itemA, itemB, type, currentAttrs, texA, texB);
                    trialLog = {subID, b, t, 'choice', currentAttrs, idx(1), idx(2), choice, rt, NaN};
                    allData = [allData; trialLog];
                end
            else
                for t = 1:nPriceTrials
                    idx = randi(height(stimTbl));
                    itemP = stimTbl(idx, :);
                    texP = [];
                    if strcmpi(type, 'house'), texP = allTextures{idx}; end
                    runITI(w, cfg);
                    [price, readyRT, priceRT] = doPriceTrial(w, cfg, itemP, type, currentAttrs, texP);
                    trialLog = {subID, b, t, 'pricing', currentAttrs, idx, NaN, price, readyRT, priceRT};
                    allData = [allData; trialLog];
                end
            end
            
            save(fullfile(cfg.paths.data, [saveName '_backup.mat']), 'allData');
        end
        results = cell2table(allData, 'VariableNames', ...
            {'participant', 'block', 'trial', 'task', 'num_attrs', 'stim_a', 'stim_b', 'response', 'duration', 'full_price_duration'});
        writetable(results, fullfile(cfg.paths.data, [saveName '.csv']));
        
        DrawFormattedText(w, 'Experiment Complete.\nThank you!', 'center', 'center', [255 255 255]);
        Screen('Flip', w);
        WaitSecs(2);
        
        Screen('CloseAll');
        ListenChar(0);

    catch ME
        if exist('allData', 'var'), save(fullfile(cfg.paths.crashed, ['CRASH_SAVE_' subID '.mat']), 'allData'); end
        sca;
        ListenChar(0);
        rethrow(ME);
    end
end

%% ===================== TRIAL FUNCTIONS =====================
function runITI(w, cfg)
    cx = cfg.screen.centerX;
    cy = cfg.screen.centerY;
    
    fixSize = 20;
    Screen('DrawLine', w, [255 255 255], cx - fixSize, cy, cx + fixSize, cy, 3);
    Screen('DrawLine', w, [255 255 255], cx, cy - fixSize, cx, cy + fixSize, 3);
    
    Screen('TextSize', w, 20);
    DrawFormattedText(w, 'Click the center to start trial', 'center', cy + 50, [200 200 200]);
    Screen('Flip', w);
    
    buttons = [0 0 0];
    clickReached = false;
    while ~clickReached
        [mx, my, buttons] = GetMouse(w);
        if buttons(1) && IsInRect(mx, my, [cx-25, cy-25, cx+25, cy+25])
            clickReached = true;
        end
        checkForQuit();
    end   
    Screen('Flip', w);
    WaitSecs(0.2);
end

function [choice, rt] = doChoiceTrial(w, cfg, itemA, itemB, type, numAttrs, texA, texB)
    cx = cfg.screen.centerX;
    cy = cfg.screen.centerY;
    
    leftRect  = [cx - 650, cy - 450, cx - 50, cy + 450]; 
    rightRect = [cx + 50,  cy - 450, cx + 650, cy + 450];
    
    respEntered = false;
    buttons = [0 0 0]; 
    
    t0 = GetSecs;
    while ~respEntered
        [mx, my, buttons] = GetMouse(w);
        
        drawItemCard(w, leftRect,  itemA, type, numAttrs, false, texA);
        drawItemCard(w, rightRect, itemB, type, numAttrs, false, texB);
        
        Screen('TextSize', w, 28);
        DrawFormattedText(w, 'Which do you prefer? Click Left or Right.', 'center', cfg.screen.rect(4)-40, [255 255 255]);
        Screen('Flip', w);
        
        if buttons(1)
            if IsInRect(mx, my, leftRect)
                rt = GetSecs - t0;
                choice = 1; respEntered = true;
            elseif IsInRect(mx, my, rightRect)
                rt = GetSecs - t0;
                choice = 2; respEntered = true;
                
            end
            
            if respEntered
                drawItemCard(w, leftRect,  itemA, type, numAttrs, (choice==1), texA);
                drawItemCard(w, rightRect, itemB, type, numAttrs, (choice==2), texB);
                Screen('Flip', w);
                WaitSecs(0.3);
                while any(buttons); [~,~,buttons] = GetMouse(w); end
            end
        end
        checkForQuit();
    end
end

function [pricePaid, readyRT, pricingRT] = doPriceTrial(w, cfg, item, type, numAttrs, texStruct)
    
    clearAttrs = true;

    cx = cfg.screen.centerX;
    cy = cfg.screen.centerY;
    ScreenRect = cfg.screen.rect;
    
    if clearAttrs
        cardRect = [cx-350, cy - 450, cx+350, cy + 450];
        scaleCenter = [cx, cy];
        promptX = 'center'; promptY = cardRect(4)+50;
    else
        cardRect = [cx - 850, cy - 450, cx - 150, cy + 450];
        scaleCenter = [ScreenRect(3)*.78, ScreenRect(4)*.5];
        promptX = cx+150; promptY = cy;
    end

    readyToPrice = false;
    t0 = GetSecs;
    while ~readyToPrice
        drawItemCard(w, cardRect, item, type, numAttrs, false, texStruct);
        
        Screen('TextSize', w, 32);
        DrawFormattedText(w, 'Click when ready to price', promptX, promptY, [255 255 255], [], [], [], [], [], [cx, 0, ScreenRect(3), ScreenRect(4)]);
        Screen('Flip', w);

        [~, ~, buttons] = GetMouse(w);
        if any(buttons)
            while any(buttons); [~,~,buttons] = GetMouse(w); end
            readyToPrice = true;
            readyRT = GetSecs - t0;
        end
        checkForQuit();
    end

    % --- STAGE 2: PRICING SCALE APPEARS ---
    center = [ScreenRect(3)*.78, ScreenRect(4)*.5]; 
    maxPrice = 1000000;
    if any(strcmp('listPrice', item.Properties.VariableNames)), maxPrice = item.listPrice; end
    
    scaleMax = maxPrice;
    scaleMin = 0;
    scaleColor = [255 255 255];
    textColor = [255 255 255];
    majorTicks = linspace(scaleMin,scaleMax,11);
    minorTicks = linspace(scaleMin,scaleMax,51);
    numTicks = length(majorTicks);
    numMinorTicks = length(minorTicks);
    
    % Scale Geometry (relative to scaleCenter)
    innerRadius = 0.35 * (ScreenRect(4)/2); 
    outerRadius = 0.40 * (ScreenRect(4)/2); 
    minorRadius = 0.365 * (ScreenRect(4)/2);
    textRadius  = 0.48; 
    tickAngles = linspace(pi, 2*pi, numTicks);
    minorTickAngles = linspace(pi, 2*pi, numMinorTicks);
    
    priceEntered = 0;
    while priceEntered == 0
        if ~clearAttrs; drawItemCard(w, leftRect, item, type, numAttrs, false, texStruct); end
        
        radialLines = zeros(2, numTicks*2);
        minRadialLines = zeros(2, numMinorTicks*2);
        for n = 1:numTicks
            radialLines(1,(n*2-1)) = round(innerRadius * cos(tickAngles(n)) + scaleCenter(1));
            radialLines(2,(n*2-1)) = round(innerRadius * sin(tickAngles(n)) + scaleCenter(2));
            radialLines(1,(n*2))   = round(outerRadius * cos(tickAngles(n)) + scaleCenter(1));
            radialLines(2,(n*2))   = round(outerRadius * sin(tickAngles(n)) + scaleCenter(2));
            
            textTick = ['$',num2str(majorTicks(n)/1000,'%.0f'),'k'];
            textLocX = round(textRadius * (ScreenRect(4)/2) * cos(tickAngles(n)) + scaleCenter(1)) - 40;
            textLocY = round(textRadius * (ScreenRect(4)/2) * sin(tickAngles(n)) + scaleCenter(2)) + 10;
            Screen('TextSize', w, 20);
            Screen('DrawText', w, textTick, textLocX, textLocY, textColor);
        end
        
        for n = 1:numMinorTicks
            minRadialLines(1,(n*2-1)) = round(innerRadius * cos(minorTickAngles(n)) + scaleCenter(1));
            minRadialLines(2,(n*2-1)) = round(innerRadius * sin(minorTickAngles(n)) + scaleCenter(2));
            minRadialLines(1,(n*2))   = round(minorRadius * cos(minorTickAngles(n)) + scaleCenter(1));
            minRadialLines(2,(n*2))   = round(minorRadius * sin(minorTickAngles(n)) + scaleCenter(2));
        end        
        Screen('DrawLines', w, radialLines, 3, scaleColor);
        Screen('DrawLines', w, minRadialLines, 2, scaleColor);
        Screen('FrameArc', w, scaleColor, [scaleCenter(1)-innerRadius, scaleCenter(2)-innerRadius, scaleCenter(1)+innerRadius, scaleCenter(2)+innerRadius], 270, 180, 5);        
        
        % Response Logic
        [xM, yM, buttons] = GetMouse(w);
        xDev = xM - scaleCenter(1);
        yDev = scaleCenter(2) - yM;
        
        if yDev > 0
            respAngle = atan2(yDev, xDev);
            respPrice = scaleMax - (respAngle/pi)*scaleMax;
            xdot = round(innerRadius * cos(respAngle) + scaleCenter(1));
            ydot = round(scaleCenter(2) - innerRadius * sin(respAngle));
            Screen('DrawDots', w, [xdot; ydot], 20, [50 155 255], [], 1);
            
            Screen('TextSize', w, 32);
            priceStr = sprintf('Bid: $ %s', insertCommas(round(respPrice)));
            DrawFormattedText(w, priceStr, scaleCenter(1)-150, scaleCenter(2)+150, [50 155 255]);            if buttons(1)
                pricePaid = respPrice;
                pricingRT = GetSecs - t0;
                priceEntered = 1;
                
                % clear attributes when asked to price?
                % drawItemCard(w, leftRect, item, type, numAttrs, false, texStruct);
                Screen('Flip', w);
                WaitSecs(0.3);
            end
        end
        Screen('Flip', w);
        checkForQuit();
    end
end

%% ===================== DRAWING HELPER =====================

function drawItemCard(w, rect, itemData, type, numAttrs, highlight, houseTexStruct)
    Screen('FillRect', w, [30 30 30], rect);
    borderColor = [200 200 200]; borderWidth = 2;
    if highlight, borderColor = [255 215 0]; borderWidth = 6; end
    Screen('FrameRect', w, borderColor, rect, borderWidth);
    
    buffer = 20;
    cardWidth = rect(3) - rect(1);
    
    if strcmpi(type, 'house') && isstruct(houseTexStruct)
        imgW = (cardWidth - (4 * buffer)) / 3;
        imgH = 160;
        cats = {'ext','liv','bed','bath','out','kit'};
        for idx = 1:6
            col = mod(idx-1, 3); row = floor((idx-1) / 3);
            target = [rect(1)+buffer + col*(imgW+buffer), ...
                      rect(2)+buffer + row*(imgH+buffer), ...
                      rect(1)+buffer + col*(imgW+buffer) + imgW, ...
                      rect(2)+buffer + row*(imgH+buffer) + imgH];
            if isfield(houseTexStruct, cats{idx}) && ~isempty(houseTexStruct.(cats{idx}))
                Screen('DrawTexture', w, houseTexStruct.(cats{idx}), [], target);
            end
        end
        textY = rect(2) + (2 * imgH) + (4 * buffer);
    else
        textY = rect(2) + buffer*3;
    end
    
    Screen('TextSize', w, 32);
    labels = itemData.Properties.VariableNames;
    drawCount = min(numAttrs, length(labels));

    for i = 1:drawCount
        val = itemData.(labels{i});
        if iscell(val), val = val{1}; end
        
        rawLabel = strrep(labels{i}, '_', ' ');
        cleanLabel = regexprep(rawLabel, '(^.|(?<= ).)', '${upper($1)}');
        
        if contains(lower(labels{i}), 'price') || contains(lower(labels{i}), 'salary')
            valStr = ['$ ', insertCommas(round(val))];
        else
            if isnumeric(val), valStr = num2str(val); else, valStr = char(val); end
        end

        fullLine = sprintf('%s: %s', cleanLabel, valStr);
        linespacing = 80;
        DrawFormattedText(w, fullLine, 'center', textY + (i-1)*linespacing, [255 255 255], [], [], [], [], [], rect);
    end
end


%% ===================== UTILITY FUNCTIONS =====================

function cfg = setupCfg()
    cfg.paths.task = pwd;
    cfg.paths.data = fullfile(pwd, 'Data');
    cfg.paths.crashed=fullfile(cfg.paths.data, 'Crashes');
    cfg.paths.stim = fullfile(pwd, 'stimuli');
    cfg.paths.tobii = fullfile(pwd, '..', 'TobiiPro.SDK.Matlab_1.9.0.59');
end

function [tbl, cols] = loadStimTable(path)
    tbl = readtable(path);
    cols = tbl.Properties.VariableNames;
end

function allHouseTexs = loadHouseTextures(w, stimTbl, imgPath)
    numHouses = height(stimTbl);
    allHouseTexs = cell(numHouses, 1);
    
    categories = {'ext', 'kit', 'bed', 'bath', 'liv', 'out'};
    
    fprintf('Loading multi-view house images...\n');
    
    for i = 1:numHouses
        houseID = i;
        tempStruct = struct();
        
        for c = 1:length(categories)
            cat = categories{c};
            fileName = fullfile(imgPath, sprintf('%s%d.png', cat, houseID));
            
            if exist(fileName, 'file')
                imgData = imread(fileName);
                tempStruct.(cat) = Screen('MakeTexture', w, imgData);
            else
                tempStruct.(cat) = [];
                warning('Missing image: %s', fileName);
            end
        end
        allHouseTexs{i} = tempStruct;
    end
end

function checkForQuit()
    [keyIsDown, ~, keyCode] = KbCheck;
    if keyIsDown && keyCode(KbName('q'))
        Screen('CloseAll');
        error('User quit experiment.');
    end
end

function str = insertCommas(num)
    % Formats a number with commas (e.g., 1000000 -> 1,000,000)
    str = java.text.DecimalFormat('#,###').format(num);
end
