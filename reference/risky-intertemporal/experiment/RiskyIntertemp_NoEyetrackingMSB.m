    %%
% Design - choice, buy
% intertemp, risky, both - different days - see notes for more details
% so on each day they just do choice and price for one type (delay, risk,
% or both)

% experiment prep
sca;
clear;
PsychDefaultSetup(2);

% Eye tracker files path
% UPDATE -- add tobii files to path
% addpath(genpath('L:\Kvam Lab\TobiiPro.SDK.Matlab_1.9.0.59'));
% addpath(genpath('L:\Kvam Lab\RiskyIntertemporalEyetracking'));

% Eye tracker setup
% tobii = EyeTrackingOperations();
% found_eyetrackers = tobii.find_all_eyetrackers()
% my_eyetracker = found_eyetrackers(1)
% disp(["Address: ", my_eyetracker.Address])
% disp(["Model: ", my_eyetracker.Model])
% disp(["Name (It's OK if this is empty): ", my_eyetracker.Name])
% disp(["Serial number: ", my_eyetracker.SerialNumber])

tic

exp = struct( ...
    "subjectNumber", 1, ... %uint16(input("Participant #: ")), ...
    "sessionNumber", 1, ... %uint8(input("Session #: ")), ...
    "fileName", 'TBD', ...
    "shortName", 'TBD', ...
    "locations", zeros(6, 6, 4), ...
    "priceLocations", zeros(6, 3, 4), ...
    "varNames", [...
        "pID", "sessionNo", "isPractice", "blockNo", "blockType", "trialNo", ...
        "response", "rt", "price1", "price2", "prob1", "prob2", "delay1", "delay2"...
        ],...
    "condID", 0, ... 
    "nConds", 3, ...
    "blockNo", 1, ...
    "nBlocksEachCond", 2, ...
    "blockType", 2, ...
    "nSubBlocks", 6, ...
    "nPriceTrials", 84, ...
    "nChoiceTrials", 42, ...
    "nPracticeBlocks", 1, ...
    "nPracticeTrials", 8, ...
    "nScalePracticeTrials", 12, ...
    "trialCounter", 1, ...
    "trialNum", 1, ...
    "checkRate", 0.2, ... % mouse position updating
    "trialMaxDuration", 6000, ...
    "response", 0, ...
    "rt", 0, ...
    "t0", GetSecs, ...
    "choiceLabels", {{'$', '%', 'days', '$', '%', 'days'}} ...
);

% same randomly generate condList for everyone -- no need to load in csv.
rng(42);
condList = randi(exp.nSubBlocks, exp.subjectNumber, 1);
exp.condID = uint8(condList(end));
rng('shuffle')

exp.fileName  = [ ...
    'Data' filesep 'RIE' num2str(exp.subjectNumber) '_' ...
    char(datetime("now", Format="yyyyMMdd_HHmmSS")) ...
];
exp.shortName = [...
    'RIE' num2str(exp.subjectNumber) '-' num2str(exp.sessionNumber) ...
];

screenNum = max(Screen('Screens'));
colours.white   = WhiteIndex(screenNum); colours.black = BlackIndex(screenNum); colours.gray = colours.white / 2;
colours.green   = [55 255 55]; colours.red = [255 55 55];
colours.bg      = colours.black;
colours.font    = colours.white; 

Screen('Preference','SkipSyncTests', 1, 'Preference', 'SuppressAllWarning', 1);    %Change global setting for screen to ignore sync tests (sync to monitor refresh rate - avoid flickering), idk what 1 at the end does?
[window, rect] = PsychImaging('OpenWindow', screenNum, colours.bg);  %opens black rectangular window on the screen

screen = struct( ...
    "num", uint8(screenNum), ...
    "window", window, ...
    "rect", uint16(rect), ...
    "centerX", (rect(3) - rect(1)) / 2, ...
    "centerY", (rect(4) - rect(2)) / 2, ...
    "center", [0, 0], ...
    "nFrames", round(1 / Screen('GetFlipInterval', window)), ...
    "ifi", Screen('GetFlipInterval', window) ...
);
screen.center = [screen.centerX, screen.centerY];
clear screenNum window rect condList

Priority(MaxPriority(screen.window));
Screen('BlendFunction', screen.window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);  %allows new colors to be blended with previous colors on screen and defines color blending type?
Screen('Flip', screen.window, colours.bg);
Screen('TextSize', screen.window, 22);     % text size set to 22
Screen('TextStyle',screen.window, 1);     % text style (font?) set to 1, idk what 1 refers to?

ListenChar(2);      %records keystrokes but supresses input?
AssertOpenGL;       %checks if OpenGL graphics library is working?

data = struct( ...
    "subjectNumber", uint16(exp.subjectNumber), ...
    "sessionNumber", uint8(exp.sessionNumber), ...
    "startTime", GetSecs, ...
    "trials", array2table(zeros(...
        exp.nPracticeTrials + exp.nChoiceTrials + exp.nPriceTrials, length(exp.varNames)), ...
        VariableNames=exp.varNames), ...
    "mousePos", nan(exp.nPracticeTrials + exp.nChoiceTrials + exp.nPriceTrials, exp.trialMaxDuration * exp.checkRate, 2) ...
);

% Setup stimuli locations
halfX       = screen.centerX / 2;
hypDist     = sqrt(screen.centerY^2 + halfX^2);
midAdjust   = hypDist - halfX;

leftBot  = uint16([0.5 * screen.centerX, 0, screen.centerX, screen.centerY * 3]);
leftMid  = uint16([0.5 * screen.centerX - midAdjust, 0, screen.centerX, screen.centerY * 2]);
leftTop  = uint16([0.5 * screen.centerX, 0, screen.centerX, screen.centerY]);
rightBot = uint16([screen.centerX, 0, screen.centerX * 1.5, screen.centerY * 3]);
rightMid = uint16([screen.centerX, 0, screen.centerX * 1.5 + midAdjust, screen.centerY * 2]);
rightTop = uint16([screen.centerX, 0, screen.centerX * 1.5, screen.centerY]);

%LocationMatrix
%where {LocationMatrix{1, :}} === exp.locations(:, :, 1) - with the row values being the coords and the columns the positions.
exp.locations =  reshape([...
    leftTop,leftMid,leftBot,rightTop,rightMid,rightBot;...
    leftTop,leftBot,leftMid,rightTop,rightBot,rightMid;...
    leftMid,leftTop,leftBot,rightMid,rightTop,rightBot;...
    leftMid,leftBot,leftTop,rightMid,rightBot,rightTop;...
    leftBot,leftTop,leftMid,rightBot,rightTop,rightMid;...
    leftBot,leftMid,leftTop,rightBot,rightMid,rightTop ...
    ]', 4, 6, 6 ...
);

clear halfX hypDist midAdjust leftBot leftMid leftTop rightBot rightMid rightTop

quarterY  = 0.25 * screen.centerY;
quarterX  = 0.25 * screen.centerX;
hypDist   = sqrt(quarterX^2 + quarterY^2);
topAdjust = hypDist-quarterY;            

priceTop  = uint16([screen.centerX, 0, screen.centerX, screen.centerY * 1.75 - topAdjust]);
priceLeft = uint16([0.75 * screen.centerX, 0, screen.centerX, screen.centerY * 2.25]);
priceRight= uint16([screen.centerX, 0, screen.centerX * 1.25, screen.centerY * 2.25]);

%where {priceLocationMatrix{1, :}} === exp.priceLocations(:, :, 1) - with the row values being the coords and the columns the positions.
exp.priceLocations = reshape([ ...
    priceTop,priceLeft,priceRight;...
    priceTop,priceRight,priceLeft;...
    priceLeft,priceTop,priceRight;...
    priceLeft,priceRight,priceTop;...
    priceRight,priceTop,priceLeft;...
    priceRight,priceLeft,priceTop ...
    ]', 4, 6, 3 ...
);

clear quarterY quarterX hypDist topAdjust priceLeft priceTop priceRight

%% Gambles Moved down to subject counterbalancing to make sure everyone prices the same gambles

gambles = struct( ...
    "data", readmatrix('RIEgambles.csv', OutputType="uint8"), ...
    "order", 0, ...
    "counter", uint16(1), ...
    "pairs", readmatrix('RIEgamblepairs.csv', OutputType="uint8"), ...
    "pairOrder", 0, ...
    "pairCounter", uint16(1),...
    "nGamblePlays", uint8(1), ... % = 2 in payment
    "pay1", num2str(randi(20), '%.2f'), ...
    "pay2", num2str(randi(20), '%.2f'), ...
    "prob1",num2str(randi(100)),...
    "prob2",num2str(randi(100)),...
    "delay1",num2str(randi(250)),...
    "delay2",num2str(randi(250))...
);
gambles.order     = uint8(randperm(length(gambles.data)));
gambles.pairOrder = uint8(randperm(length(gambles.pairs)));

%% Types of trials
% Previously 1-3 Gains, 4-6 losses, ordered choice, buy, sell
% 1 = Both - Binary choice
% 2 = Both - Willingness to pay 
% 3 = Delay - Binary choice
% 4 = Delay - Willingness to pay 
% 5 = Risk - Binary choice
% 6 = Risk - Willingness to pay 

% 42 choice trials (6 blocks of 7)
% 84 pricing trials (6 blocks of 14)

if exp.subjectNumber == 9999       %I assume this is for testing purposes to avoid going through the whole thing?
    exp.nBlocksEachCond = 2;    
    exp.nTrialsPerBlock = 2;
    exp.nPracticeTrials = 2;
    exp.nScalePractice = 2;
end

if exp.sessionNumber == 1
    exp.eachCond = Shuffle([1 2]);
    if exp.condID == 3 || exp.condID == 4
        exp.eachCond = Shuffle([3 4]);
    elseif exp.condID == 5 || exp.condID == 6
        exp.eachCond = Shuffle([5 6]);
    end
elseif exp.sessionNumber == 2
    % condListID == 3 | condListID == 5
    exp.eachCond = Shuffle([1 2]);
    if exp.condID == 1 || exp.condID == 6
        exp.eachCond = Shuffle([3 4]);
    elseif exp.condID == 2 || exp.condID == 4
        exp.eachCond = Shuffle([5 6]);
    end
else
    % condListID == 4 | condListID == 6
    exp.eachCond = Shuffle([1 2]);
    if exp.condID == 2 || exp.condID == 5
        exp.eachCond = Shuffle([3 4]);
    elseif exp.condID == 1 || exp.condID == 3
        exp.eachCond = Shuffle([5 6]);
    end
end


%% Scale information
nMajorTicks     = 10;
nMinorTicks     = 20;
innerFract      = 0.8;
outerFract      = 0.85;
minorRadiusFract= 0.815; 
scale = struct( ...
    "max", nMinorTicks, ...
    "min", 0, ...
    "majorTicks", linspace(0, nMinorTicks, nMajorTicks+1), ...
    "minorTicks", linspace(0, nMinorTicks, nMinorTicks+1), ...
    "textRadius", 0.915, ...
    "numTicks", nMajorTicks + 1, ...
    "numMinorTicks", nMinorTicks, ...
    "innerRadius", innerFract * screen.centerY, ...
    "outerRadius", outerFract * screen.centerY, ...
    "minorRadius", minorRadiusFract * screen.centerY, ...
    "tickAngles", linspace(pi, 2*pi, nMajorTicks + 1), ...
    "minorTickAngles", linspace(pi, 2*pi, nMinorTicks + 1), ...
    "radialLines", zeros(2, (nMajorTicks+1) * 2), ...
    "minRadialLines", zeros(2, (nMinorTicks+1) * 2),...
    "textTick", {1:nMajorTicks},...
    "textLocX", 0:nMajorTicks,...
    "textLocY", 0:nMajorTicks ...
);
setTicks          = @(t) "$" + t;
[scale.textTick]  = setTicks(0:2:nMinorTicks);
for n = 1:scale.numTicks
    scale.radialLines(1,(n*2-1))= round(scale.innerRadius .* cos(scale.tickAngles(n)) + screen.center(1)); % inner x coordinate of tick
    scale.radialLines(2,(n*2-1))= round(scale.innerRadius .* sin(scale.tickAngles(n)) + screen.center(2)); % inner y coordinate
    scale.radialLines(1,(n*2))  = round(scale.outerRadius .* cos(scale.tickAngles(n)) + screen.center(1)); % outer x coordinate
    scale.radialLines(2,(n*2))  = round(scale.outerRadius .* sin(scale.tickAngles(n)) + screen.center(2)); % outer y coordinate
end
for n = 1:scale.numMinorTicks
    scale.minRadialLines(1,(n*2-1)) = round(scale.innerRadius .* cos(scale.minorTickAngles(n)) + screen.center(1)); % inner x coordinate of tick
    scale.minRadialLines(2,(n*2-1)) = round(scale.innerRadius .* sin(scale.minorTickAngles(n)) + screen.center(2)); % inner y coordinate
    scale.minRadialLines(1,(n*2))   = round(scale.minorRadius .* cos(scale.minorTickAngles(n)) + screen.center(1)); % outer x coordinate
    scale.minRadialLines(2,(n*2))   = round(scale.minorRadius .* sin(scale.minorTickAngles(n)) + screen.center(2)); % outer y coordinate
end

clear nMajorTicks nMinorTicks setTicks n innerFract outerFract minorRadiusFract

%% Instructions

% Slide 1
HideCursor();
DrawTxt(screen.window,...
    'Welcome! Please complete the informed consent statement, then click the left mouse button to begin the experiment.', ...
    screen.centerY - 50);
Screen('Flip', screen.window, colours.bg);

moveAlong
Screen('Flip', screen.window, colours.bg);
pause(.5);

% Slide 2
slide2_txt = {...
    'In this experiment, you will price lotteries as well as make decisions between pairs of lotteries. Each lottery consists of a payoff ($), a chance of winning (%), and a delay (days).',...
    ['45%\n' 'gain $14\n' '7 days'], ...
    'If you were to play this lottery, you would have a 45 in 100 chance of winning $14 after waiting 7 days, and a 55 in 100 chance of receiving $0.',...
    'On one day of this three session experiment, these lotteries will be like the example.',...
    'On one day every lottery will be certain (100% chance), and another day every lottery will be immediate (0 days).\n\n(Click the left mouse button to continue)', ...
};
for idx = 1:length(slide2_txt)
    yPos = 0.3 + (idx-1)*0.3;
    DrawTxt(screen.window, slide2_txt{idx}, screen.centerY*yPos);
end
Screen('Flip', screen.window, colours.bg);

moveAlong
Screen('Flip', screen.window, colours.bg);
pause(.5);

DrawFormattedText(screen.window, [...
    'Your tasks will be the following:\n\n',...
    '1) DECIDE between pairs of lotteries, indicating which you prefer\n\n',...
    '2) BUY / indicate how much a person might pay to play the lottery.'...
    ], 'center', screen.centerY*.4, colours.font, 120, 0, 0, 1.4);
DrawFormattedText(screen.window,[...
    'DECIDE and BUY are organized in blocks, so you only have to do one at a time\n',...
    '(Click the left mouse button to continue)'...
    ],'center', screen.centerY*1.7, colours.font, 80, 0, 0, 1.4);
Screen('Flip', screen.window, colours.bg);

moveAlong
Screen('Flip', screen.window, colours.bg);
pause(.5);

DrawTxt(screen.window, ...
    'To DECIDE, you will simply click the left or right mouse button according to which lottery you prefer (left or right).',...
    screen.centerY*.8);
DrawTxt(screen.window, ...
    'Try a few of these trials now. Click the left mouse button to see a pair of lotteries, then left or right depending which you prefer.',...
    screen.centerY*1.2);
Screen('Flip', screen.window, colours.bg);

moveAlong
Screen('Flip', screen.window, colours.bg);
pause(.5);

clear yPos idx slide2_txt

%% Choice practice
for w = 1:exp.nPracticeBlocks
    locations = exp.locations(:, :, randi(6, 1, 1))';
    for n = 1:(exp.nPracticeTrials/exp.nPracticeBlocks)
        DrawFormattedText(screen.window, '+', 'center', 'center', colours.font, 80, 0, 0, 1.4);
        DrawFormattedText(screen.window, '(Click on the + to start)', 'center', screen.centerY+150, colours.font ,80, 0, 0, 1.4);
        for idx = 1:length(exp.choiceLabels)
            DrawLocText(screen.window, exp.choiceLabels{idx}, locations(idx, :));
        end
        ShowCursor('Arrow');
        Screen('Flip', screen.window, colours.bg);

        clickTarget(screen.centerX, screen.centerY, 40)
        
        gambles.pay1    = num2str(randi(20), '%.2f');
        gambles.pay2    = num2str(randi(20), '%.2f');
        gambles.prob1   = num2str(randi(100));
        gambles.prob2   = num2str(randi(100));
        gambles.delay1  = num2str(randi(250)); 
        gambles.delay2  = num2str(randi(250)); 
        gamble_text = {...
            ['$' gambles.pay1], [gambles.prob1 '%'], [gambles.delay1 ' days'], ...
            ['$' gambles.pay2], [gambles.prob2 '%'], [gambles.delay2 ' days']};
        if any(exp.eachCond == [3, 4])
            [gamble_text{[3 6]}] = deal('0 days');
        elseif any(exp.eachCond == [5, 6])
            [gamble_text{[2 4]}] = deal('100%');
        end    
        for idx = 1:length(gamble_text)
            DrawLocText(screen.window, gamble_text{idx}, locations(idx, :));
        end
        Screen('Flip', screen.window, colours.bg);
        HideCursor();
        pause(.3);

        [exp.response, exp.rt] = getClickResponse(GetSecs);
        Screen('Flip', screen.window, colours.bg);
        pause(.5);
    end
end   

clear w idx txt_labels locations gamble_text
%% Rating Instructions

DrawFormattedText(screen.window,...
    'On BUY trials, you will enter the buying price using a scale like this one.',...
    'center',screen.centerY*1.3,colours.font, 80, 0, 0, 1.5);
DrawFormattedText(screen.window,[...
    'To respond using this scale, you just have to click on the desired dollar value along the semicircle\n\n', ...
    '(Next we''ll try using this scale to enter numbers. Click the left mouse button to continue.)'...
    ], 'center',screen.centerY*1.6,colours.font, 80, 0, 0, 1.5);

for n = 1:scale.numTicks
    scale.textLocX(n) = round(scale.textRadius * screen.center(2) * cos(scale.tickAngles(n)) + screen.center(1)) - 12; % specifies where on the x axis the $ text for each major tick appears
    scale.textLocY(n) = round(scale.textRadius * .95 * screen.center(2) * sin(scale.tickAngles(n)) + screen.center(2)); % specifies where on the y axis the $ text for each major tick appears
end

drawScale(screen.window, scale.textTick, scale.textLocX, scale.textLocY, colours.font, colours.bg, screen.center, scale.radialLines, scale.minRadialLines, scale.innerRadius);
ShowCursor('Arrow');
Screen('Flip', screen.window, colours.bg);

[exp.response, exp.rt] = getClickResponse(GetSecs);
Screen('Flip', screen.window, colours.bg);
pause(.3);

%% Practice trials

exp.trialCounter = 1;
while exp.trialCounter <= exp.nScalePracticeTrials
    DrawTxt(screen.window, '+', 'center');
    DrawTxt(screen.window, '(Click on the + to start)', screen.centerY+150);
    ShowCursor('Arrow');
    Screen('Flip', screen.window, colours.bg);

    clickTarget(screen.centerX, screen.centerY, 40)
    Screen('Flip', screen.window, colours.bg);
    pause(.3);

    findNum = rand*20; % does rand have a specfic range it pulls from?
    DrawFormattedText(screen.window,['Enter $',num2str(findNum,'%.2f'),' using the scale.\n\n (You do not need to be exact, just get close.)'],'center',screen.centerY*1.3,colours.font, 80, 0, 0, 1.5);
    drawScale(screen.window, scale.textTick, scale.textLocX, scale.textLocY, colours.font, colours.bg, screen.center, scale.radialLines, scale.minRadialLines, scale.innerRadius);
    Screen('Flip', screen.window, colours.bg);
    ShowCursor('Arrow');
    click = 0;
    exp.t0 = GetSecs; % before or after the above flip-pause?
    while click == 0
        [xMouse, yMouse, buttons] = GetMouse;
        xDist   = xMouse - screen.center(1); % distance of mouse from center of x axis
        yDist   = screen.center(2) - yMouse; % distance of mouse from center of y axis
        rMouse  = sqrt(xDist^2 + yDist^2); % distance of mouse from true center (radius from the center)
        thMouse = atan2(abs(yDist),xDist); % is this the angle of the mouse from the center?
        if rMouse >= scale.innerRadius % if mouse is positioned at or beyond the inner radius of the arc
            exp.response = ((scale.max - scale.min) - (scale.max-scale.min)*thMouse/pi) + scale.min; % determines value ($) of mouse position on or beyond arc
            DrawFormattedText(screen.window,['$',num2str(exp.response,'%.2f')],'center',screen.centerY*.8, colours.font, 80, 0, 0, 1.5, 0, [0,0,screen.centerX*2,screen.centerY*2]); %displays text for $ amount of current mouse position
            if any(buttons) % if any buttons clicked
                exp.rt = GetSecs - exp.t0; % RT for choice -- was not previously defined here.
                click = 1;
                if abs(exp.response - findNum) < .15
                    DrawFormattedText(screen.window,'Good!','center','center',colours.green, 80, 0, 0, 1.5);
                    exp.trialCounter = exp.trialCounter + 1;
                else
                    DrawFormattedText(screen.window,'Try to get closer.','center','center',colours.red,80,0,0,1.5);
                end
            end
        end
    end

    data.sPractice(exp.trialCounter).response = exp.response; % stores choice in data matrix
    data.sPractice(exp.trialCounter).rt = exp.rt; % stores RT in data matrix
    Screen('Flip', screen.window, colours.bg); 
    pause(2.3); % 2.3s ITI
end

pause(1);
DrawFormattedText(screen.window,'Click the left mouse button to begin the experiment.','center',screen.centerY*1.6, colours.font, 80, 0, 0, 1.5);
Screen('Flip', screen.window, colours.bg);

moveAlong;
Screen('Flip', screen.window, colours.bg);
pause(.5);

clear click xMouse yMouse buttons xDist yDist rMouse thMouse 

%% Main loop

%bN
for blockNo = 1:exp.nBlocksEachCond % repeat loop for the number of blocks
    pause(.5);
    exp.blockType = 2; % draws from column 1 of condOrder to determine block type
    %isSpeed = eachCond(condOrder(bN),2);  % draws from column 2 of condOrder to determine if block is speed (else precision)
    
    % 1 = Binary choice gains
    % 2 = Willingness to pay gains (WTP)
    % 3 = Willingness to accept gains (WTA)
    % 4 = Binary choice losses
    % 5 = Willingness to pay losses (WTP)
    % 6 = Willingness to accept losses (WTA)
   
    instrTxt = 'The following are DECIDE trials. Click the right mouse button for a chance to obtain the option on the right, or the left mouse button for a chance to obtain the one on the left.';
    
    if any([2 4 6] == exp.blockType)
        instTxt = 'The following are BUY trials. Specify how much you might pay to play the lottery.';
    end
    DrawFormattedText(screen.window, instrTxt, 'center', centerY-50, colours.bg, 80, 0, 0, 1.4);
    DrawTxt(screen.window, 'Click the left mouse button to continue.', screen.centerY+200);
    Screen('Flip', screen.window, colours.bg);
    moveAlong;
    pause(.3);
    
    exp.nTrials = round(exp.nPriceTrials/6);
    if any([1 3 5] == exp.blockType)
        exp.nTrials = round(nChoiceTrials/6);
    end
    orderInd = randperm(6);
    for w = 1:exp.nSubBlocks
        Order = orderInd(w);
        locations = exp.locations(:, :, Order,:)';
        priceLocations = exp.priceLocations(:, :, Order)';
        for tN = 1:exp.nTrials
            data.trial(exp.trialNum).type = exp.blockType; % record block type for subsequent trials
            %% Fixation
            DrawTxt(screen.window, '+', 'center');
            if any([1 3 5] == exp.blockType)
                DrawFormattedText(screen.window, 'DECIDE', 'center', centerY + 100, colours.font, 80, 0, 0, 1.4);
                for idx = 1:length(exp.choiceLabels)
                    DrawLocText(screen.window, exp.choiceLabels{idx}, locations(idx, :));
                end
            else
                DrawFormattedText(screen.window, 'BUY', 'center', centerY + 100, colours.font, 80, 0, 0, 1.4);
                for idx = 1:length(exp.choiceLabels)/2
                    DrawLocText(screen.window, exp.choiceLabels{idx}, locations(idx, :));
                end
            end
            ShowCursor('Arrow');
            Screen('Flip', screen.window, 0, 0);
            clickTarget(screen.centerX, screen.centerY, 40);
            Screen('Flip', screen.window, colours.bg);
            pause(.3);
            
            %% Trial
            if any([1 3 5] == blockType)
                gpIndex = gPairOrder(nGP);
                data.trial(trialNum).gambleNum = gpIndex;
                nGP = nGP + 1;
                [gambles.pay1, gambles.delay1, gambles.prob1,...
                 gambles.pay2, gambles.delay2, gambles.prob2 ...
                ] = getGambles(gambles, nGP, 0.5);

                DrawFormattedText(screen.window,['$',num2str(gambles.pay1,'%.2f')], 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, locations(1, :)); % draws left stimulus
                DrawFormattedText(screen.window,['$',num2str(gambles.pay2,'%.2f')], 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, locations(4, :)); % draws left stimulus
                if blockType == 5
                    DrawFormattedText(screen.window,'100%', 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, locations(2,:)); % draws right stimulus
                    DrawFormattedText(screen.window,'100%', 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, locations(5,:)); % draws right stimulus
                else % variable in blockTypes 1 and 3
                    DrawFormattedText(screen.window,[num2str(gambles.prob1),'%'], 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, locations(2, :)); % draws right stimulus
                    DrawFormattedText(screen.window,[num2str(gambles.prob2),'%'], 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, locations(5, :)); % draws right stimulus
                end
                if blockType == 3
                    DrawFormattedText(screen.window,'0 days', 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, locations(3, :)); % draws right stimulus
                    DrawFormattedText(screen.window,'0 days', 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, locations(6, :)); % draws right stimulus
                else % variable in blockTypes 1 and 5
                    DrawFormattedText(screen.window,[num2str(gambles.delay1),' days'], 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, locations(3, :)); % draws right stimulus
                    DrawFormattedText(screen.window,[num2str(gambles.delay2),' days'], 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, locations(6, :)); % draws right stimulus
                end
                Screen('Flip', screen.window, colours.bg);
                
                exp.t0 = GetSecs; % real-time at start of trial
                HideCursor();
                
                %%% start eyetracking
                my_eyetracker.get_gaze_data();
                click = 0;
                while click == 0
                    [xMouse, yMouse, buttons] = GetMouse;
                    if buttons(1) || buttons(3)
                        thisRT = GetSecs - exp.t0;
                        %%% stop eye tracking
                        gaze_data = my_eyetracker.get_gaze_data();
                        data.trial(trialNum).gazeData = gaze_data;
                        my_eyetracker.stop_gaze_data()
                        %%%
                        if buttons(1)
                            click = -1; % participant clicked left
                        elseif buttons(3)
                            click = 1; % participant clicked right
                        end
                    end
                end
                
                Screen('Flip', screen.window, colours.bg);
                pause(.3);

                data.trial(trialNum).typeText = 'choice'; % records choice trial type
                data.trial(trialNum).type = blockType; % numerical code for choice trial
                if blockType == 1
                    %% Binary gambles (+)
                    data.trial(trialNum).typeText2 = 'both'; % records gain trial type
                elseif blockType == 3
                    %% Binary gambles risk
                    data.trial(trialNum).typeText2 = 'risk'; % records loss trial type
                elseif blockType == 5
                    %% Binary gambles delay
                    data.trial(trialNum).typeText2 = 'delay'; % records loss trial type
                end
                data.trial(trialNum).resp = click; %records left/right choice
                data.trial(trialNum).rt = thisRT; %records RT
                data.trial(trialNum).stim = [gambles.pay1,gambles.prob1,gambles.delay1,gambles.pay2,gambles.prob2,gambles.delay2]; %records choice stimuli
                data.trial(trialNum).traj = []; %records nothing for mouse trajectory, because there isn't anything to track
                % data.trial(trialNum).isSpeed = isSpeed; %records speed condition
                data.trial(trialNum).blockNum = bN; %records block number
                data.trial(trialNum).trialInBlock = tN; % records trial number

            else
                gIndex = gambleOrder(nG); % gIndex = randomized gambles with counter
                nG = nG + 1; % interates counter each loop
                data.trial(trialNum).gambleNum = gIndex; % records gIndex for each trial, tracks trialnumber within block
                gamblePay = gambles(gIndex,1);
                gambleDelay = gambles(gIndex,2);
                gambleProb = gambles(gIndex,3);

                %exp.checkRate = 0.2 is how often you update the mouse position.  multiply this by maxTrialDuration.
                traj = nan(100, 2); % starts mouse trajectory at x=0, y=0 -- estimating preallocation. You might be able to compute better guesses based off update rates and max trial duration.
                updateCounter = 1;
                
                DrawFormattedText(screen.window,['$',num2str(gamblePay,'%.2f')], 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, priceLocations(1,:)); % draws left stimulus
                if blockType == 4
                    DrawFormattedText(screen.window,'0 days', 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, priceLocations(3,:)); % draws right stimulus
                else
                    DrawFormattedText(screen.window,[num2str(gambleDelay),' days'], 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, priceLocations(3,:)); % draws right stimulus
                end
                if blockType == 6
                    DrawFormattedText(screen.window,'100%', 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, priceLocations(2, :)); % draws right stimulus
                else
                    DrawFormattedText(screen.window,[num2str(gambleProb),'%'], 'center', 'center',colours.font, 80, 0, 0, 1.5, 0, priceLocations(2,:)); % draws right stimulus
                end
        
                %DrawFormattedText(screen.window,[num2str(gambleProb),'%','\n','gain $',num2str(gamblePay,'%.2f'),'\n',num2str(gambleDelay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, [0, 200, centerX*2, centerY*2]);
                DrawFormattedText(screen.window,'What price would you PAY to play this lottery?','center','center',colours.font, 80, 0, 0, 1.5, 0, [0,screen.centerY,screen.centerX*2,screen.centerY*2]);
                drawScale(screen.window, scale.textTick, scale.textLocX, scale.textLocY, colours.font, colours.bg, screen.center, scale.radialLines, scale.minRadialLines, scale.innerRadius);
                ShowCursor('Arrow');
                click = 0;
                exp.t0 = GetSecs; % real-time at start of trial
                Screen('Flip', screen.window, colours.bg);
                lastCheck = exp.t0; % lastCheck = real-time at start of trial
                while click == 0
                    [xMouse, yMouse, buttons] = GetMouse;
                    xDist = xMouse - screen.center(1);
                    yDist = screen.center(2) - yMouse;
                    rMouse = sqrt(xDist^2 + yDist^2);
                    thMouse = atan2(abs(yDist),xDist);
                    if GetSecs - lastCheck > exp.checkRate % if current time - start of trial (lastCheck) is > .2 (mouse checkRate)
                        traj(updateCounter, :) = [xDist, yDist]; % records mouse trajectory
                        lastCheck = GetSecs; % refreshes lastCheck to current time
                    end
                    
                    if rMouse >= scale.innerRadius % if radius of mouse is at or beyond the inner radius of arc
                        resp = ((scale.max - scale.min) - (scale.max-scale.min)*thMouse/pi) + scale.min; % determines value ($) of mouse position on or beyond arc
                        DrawFormattedText(screen.window,['Response: \n $',num2str(round(resp*100)/100,'%.2f')],'center',screen.centerY*.8,[.5 .5 .5], 80, 0, 0, 1.5, 0, [0,0,screen.centerX*2,screen.centerY*2]);
                        if any(buttons) 
                            thisRT = GetSecs - t0; %records RT for choice
                            %%% stop eye tracking
                            % gaze_data = my_eyetracker.get_gaze_data();
                            % data.trial(trialNum).gazeData = gaze_data;
                            % my_eyetracker.stop_gaze_data()
                            %%%
                            click = 1;
                        end
                    end
                    updateCounter = updateCounter + 1;
                end
                
                Screen('Flip', screen.window, colours.bg);
                pause(.3);
                
                data.trial(trialNum).typeText = 'price'; % records WTP trial type
                data.trial(trialNum).type = blockType; % numerical code for WTP trial
                if blockType == 2
                    %% Willingness to pay (buying) (+)
                    data.trial(trialNum).typeText2 = 'both'; % records gain trial type
                elseif blockType == 4
                    %% Willingness to pay (buying)(-)
                    data.trial(trialNum).typeText2 = 'risk'; % records loss trial type
                elseif blockType == 6
                    %% Willingness to accept (selling) (-)
                    data.trial(trialNum).typeText2 = 'delay'; % records loss trial type
                end
                
                data.trial(trialNum).resp = resp; %records left/right choice
                data.trial(trialNum).rt = thisRT; %records RT
                data.trial(trialNum).stim = [gamblePay,gambleProb,gambleDelay]; %records choice stimuli
                data.trial(trialNum).traj = traj; %records mouse trajectory (how does it know? [] shouldn't provide any information?)
                %data.trial(trialNum).isSpeed = isSpeed; %records speed condition
                data.trial(trialNum).blockNum = bN; %records block number
                data.trial(trialNum).trialInBlock = tN; % records trial number
            end
            save(exp.fileName,'data'); % saves data from the trial to exp.fileName
            save(exp.shortName,'data'); % saves data from the trial to exp.shortName
            trialNum = trialNum + 1; % increments trialNum
        end        
    end
end

%% Task end

DrawFormattedText(screen.window,'You are all done with this session of the experiment! Please inform the experimenter.','center',centerY,[255 255 255], 80, 0, 0, 1.5);
Screen('Flip', screen.window, colours.bg);
pause(2);

moveAlong;

toc % read elapsed time from stopwatch (total session time)
ListenChar(0); % turns off keystroke recording and clears buffer
sca; %Screen('CloseAll'); % close screens

rMax = length(data.trial); % rMax = total number of trials
rSet = 1:rMax; % rSet = vector of all trials

%% Payment
disp(['Sampling ',num2str(nGamblePlays),' lotteries...']) % display value of 2 gambles (displays in command window?)

trialIndices = datasample(rSet,nGamblePlays); % pulls 1 trials from the rSet list
for m = 1:nGamblePlays 
    tgPlay = trialIndices(m); % determines which gambles were pulled
    tgSpeed = data.trial(tgPlay).isSpeed; % determines if pulled gambles were speed trials
    
    if tgSpeed == 1
        if rand > .75 %% sometimes resample if speed trial is draw (makes precision more likely)
            tgPlay = datasample(rSet,1); % redraws one trial
            disp('Resampling trials to give more precision trials...')
        end
    end
    
    tgSpeed = data.trial(tgPlay).isSpeed; % records trial information
    tgType = data.trial(tgPlay).type;
    tgResp = data.trial(tgPlay).resp;
    tgStim = data.trial(tgPlay).stim;
    ev = (tgStim(1)*tgStim(2)/100)/(1+(.01*tgStim(3))); 
    tgRT = data.trial(tgPlay).rt;
    
    disp('    ')
    
    if tgSpeed == 1
        disp(['Lottery #',num2str(m),': SPEED trial'])
        if (tgRT < 7.5 && tgType == 2 || tgType == 3 || tgType == 5 || tgType == 6) || (tgRT < 3.5 && tgType == 1 || tgType == 4) % if price, determines if RT was <5s, if choice, determines if RT was <2s #UPDATED
            disp('++ YOU COMPLETED THE TRIAL IN TIME! BONUS +$2 ++')
            data.lotteryPlayed(m).speedBonus = 1; % records bonus from speed trial
        else
            disp('-- YOU DID NOT COMPLETE THE TRIAL IN TIME - NO BONUS. --')
            data.lotteryPlayed(m).speedBonus = 0; % records no bonus from speed trial
        end
    else
        disp(['Lottery #',num2str(m),': PRECISION trial']);
        data.lotteryPlayed(m).speedBonus = []; % records blank for speed bonus (precision trial, no bonus)
    end
        
    data.lotteryPlayed(m).type = tgType;
    data.lotteryPlayed(m).resp = tgResp;
    data.lotteryPlayed(m).stim = tgStim;
    data.lotteryPlayed(m).EV = ev;
    data.lotteryPlayed(m).isSpeed = tgSpeed;
    
    
    if tgType == 1 % choice (+)
        if tgResp == 1
            disp(['You chose a lottery with ',num2str(tgStim(5),'%.0f'),'% chance of gaining $',num2str(tgStim(4),'%.2f'),' after a delay of ',num2str(tgStim(6)),' days','.'])
            disp('++++ YOU WILL PLAY THIS LOTTERY ++++'); % where do they do the "playing" of this lottery? Does it occur outside of this script?
        else
            disp(['You chose a lottery with ',num2str(tgStim(2),'%.0f'),'% chance of gaining $',num2str(tgStim(1),'%.2f'),' after a delay of ',num2str(tgStim(3)),' days','.'])
            disp('++++ YOU WILL PLAY THIS LOTTERY ++++');
        end
        data.lotteryPlayed(m).wasAccepted = 1;
        data.lotteryPlayed(m).typeString = 'Choice gain';
    elseif tgType == 2 % buying (+)
        disp(['You bid $',num2str(tgResp,'%.2f'),' to obtain a lottery with ',num2str(tgStim(2),'%.0f'),'% chance of gaining $',num2str(tgStim(1),'%.2f'),' after a delay of ',num2str(tgStim(3)),' days','.'])
        if tgResp < min(3,ev/3) % if price was < ev/3 or 3 (whichever is lower) 
            disp('---- THIS BID WAS REJECTED FOR BEING TOO LOW, YOU WILL KEEP THE MONEY YOU OFFERED FOR IT ----');
            data.lotteryPlayed(m).wasAccepted = 0;
        else
            disp('++++ THIS BID WAS ACCEPTED, YOU WILL PLAY THIS LOTTERY ++++')
            data.lotteryPlayed(m).wasAccepted = 1;
        end
        data.lotteryPlayed(m).typeString = 'Buying gain';
    elseif tgType == 3 % selling (+)
        disp(['You asked for $',num2str(tgResp,'%.2f'),' to sell a lottery with ',num2str(tgStim(2),'%.0f'),'% chance of gaining $',num2str(tgStim(1),'%.2f'),' after a delay of ',num2str(tgStim(3)),' days','.'])
        if tgResp > min(tgStim(1),1.5*ev) % if price was higher than the payout or 1.5*ev (whichever is lowest)
            disp('---- THIS PRICE WAS REJECTED FOR BEING TOO HIGH, YOU WILL KEEP (PLAY) THIS LOTTERY ----')
            data.lotteryPlayed(m).wasAccepted = 0;
        else
            disp('++++ THIS PRICE WAS ACCEPTED, YOU WILL RECEIVE THE REQUESTED PRICE FOR THE LOTTERY ++++')
            data.lotteryPlayed(m).wasAccepted = 1;
        end
        data.lotteryPlayed(m).typeString = 'Selling gain';
    elseif tgType == 4 % choice (-)
        if tgResp == 1
            disp(['You chose a lottery with ',num2str(tgStim(5),'%.0f'),'% chance of losing $',num2str(tgStim(4),'%.2f'),' after a delay of ',num2str(tgStim(6)),' days','.'])
            disp('++++ YOU WILL PLAY THIS LOTTERY ++++'); % where do they do the "playing" of this lottery? Does it occur outside of this script?
        else
            disp(['You chose a lottery with ',num2str(tgStim(2),'%.0f'),'% chance of losing $',num2str(tgStim(1),'%.2f'),' after a delay of ',num2str(tgStim(3)),' days','.'])
            disp('++++ YOU WILL PLAY THIS LOTTERY ++++');
        end
        data.lotteryPlayed(m).wasAccepted = 1;
        data.lotteryPlayed(m).typeString = 'Choice loss';
    elseif tgType == 5 % buying (-)
        disp(['You bid $',num2str(tgResp,'%.2f'),' to avoid a chance to lose a lottery with ',num2str(tgStim(2),'%.0f'),'% chance of losing $',num2str(tgStim(1),'%.2f'),' after a delay of ',num2str(tgStim(3)),' days','.'])
        if tgResp < min(3,ev/3) % if price was < ev/3 or 3 (whichever is lower) 
            disp('---- THIS BID WAS REJECTED FOR BEING TOO LOW, YOU WILL KEEP THE MONEY YOU OFFERED FOR IT AND PLAY THIS LOTTERY ----');
            data.lotteryPlayed(m).wasAccepted = 0;
        else
            disp('++++ THIS BID WAS ACCEPTED, YOU AVOIDED PLAYING THIS LOTTERY ++++')
            data.lotteryPlayed(m).wasAccepted = 1;
        end
        data.lotteryPlayed(m).typeString = 'Buying loss';
    else % selling  (-)
        disp(['You asked for $',num2str(tgResp,'%.2f'),' to take on the chance to lose lottery with ',num2str(tgStim(2),'%.0f'),'% chance of losing $',num2str(tgStim(1),'%.2f'),' after a delay of ',num2str(tgStim(3)),' days','.'])
        if tgResp > min(tgStim(1),1.5*ev) % if price was higher than the payout or 1.5*ev (whichever is lowest)
            disp('---- THIS PRICE WAS REJECTED FOR BEING TOO HIGH, YOU WILL NOT PLAY THIS LOTTERY ----')
            data.lotteryPlayed(m).wasAccepted = 0;
        else
            disp('++++ THIS PRICE WAS ACCEPTED, YOU WILL RECEIVE THE REQUESTED PRICE FOR THE LOTTERY AND PLAY THIS LOTTERY ++++')
            data.lotteryPlayed(m).wasAccepted = 1;
        end
        data.lotteryPlayed(m).typeString = 'Selling loss';
    end
end

save(exp.fileName,'data'); % save data to exp.fileName
save(exp.shortName,'data'); % save data to exp.shortName

%% functions

function DrawLocText(win, txt, location)
    sx          = 'center';
    sy          = 'center';
    colour      = [255 255 255];
    wrapat      = 80;
    flipHorz    = 0;
    flipVert    = 0;
    vSpacing    = 1.5;
    right2left  = 0;
    DrawFormattedText(win, txt, sx, sy, colour, wrapat, flipHorz, flipVert, vSpacing, right2left, double(location));
end

function DrawTxt(win, txt, yPos)
    sx          = 'center';
    sy          = yPos;
    colour      = [255 255 255];
    wrapat      = 80;
    flipHorz    = 0;
    flipVert    = 0;
    vSpacing    = 1.5;
    right2left  = 0;
    DrawFormattedText(win, txt, sx, sy, colour, wrapat, flipHorz, flipVert, vSpacing, right2left);
end

function moveAlong
    progress = false;
    while ~progress
        [~,~,buttons] = GetMouse;
        if any(buttons)
            progress = true;
        end
    end
end

function [response, rt] = getClickResponse(t0)
    response= 0;
    rt      = 0;
    while response == 0
        [~, ~, buttons] = GetMouse;
        if buttons(1) || buttons (3)
            rt = GetSecs - t0;
            response = 1;
            if buttons(1)
                response = -response;
            end
        end
    end
end

function clickTarget(targetX, targetY, pixelBuffer)
    clicked = false;
    while ~clicked
        [x, y, buttons] = GetMouse;
        if any(buttons) && abs(x - targetX) <= pixelBuffer && abs(y - targetY) <= pixelBuffer
            clicked = true;
        end
    end
end

function drawScale(win, textTicks, xLoc, yLoc, font_colour, bg_colour, center, radialLines, minRadialLines, innerRadius)
    for n = 1:length(textTicks)
        Screen('DrawText', win, textTicks{n}, xLoc(n), yLoc(n), font_colour, bg_colour, center(2));
    end
    Screen('DrawLines', win, radialLines, 3, font_colour);
    Screen('DrawLines', win, minRadialLines, 2, font_colour);
    Screen('FrameArc', win, font_colour, [center(1)-innerRadius, center(2)-innerRadius, center(1)+innerRadius, center(2)+innerRadius], 270, 180, 5, 5);
end


function [pay1, delay1, prob1, pay2, delay2, prob2] = getGambles(gambleData, idx, rnd_benchmark) 
    gpIndex = gambleData.pairOrder(idx);
    if rand > rnd_benchmark
        pay1    = gPairs(gpIndex,1);
        delay1  = gPairs(gpIndex,2);
        prob1   = gPairs(gpIndex,3);
        pay2    = gPairs(gpIndex,4);
        delay2  = gPairs(gpIndex,5);
        prob2   = gPairs(gpIndex,6);
    else
        pay1    = gPairs(gpIndex,4);
        delay1  = gPairs(gpIndex,5);
        prob1   = gPairs(gpIndex,6);
        pay2    = gPairs(gpIndex,1);
        delay2  = gPairs(gpIndex,2);
        prob2   = gPairs(gpIndex,3);
    end
end
