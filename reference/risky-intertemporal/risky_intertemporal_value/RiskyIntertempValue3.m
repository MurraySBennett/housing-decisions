%% experiment prep

clear;   % clears all vars from workspace, idk how it differs from clearvars

tic     % starts stopwatch timer

Screen('Preference','SkipSyncTests', 1);    %Change global setting for screen to ignore sync tests (sync to monitor refresh rate - avoid flickering), idk what 1 at the end does?
Screen('Preference', 'SuppressAllWarnings', 1);     %Change global setting for screen to not display warnings, idk what 1 does?

subjectNum = input('Subject ID: ');     %creates subjectNum variable, prompts subject to input ID
sessionNum = input('Session #: ');      %%creates sessionNum variable, prompts subject to input session

s = rng('shuffle');     %creates s variable, seeds random number generator based on the current time

dataMat = struct; % structure for storing data
dataMat.randomSeed = s;     % adds randomSeed = s to data array
dataMat.SubjectNumber = subjectNum;     % adds SubjectNumber = subjectNum to data array
dataMat.SessionNumber = sessionNum;     % adds SessionNumber = sessionNum to data array

fileName = strcat('Data\RIV',num2str(subjectNum),'_',datestr(now, 'yyyymmdd_HHMMSS'));      %creates fileName variable, concatenate string
shortName = strcat('RIV',num2str(subjectNum),'-',num2str(sessionNum));      %creates shortName variable, concatenate string

startTime = GetSecs;    %creates startTime variable, records real-time start

[window, ScreenRect] = Screen('OpenWindow', 0, 0);  %opens black rectangular window on the screen
centerX = (ScreenRect(3) - ScreenRect(1))/2;    %creates centerX variable at the center of the screen's X axis
centerY = (ScreenRect(4) - ScreenRect(2))/2;    %creates centerY variable at the center of the screen's Y axis
center = [centerX centerY];     %creates center varible with values from the center of the x and y axes
Screen('BlendFunction', window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);  %allows new colors to be blended with previous colors on screen and defines color blending type?
Screen('Flip', window, 0, 0); % update the window
Screen('TextSize', window, 22);     % text size set to 22
Screen('TextStyle',window,[1]);     % text style (font?) set to 1, idk what 1 refers to?

ListenChar(2);      %records keystrokes but supresses input?
AssertOpenGL;       %checks if OpenGL graphics library is working?

dataMat.startTime = startTime;  %adds startTime = startTime to data array

nGamblePlays = 1;  %creates nGamblePlays variable = 2 for use in payment

%% Gambles Moved down to subject counterbalancing to make sure everyone prices the same gambles
gambles = csvread('RIVgambles.csv'); % creates gambles variable with data imported from gambles csv file
gambleOrder = [randperm(length(gambles)),randperm(length(gambles)),randperm(length(gambles)),randperm(length(gambles))];  %changed from repeating 3 times to 2 %creates gambleOrder variable with the gambles randomly suffled, idk why 3 times?
nG = 1; % counter tracking the index of the current gamble

gPairs = csvread('RIVgamblepairs.csv'); % creates gPairs variable with data imported from gamblepairs csv file
gPairOrder = [randperm(length(gPairs)),randperm(length(gPairs))];  %creates gPairOrder variable with the gamblepairs randomly suffled, idk why listed twice?
nGP = 1; % counter tracking the index of the current gamble pair

%% Types of trials
% 1 = Binary choice gains
% 2 = Willingness to pay gains (WTP)
% 3 = Willingness to accept gains (WTA)
% 4 = Binary choice losses
% 5 = Willingness to pay losses (WTP)
% 6 = Willingness to accept losses (WTA)

trialTypes = [1 2 3 4 5 6];     %creates trialTypes vector

nConds = length(trialTypes) / 2;   %EDITED %nConds var, length = trialTypes
nBlocksEachCond = 2;        %UPDATE to 4? 4 blocks per condition (gains/losses * speed/precision)
nTrialsPerPriceBlock = 50;       %was nTrialsPerBlock = 50; 
nTrialsPerChoiceBlock = 25;

nPractice = 8;      %8 practice trials
nScalePractice = 12;    %UPDATE THIS TO 12 scale practice trials

if subjectNum == 9999       %I assume this is for testing purposes to avoid going through the whole thing?
    nBlocksEachCond = 2;    
    nTrialsPerBlock = 2;
    nPractice = 2;
    nScalePractice = 2;
end


nBlocks = nConds * nBlocksEachCond;% + 2; %specify number of blocks, does +2 here make it repeat twice for each block to get data for speed and precision conditions?
nTrials = nBlocks * (2/3) * nTrialsPerPriceBlock + nBlocks * (1/3) * nTrialsPerChoiceBlock; %specify number of trials

trialNum = 1;  %create trialNum var, starts at 1

condOrder = randperm(nBlocks);  %randomly shuffles all blocks


if rem(subjectNum, 2) == 1 % if subject number is odd
    if sessionNum == 1
        
        eachCond = [1,1;1,0;2,1;2,0;3,1;3,0];
        %gambles = csvread('RIVgambles.csv',40,0); % creates gambles variable with data imported from gambles csv file
        %blockGambles = [randperm(length(gPairs)); ...  %randomly shuffles gambles and gamblepairs, not sure what is going on here
         %   randperm(length(gPairs));...
          %  randperm(length(gambles)/2);...
           % randperm(length(gambles)/2)+length(gambles)/2;...
            %randperm(length(gambles)/2);...
            %randperm(length(gambles)/2)+length(gambles)/2];
            
    elseif sessionNum == 2    
        
        eachCond = [4,1;4,0;5,1;5,0;6,1;6,0];
        %gambles = csvread('RIVgambles.csv',0,0,[0,0,39,2]);
        %blockGambles = [randperm(length(gPairs)); ...  %randomly shuffles gambles and gamblepairs, not sure what is going on here
         %   randperm(length(gPairs));...
         %   randperm(length(gambles)/2);...
         %   randperm(length(gambles)/2)+length(gambles)/2;...
         %   randperm(length(gambles)/2);...
         %   randperm(length(gambles)/2)+length(gambles)/2];
         
    elseif sessionNum == 3
        
        eachCond = [1,1;1,0;2,1;2,0;3,1;3,0];
        %gambles = csvread('RIVgambles.csv',40,0);
        
    else
        
        eachCond = [4,1;4,0;5,1;5,0;6,1;6,0];
        %gambles = csvread('RIVgambles.csv',0,0,[0,0,39,2]);
    end
else % if subject number is even
    if sessionNum == 1
        
        eachCond = [4,1;4,0;5,1;5,0;6,1;6,0];
        %gambles = csvread('RIVgambles.csv',40,0);%not sure what is going on here
        %blockGambles = [randperm(length(gPairs)); ...  %randomly shuffles gambles and gamblepairs, not sure what is going on here
        %    randperm(length(gPairs));...
        %    randperm(length(gambles)/2);...
        %    randperm(length(gambles)/2)+length(gambles)/2;...
        %    randperm(length(gambles)/2);...
        %    randperm(length(gambles)/2)+length(gambles)/2];
        
    elseif sessionNum == 2
        eachCond = [1,1;1,0;2,1;2,0;3,1;3,0];
        %gambles = csvread('RIVgambles.csv',0,0,[0,0,39,2]);%not sure what is going on here
       % blockGambles = [randperm(length(gPairs)); ...  %randomly shuffles gambles and gamblepairs, not sure what is going on here
       %     randperm(length(gPairs));...
       %     randperm(length(gambles)/2);...
       %     randperm(length(gambles)/2)+length(gambles)/2;...
       %     randperm(length(gambles)/2);...
       %     randperm(length(gambles)/2)+length(gambles)/2];
       
    elseif sessionNum == 3
        
        eachCond = [4,1;4,0;5,1;5,0;6,1;6,0];
        %gambles = csvread('RIVgambles.csv',40,0);
        
    else
        
        eachCond = [1,1;1,0;2,1;2,0;3,1;3,0];
        %gambles = csvread('RIVgambles.csv',0,0,[0,0,39,2]);
    end
end

%gambleOrder = [randperm(length(gambles)),randperm(length(gambles))];  %changed from repeating 3 times to 2 %creates gambleOrder variable with the gambles randomly suffled, idk why 3 times?
%nG = 1; % counter tracking the index of the current gamble
%UPDATE THIS SECTION - is it correct and how to randomize order of gains / loss sessions between participants?
%if sessionNum == 1      %specifies what types of choices/ratings are made based on session number, but not sure what the rationale here is
%    eachCond = [eachCond; 1,0; 1,1; 2,0; 2,1; 3,0; 3,1]; % was [eachCond; 1,1; 2,0] % 1 rating, 1 choice
%    gambleOrder = [gambleOrder,randperm(length(gambles))]; % was /2 at end
%    gPairOrder = [gPairOrder,randperm(length(gPairs))];
%else
%    eachCond = [eachCond; 4,1;4,0;5,1;5,0;6,1;6,0]; % 2 rating
%    gambleOrder = [gambleOrder,randperm(length(gambles))];
%    gPairOrder = [gPairOrder,randperm(length(gPairs))];
%%elseif sessionNum == 3
%    eachCond = [eachCond; 1,0; 3,1]; % 1 rating 1 choice
%    gambleOrder = [gambleOrder,randperm(length(gambles)/2)+length(gambles)/2];
%    gPairOrder = [gPairOrder,randperm(length(gPairs))];
%else
%    eachCond = [eachCond; 2,0; 4,1]; % 2 rating
%    gambleOrder = [gambleOrder,randperm(length(gambles))];
%end
    

%% Scale information

scaleMax = 20;
scaleMin = 0;

scaleColor = [255 255 255]; %sets color to white?
textColor = [255 255 255];

majorTicks = linspace(scaleMin,scaleMax,11); %generates 11 points between the scale min and max
minorTicks = linspace(scaleMin,scaleMax,21); %generates 21 points between the scale min and max

numTicks = length(majorTicks); %creates numTicks var with length = number of major ticks
numMinorTicks = length(minorTicks);

innerRadiusFraction = 0.8; % how far from the center the ticks should start
innerRadius = innerRadiusFraction*center(2); % set the radius of the confidence scale to be 75% of the way from the center to the edge of the screen
outerRadiusFraction = 0.85; % can be adjusted to whatever we want, 80% of the way to the edge of the screen is reasonable
outerRadius = outerRadiusFraction*center(2); % set the radius for the end point of the ticks on the scale
minorRadiusFraction = .815;
minorRadius = minorRadiusFraction*center(2);
textRadius = 0.915;  % how far from the center the text will be

checkRate = .2; % record mouse trajectory every 200 ms

%% Instructions

if sessionNum == 1 

    % Slide 1

    HideCursor();

    DrawFormattedText(window, ['Welcome! Please complete the informed consent statement, then click the left mouse button to begin the experiment.'], 'center', centerY-50, [255 255 255], 80, 0, 0, 1.4);  %displays white text on screen
    Screen('Flip',window,0,0); %update window

    clicked = 0; %sets mouse to not be clicked
    while clicked == 0  %while mouse is not clicked
        [x,y,buttons] = GetMouse; %records state of mouse
        if any(buttons)  %if you click anything on the mouse, clicked = 1
            clicked = 1;
        end
    end

    Screen('Flip',window,0,0); %update window
    pause(.5);  %pause for .5 seconds

    % Slide 2

    textStr1 = ['In this experiment, you will price lotteries as well as make decisions between pairs of lotteries. Each lottery consists of a chance of winning (%), gaining or losing a payoff ($), and a delay (days).'];  %text strings to display
    textStr2 = [' 45% \n','gain $14 \n','7 days'];
    textStr3 = ['If you were to play this lottery, you would have a 45 in 100 chance of winning $14 after waiting 7 days, and a 55 in 100 chance of receiving $0.'];
    textStr4 = [' 45% \n','lose $14 \n','7 days'];
    textStr5 = ['If you were to play this lottery, you would have a 45 in 100 chance of losing $14 after waiting 7 days, and a 55 in 100 chance of losing $0. \n \n (Click the left mouse button to continue)'];
    
    DrawFormattedText(window, textStr1, 'center', centerY*.3, [255 255 255], 80, 0, 0, 1.4); %text string 1 drawn towards the top of the screen
    DrawFormattedText(window, textStr2, 'center', centerY*.6, [255 255 255], 80, 0, 0, 1.4);  %text string 2 drawn in the middle
    DrawFormattedText(window, textStr3, 'center', centerY*.9, [255 255 255], 80, 0, 0, 1.4);  %text string 3 drawn towards the bottom
    DrawFormattedText(window, textStr4, 'center', centerY*1.2, [255 255 255], 80, 0, 0, 1.4);
    DrawFormattedText(window, textStr5, 'center', centerY*1.5, [255 255 255], 80, 0, 0, 1.4);
    
    
    Screen('Flip',window,0,0); %update window

    clicked = 0;
    while clicked == 0
        [x,y,buttons] = GetMouse;
        if any(buttons)
            clicked = 1;
        end
    end

    Screen('Flip',window,0,0);
    pause(.5);

    textStr1 = ['Your tasks will be the following: \n \n 1) DECIDE between pairs of lotteries, indicating which you prefer',...
        '\n \n 2) BUY / indicate how much a person might pay to play the lottery (gain; buy the lottery ticket) or avoid losing the lottery (loss; buy insurance), or ',...
        '\n \n 3) SELL / indicate what price a person might ask to give away their chance at the lottery (gain; sell the lottery ticket) or have a chance to lose the lottery (loss; sell insurance).'];
    textStr3 = ['DECIDE, BUY, and SELL are organized in blocks, so you only have to do one at a time',...
        '\n Gaining and Losing payoffs are organized in sessions, so you will do them on different days. \n (Click the left mouse button to continue)'];

    DrawFormattedText(window, textStr1, 'center', centerY*.4, [255 255 255], 120, 0, 0, 1.4);
    DrawFormattedText(window, textStr3, 'center', centerY*1.7, [255 255 255], 80, 0, 0, 1.4);

    Screen('Flip',window,0,0);

    clicked = 0;
    while clicked == 0
        [x,y,buttons] = GetMouse;
        if any(buttons)
            clicked = 1;
        end
    end

    Screen('Flip',window,0,0);
    pause(.5);

    textStr1 = ['To DECIDE, you will simply click the left or right mouse button according to which lottery you prefer (left or right).'];
    % textStr2 = [' $14 \n',' 45 %'];
    textStr3 = ['Try a few of these trials now. Click the left mouse button to see a pair of lotteries, then left or right depending which you prefer.'];

    DrawFormattedText(window, textStr1, 'center', centerY*.8, [255 255 255], 80, 0, 0, 1.4);
    % DrawFormattedText(window, textStr2, 'center', centerY, [255 255 255], 80, 0, 0, 1.4);
    DrawFormattedText(window, textStr3, 'center', centerY*1.2, [255 255 255], 80, 0, 0, 1.4);

    Screen('Flip',window,0,0);

    clicked = 0;
    while clicked == 0
        [x,y,buttons] = GetMouse;
        if any(buttons)
            clicked = 1;
        end
    end

    Screen('Flip',window,0,0);
    pause(.5);

    %% Choice practice
    for n = 1:nPractice
         DrawFormattedText(window, ['+'], 'center', 'center', [255 255 255], 80, 0, 0, 1.4); % draw gray fixation cross
         DrawFormattedText(window, ['(Click on the + to start)'],'center',centerY+150,[255 255 255],80, 0, 0, 1.4); %display instructions to click on fixation cross

        ShowCursor('Arrow'); %display cursor as an arrow

        Screen('Flip', window, 0, 0);
        fixationClicked = 0;
        while fixationClicked == 0
            [xMouse, yMouse, buttons] = GetMouse;   %why is this one xMouse, yMouse while the previous was x,y?
            if any(buttons) && abs(xMouse - centerX) <= 40 && abs(yMouse - centerY) <= 40 %if mouse click is within 40 units of fixation cross in both the x and y direction, counts as a click on the cross
                fixationClicked = 1;
            end
        end        

        Screen('Flip',window,0,0);
        pause(.3);  %.3s pause
        
        gamble1pay = round((rand*2000)/100); %generates a random payout 0-20 rounded to the nearest integer, why is it rand*2000/100 rather than rand*20?
        gamble1prob = round(rand*100); %generates a random % chance 0-100 rounded to integer
        gamble1delay = round((rand*25000)/100); %generates a random delay 0-250 rounded to integer

        gamble2pay = round((rand*2000)/100);
        gamble2prob = round(rand*100);
        gamble2delay = round((rand*25000)/100);
        
        if eachCond == [1,1;1,0;2,1;2,0;3,1;3,0]
            DrawFormattedText(window,[num2str(gamble1prob),'%','\n','gain $',num2str(gamble1pay,'%.2f'),'\n',num2str(gamble1delay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, [.4*centerX, 0, centerX, centerY*2]); % draws left stimulus
            DrawFormattedText(window,[num2str(gamble2prob),'%','\n','gain $',num2str(gamble2pay,'%.2f'),'\n',num2str(gamble2delay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, [centerX, 0, centerX*1.6, centerY*2]); % draws right stimulus
        else
            DrawFormattedText(window,[num2str(gamble1prob),'%','\n','lose $',num2str(gamble1pay,'%.2f'),'\n',num2str(gamble1delay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, [.4*centerX, 0, centerX, centerY*2]); % draws left stimulus
            DrawFormattedText(window,[num2str(gamble2prob),'%','\n','lose $',num2str(gamble2pay,'%.2f'),'\n',num2str(gamble2delay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, [centerX, 0, centerX*1.6, centerY*2]); % draws right stimulus
        end    
        Screen('Flip',window,0,0);

        t0 = GetSecs; %creates t0 var at current real-time
        HideCursor();

        click = 0;

        while click == 0
            [xMouse, yMouse, buttons] = GetMouse;
            if buttons(1) || buttons(3)
                thisRT = GetSecs - t0;    %tracks reaction times for choices
                if buttons(1)
                    click = -1; % participant clicked left
                elseif buttons(3)
                    click = 1; % participant clicked right
                end
            end
        end


        Screen('Flip',window,0,0);
        pause(.5);
    end

    %% Rating Instructions

    click = 0;
    while click == 0
        DrawFormattedText(window,'On BUY, and SELL trials, you will enter the buying / selling price using a scale like this one.','center',centerY*1.3,[255 255 255], 80, 0, 0, 1.5);
        DrawFormattedText(window,'To respond using this scale, you just have to click on the desired dollar value along the semicircle. \n \n (Next we''ll try using this scale to enter numbers. Click the left mouse button to continue.)','center',centerY*1.6,[255 255 255], 80, 0, 0, 1.5);
        tickAngles = linspace(pi, 2*pi, numTicks); %generates 11 ticks between pi and 2*pi
        minorTickAngles = linspace(pi, 2*pi, numMinorTicks); %generates 21 ticks between pi and 2*pi

        radialLines = zeros(2, numTicks*2); % DrawLines takes a 2x(n*2) vector of x-y coordinates, with each pair of pairs indicating the start and end point of the tick
        minRadialLines = zeros(2, numMinorTicks*2); 

        for n = 1:numTicks
            radialLines(1,(n*2-1)) = round(innerRadius * cos(tickAngles(n)) + center(1)); % inner x coordinate of tick
            radialLines(2,(n*2-1)) = round(innerRadius * sin(tickAngles(n)) + center(2)); % inner y coordinate
            radialLines(1,(n*2)) = round(outerRadius * cos(tickAngles(n)) + center(1)); % outer x coordinate
            radialLines(2,(n*2)) = round(outerRadius * sin(tickAngles(n)) + center(2)); % outer y coordinate


            textTick = ['$',num2str(majorTicks(n))]; % displays text that shows $2*n for each major tick 

            textLocX = round(textRadius * center(2) * cos(tickAngles(n)) + center(1)) - 12; % specifies where on the x axis the $ text for each major tick appears
            textLocY = round(textRadius * .95 * center(2) * sin(tickAngles(n)) + center(2)); % specifies where on the y axis the $ text for each major tick appears

            Screen('DrawText', window, textTick, textLocX, textLocY, textColor, [0 0 0], center(2)); % displays black? text for each major tick


        end

        for n = 1:numMinorTicks
            minRadialLines(1,(n*2-1)) = round(innerRadius * cos(minorTickAngles(n)) + center(1)); % inner x coordinate of tick
            minRadialLines(2,(n*2-1)) = round(innerRadius * sin(minorTickAngles(n)) + center(2)); % inner y coordinate
            minRadialLines(1,(n*2)) = round(minorRadius * cos(minorTickAngles(n)) + center(1)); % outer x coordinate
            minRadialLines(2,(n*2)) = round(minorRadius * sin(minorTickAngles(n)) + center(2)); % outer y coordinate
        end

        Screen('DrawLines', window, radialLines, 3, scaleColor); % displays major radial ticks with width=3
        Screen('DrawLines', window, minRadialLines, 2, scaleColor); % displays minor radial ticks with width=2
        Screen('FrameArc', window, scaleColor, [center(1)-innerRadius, center(2)-innerRadius, center(1)+innerRadius, center(2)+innerRadius], 270, 180, 5, 5); % displays an arc from startangle = 270 and arcangle = 180 with width and height 5 

        ShowCursor('Arrow');

        Screen('Flip',window,0,0);

        [xMouse, yMouse, buttons] = GetMouse; %returns position of mouse

        if any(buttons)
            thisRT = GetSecs - t0; %reaction time for choice
            click = 1;
        end



    end

    Screen('Flip',window,0,0);
    pause(.3);

    %% Practice trials
    nSP = 1; %creates variable nSP =1 
    while nSP <= nScalePractice
        DrawFormattedText(window, ['+'], 'center', 'center', [255 255 255], 80, 0, 0, 1.4); % draw gray fixation cross
        DrawFormattedText(window, ['(Click on the + to start)'],'center',centerY+150,[255 255 255],80, 0, 0, 1.4); %display instructions in white text

        ShowCursor('Arrow');

        Screen('Flip', window, 0, 0);
        fixationClicked = 0;
        while fixationClicked == 0  %this text determines if the fixation cross is clicked
            [xMouse, yMouse, buttons] = GetMouse;
            if any(buttons) && abs(xMouse - centerX) <= 40 && abs(yMouse - centerY) <= 40
                fixationClicked = 1;
            end
        end        

        Screen('Flip',window,0,0);
        pause(.3);



        click = 0;
        findNum = rand*20; % does rand have a specfic range it pulls from?
        while click == 0
            DrawFormattedText(window,['Enter $',num2str(findNum,'%.2f'),' using the scale. \n \n (You do not need to be exact, just get close.)'],'center',centerY*1.3,[255 255 255], 80, 0, 0, 1.5); % draw instructions text
            minorTickAngles = linspace(pi, 2*pi, numMinorTicks); % generates 21 ticks between pi and 2*pi

            radialLines = zeros(2, numTicks*2); % DrawLines takes a 2x(n*2) vector of x-y coordinates, with each pair of pairs indicating the start and end point of the tick
            minRadialLines = zeros(2, numMinorTicks*2);

            for n = 1:numTicks
                radialLines(1,(n*2-1)) = round(innerRadius * cos(tickAngles(n)) + center(1)); % inner x coordinate of tick
                radialLines(2,(n*2-1)) = round(innerRadius * sin(tickAngles(n)) + center(2)); % inner y coordinate
                radialLines(1,(n*2)) = round(outerRadius * cos(tickAngles(n)) + center(1)); % outer x coordinate
                radialLines(2,(n*2)) = round(outerRadius * sin(tickAngles(n)) + center(2)); % outer y coordinate


                textTick = ['$',num2str(majorTicks(n))]; % see previous instances

                textLocX = round(textRadius * center(2) * cos(tickAngles(n)) + center(1)) - 12;
                textLocY = round(textRadius * .95 * center(2) * sin(tickAngles(n)) + center(2));

                Screen('DrawText', window, textTick, textLocX, textLocY, textColor, [0 0 0], center(2));    


            end

            for n = 1:numMinorTicks
                minRadialLines(1,(n*2-1)) = round(innerRadius * cos(minorTickAngles(n)) + center(1)); % inner x coordinate of tick
                minRadialLines(2,(n*2-1)) = round(innerRadius * sin(minorTickAngles(n)) + center(2)); % inner y coordinate
                minRadialLines(1,(n*2)) = round(minorRadius * cos(minorTickAngles(n)) + center(1)); % outer x coordinate
                minRadialLines(2,(n*2)) = round(minorRadius * sin(minorTickAngles(n)) + center(2)); % outer y coordinate
            end

            Screen('DrawLines', window, radialLines, 3, scaleColor);
            Screen('DrawLines', window, minRadialLines, 2, scaleColor);
            Screen('FrameArc', window, scaleColor, [center(1)-innerRadius, center(2)-innerRadius, center(1)+innerRadius, center(2)+innerRadius], 270, 180, 5, 5);

            ShowCursor('Arrow');

            Screen('Flip',window,0,0);


            [xMouse, yMouse, buttons] = GetMouse;
            xDist = xMouse - center(1); % distance of mouse from center of x axis
            yDist = center(2) - yMouse; % distance of mouse from center of y axis
            rMouse = sqrt(xDist^2 + yDist^2); % distance of mouse from true center (radius from the center)
            thMouse = atan2(abs(yDist),xDist); % is this the angle of the mouse from the center?
            if rMouse >= innerRadius % if mouse is positioned at or beyond the inner radius of the arc
                resp = ((scaleMax - scaleMin) - (scaleMax-scaleMin)*thMouse/pi) + scaleMin; % determines value ($) of mouse position on or beyond arc
                DrawFormattedText(window,['$',num2str(round(resp*100)/100,'%.2f')],'center',centerY*.8,[255 255 125], 80, 0, 0, 1.5, 0, [0,0,centerX*2,centerY*2]); %displays text for $ amount of current mouse position

                if any(buttons) % if any buttons clicked
                    thisRT = GetSecs - t0; % RT for choice
                    click = 1;

                    if abs(resp - findNum) < .15 % seems like this determines if the choice is reasonable, however findNum is rand*20, which is confusing to me, why pull from uniformly distributed random numbers?
                        DrawFormattedText(window,'Good!','center','center',[55 255 55], 80, 0, 0, 1.5);
                        nSP = nSP + 1;
                    else
                        DrawFormattedText(window,'Try to get closer.','center','center',[255 55 55],80,0,0,1.5);
                    end
                end
            end
        end

        dataMat.sPractice(nSP).resp = resp; % stores choice in data matrix
        dataMat.sPractice(nSP).rt = thisRT; % stores RT in data matrix
        Screen('Flip',window,0,0); 
        pause(2.3); % 2.3s ITI
    end


    pause(1);

    DrawFormattedText(window,'In addition, there are two types emphasis on different trials, SPEED and PRECISION.','center',centerY*.3,[255 255 255], 80, 0, 0, 1.5);
    DrawFormattedText(window,'SPEED: \n \n On SPEED trials, try to make your response quickly (in less than 7.5 seconds on rating trials, less than 3.5 seconds on decision trials)','center','center',[255 125 255], 30, 0, 0, 1.5, 0, [0, 0, centerX, centerY*1.9]);
    DrawFormattedText(window,'PRECISION: \n \n On PRECISION trials, try to make your response precisely, to within 10 cents of the price you want to enter.','center','center',[125 255 255], 30, 0, 0, 1.5, 0, [centerX, 0, centerX*2, centerY*1.9]);
    DrawFormattedText(window,'Dont worry! You will be reminded before each trial and block which emphasis and rating you need to give. \n \n Click the left mouse button to begin the experiment.','center',centerY*1.6,[255 255 255], 80, 0, 0, 1.5);

    Screen('Flip',window,0,0);

    pause(2);

    clicked = 0;
    while clicked == 0
        [x,y,buttons] = GetMouse;
        if any(buttons)
            clicked = 1;
        end
    end

    Screen('Flip',window,0,0);
    pause(.5);
else % if session =/= 1
    %% warm-up trials
    HideCursor();

    DrawFormattedText(window, ['Welcome back! Since this isn''t your first session, we''ll give a short refresher on the instructions and then go straight to some warm-up trials. Click the left mouse button when you''re ready to start.'], 'center', centerY-50, [255 255 255], 80, 0, 0, 1.4);
    Screen('Flip',window,0,0);

    clicked = 0;
    while clicked == 0
        [x,y,buttons] = GetMouse;
        if any(buttons)
            clicked = 1;
        end
    end

    Screen('Flip',window,0,0);
    pause(.5);
    
    textStr1 = ['Recall that the experiment includes the following trial types: \n \n 1) DECIDE between pairs of lotteries, indicating which you prefer',...
        '\n \n 2) BUY / indicate how much a person might pay to play the lottery (gain; buy the lottery ticket) or avoid losing the lottery (loss; buy insurance), or ',...
        '\n \n 3) SELL / indicate what price a person might ask to give away their chance at the lottery (gain; sell the lottery ticket) or have a chance to lose the lottery (loss; sell insurance).'];
    textStr3 = ['DECIDE, BUY, and SELL are organized in blocks, so you only have to do one at a time',...
        '\n Gaining and Losing payoffs are organized in sessions, so you will do them on different days. \n (Click the left mouse button to continue)'];

    DrawFormattedText(window, textStr1, 'center', centerY*.4, [255 255 255], 120, 0, 0, 1.4);
    DrawFormattedText(window, textStr3, 'center', centerY*1.7, [255 255 255], 80, 0, 0, 1.4);

    Screen('Flip',window,0,0);

    clicked = 0;
    while clicked == 0
        [x,y,buttons] = GetMouse;
        if any(buttons)
            clicked = 1;
        end
    end

    Screen('Flip',window,0,0);
    pause(.5);
    
    nSP = 1;
    while nSP <= nScalePractice
        DrawFormattedText(window, ['+'], 'center', 'center', [255 255 255], 80, 0, 0, 1.4); % draw gray fixation cross
        DrawFormattedText(window, ['(Click on the + to start)'],'center',centerY+150,[255 255 255],80, 0, 0, 1.4);

        ShowCursor('Arrow');

        Screen('Flip', window, 0, 0);
        fixationClicked = 0;
        while fixationClicked == 0  % see previous instances
            [xMouse, yMouse, buttons] = GetMouse;
            if any(buttons) && abs(xMouse - centerX) <= 40 && abs(yMouse - centerY) <= 40
                fixationClicked = 1;
            end
        end        

        Screen('Flip',window,0,0);
        pause(.3);

        t0 = GetSecs;  % real-time of trial onset

        click = 0;
        findNum = rand*20;
        while click == 0
            DrawFormattedText(window,['Enter $',num2str(findNum,'%.2f'),' using the scale. \n \n (You do not need to be exact, just get close.)'],'center',centerY*1.3,[255 255 255], 80, 0, 0, 1.5);
            tickAngles = linspace(pi, 2*pi, numTicks);
            minorTickAngles = linspace(pi, 2*pi, numMinorTicks);

            radialLines = zeros(2, numTicks*2); % DrawLines takes a 2x(n*2) vector of x-y coordinates, with each pair of pairs indicating the start and end point of the tick
            minRadialLines = zeros(2, numMinorTicks*2);

            for n = 1:numTicks
                radialLines(1,(n*2-1)) = round(innerRadius * cos(tickAngles(n)) + center(1)); % inner x coordinate of tick
                radialLines(2,(n*2-1)) = round(innerRadius * sin(tickAngles(n)) + center(2)); % inner y coordinate
                radialLines(1,(n*2)) = round(outerRadius * cos(tickAngles(n)) + center(1)); % outer x coordinate
                radialLines(2,(n*2)) = round(outerRadius * sin(tickAngles(n)) + center(2)); % outer y coordinate


                textTick = ['$',num2str(majorTicks(n))];

                textLocX = round(textRadius * center(2) * cos(tickAngles(n)) + center(1)) - 12;
                textLocY = round(textRadius * .95 * center(2) * sin(tickAngles(n)) + center(2));

                Screen('DrawText', window, textTick, textLocX, textLocY, textColor, [0 0 0], center(2));    


            end

            for n = 1:numMinorTicks
                minRadialLines(1,(n*2-1)) = round(innerRadius * cos(minorTickAngles(n)) + center(1)); % inner x coordinate of tick
                minRadialLines(2,(n*2-1)) = round(innerRadius * sin(minorTickAngles(n)) + center(2)); % inner y coordinate
                minRadialLines(1,(n*2)) = round(minorRadius * cos(minorTickAngles(n)) + center(1)); % outer x coordinate
                minRadialLines(2,(n*2)) = round(minorRadius * sin(minorTickAngles(n)) + center(2)); % outer y coordinate
            end

            Screen('DrawLines', window, radialLines, 3, scaleColor);
            Screen('DrawLines', window, minRadialLines, 2, scaleColor);
            Screen('FrameArc', window, scaleColor, [center(1)-innerRadius, center(2)-innerRadius, center(1)+innerRadius, center(2)+innerRadius], 270, 180, 5, 5);

            ShowCursor('Arrow');

            Screen('Flip',window,0,0);


            [xMouse, yMouse, buttons] = GetMouse;
            xDist = xMouse - center(1);
            yDist = center(2) - yMouse;
            rMouse = sqrt(xDist^2 + yDist^2);
            thMouse = atan2(abs(yDist),xDist);
            if rMouse >= innerRadius
                resp = ((scaleMax - scaleMin) - (scaleMax-scaleMin)*thMouse/pi) + scaleMin;
                DrawFormattedText(window,['$',num2str(round(resp*100)/100,'%.2f')],'center',centerY*.8,[255 255 125], 80, 0, 0, 1.5, 0, [0,0,centerX*2,centerY*2]);

                if any(buttons)
                    thisRT = GetSecs - t0;
                    click = 1;

                    if abs(resp - findNum) < .15
                        DrawFormattedText(window,'Good!','center','center',[55 255 55], 80, 0, 0, 1.5);
                        nSP = nSP + 1;
                    else
                        DrawFormattedText(window,'Try to get closer.','center','center',[255 55 55],80,0,0,1.5);
                    end
                end
            end
        end

        dataMat.sPractice(nSP).resp = resp;
        dataMat.sPractice(nSP).rt = thisRT;
        Screen('Flip',window,0,0);
        pause(2.3);
    end


    pause(1);

    DrawFormattedText(window,'In addition, remember that there are two types emphasis on different trials, SPEED and PRECISION.','center',centerY*.3,[255 255 255], 80, 0, 0, 1.5);
    DrawFormattedText(window,'SPEED: \n \n On SPEED trials, try to make your response quickly (in less than 7.5 second on rating trials, less than 3.5 seconds on decision trials)','center','center',[255 125 255], 30, 0, 0, 1.5, 0, [0, 0, centerX, centerY*1.9]);
    DrawFormattedText(window,'PRECISION: \n \n On PRECISION trials, try to make your response precisely, to within 10 cents of the price you want to enter.','center','center',[125 255 255], 30, 0, 0, 1.5, 0, [centerX, 0, centerX*2, centerY*1.9]);
    DrawFormattedText(window,'Dont worry! You will be reminded before each trial and block which emphasis and rating you need to give. \n \n Click the left mouse button to begin the experiment.','center',centerY*1.6,[255 255 255], 80, 0, 0, 1.5);

    Screen('Flip',window,0,0);

    pause(2);

    clicked = 0;
    while clicked == 0
        [x,y,buttons] = GetMouse;
        if any(buttons)
            clicked = 1;
        end
    end

    Screen('Flip',window,0,0);
    pause(.5);
    
end

%% Main loop

for bN = 1:nBlocks % repeat loop for the number of blocks
    pause(.5);
    blockType = eachCond(condOrder(bN),1); % draws from column 1 of condOrder to determine block type
    isSpeed = eachCond(condOrder(bN),2);  % draws from column 2 of condOrder to determine if block is speed (else precision)
    
    % 1 = Binary choice gains
    % 2 = Willingness to pay gains (WTP)
    % 3 = Willingness to accept gains (WTA)
    % 4 = Binary choice losses
    % 5 = Willingness to pay losses (WTP)
    % 6 = Willingness to accept losses (WTA)
    
    switch blockType % execute one statement for the corresponding blocktype
        case 1
            DrawFormattedText(window, ['The following are CHOICE GAIN trials. Click the right mouse button for a chance to obtain the option on the right, or the left mouse button for a chance to obtain the one on the left.'], 'center', centerY-50, [255 255 255], 80, 0, 0, 1.4);
        case 2
            DrawFormattedText(window, ['The following are BUYING GAIN trials. Specify how much you would pay now to play the lottery (buy the lottery ticket) by selecting a value on the scale.'], 'center', centerY-50, [255 255 255], 80, 0, 0, 1.4);
        case 3
            DrawFormattedText(window, ['The following are SELLING GAIN trials. Specify how much you would ask someone else to pay you now to give away your chance to play the lottery (sell the lottery ticket) by selecting a value on the scale.'], 'center', centerY-50, [255 255 255], 80, 0, 0, 1.4);
        case 4
            DrawFormattedText(window, ['The following are CHOICE LOSS trials. Click the right mouse button for a chance to lose the option on the right, or the left mouse button for a chance to lose the one on the left.'], 'center', centerY-50, [255 255 255], 80, 0, 0, 1.4);
        case 5
            DrawFormattedText(window, ['The following are BUYING LOSS trials. Specify how much you would pay now to avoid a chance to lose the lottery (buy insurance) by selecting a value on the scale.'], 'center', centerY-50, [255 255 255], 80, 0, 0, 1.4);
        otherwise
            DrawFormattedText(window, ['The following are SELLING LOSS trials. Specify how much you would ask someone else to pay you now for you to have a chance to lose the lottery (sell insurance) by selecting a value on the scale.'], 'center', centerY-50, [255 255 255], 80, 0, 0, 1.4);
    end
    
    if isSpeed
        fTextColor = [255 125 255];
        DrawFormattedText(window, ['These are SPEED trials. Try to make your responses quickly.'], 'center', centerY+50, fTextColor, 80, 0, 0, 1.4);
    else
        fTextColor = [125 255 255];
        DrawFormattedText(window, ['These are PRECISION trials. Try to make your responses carefully.'], 'center', centerY+50, fTextColor, 80, 0, 0, 1.4);
    end
    
    DrawFormattedText(window, ['Click the left mouse button to continue.'], 'center', centerY+200, [255 255 255], 80, 0, 0, 1.4);
    
    Screen('Flip',window,0,0);
    
    clicked = 0;
    while clicked == 0
        [xMouse, yMouse, buttons] = GetMouse;
        if any(buttons) 
            clicked = 1;
        end
    end  
    
    pause(.3);
    
    %if blockType == 1 % execute one statement for the corresponding blocktype
    %        tN = 1:nTrialsPerChoiceBlock;
    %elseif blockType == 2
    %        tN = 1:nTrialsPerPriceBlock;
    %elseif blockType == 3
    %        tN = 1:nTrialsPerPriceBlock;
    %elseif blockType == 4
    %        tN = 1:nTrialsPerChoiceBlock;
    %elseif blockType == 5
    %        tN = 1:nTrialsPerPriceBlock;
    %else
    %        tN = 1:nTrialsPerPriceBlock;
    %end
    switch blockType % execute one statement for the corresponding blocktype
        case 1
            nTrialsPerBlock = nTrialsPerChoiceBlock;
        case 2
            nTrialsPerBlock = nTrialsPerPriceBlock;
        case 3
            nTrialsPerBlock = nTrialsPerPriceBlock;
        case 4
            nTrialsPerBlock = nTrialsPerChoiceBlock;
        case 5
            nTrialsPerBlock = nTrialsPerPriceBlock;
        otherwise
            nTrialsPerBlock = nTrialsPerPriceBlock;
    end       
    for tN = 1:nTrialsPerBlock
        dataMat.trial(trialNum).type = blockType; % record block type for subsequent trials
        
        %% Fixation
        DrawFormattedText(window, ['+'], 'center', 'center', [255 255 255], 80, 0, 0, 1.4); % draw gray fixation cross
        
        switch blockType
            case 1
                DrawFormattedText(window, ['CHOICE GAIN'], 'center', centerY + 100, [255 255 255], 80, 0, 0, 1.4);
            case 2
                DrawFormattedText(window, ['BUY GAIN'], 'center', centerY + 100, [255 255 255], 80, 0, 0, 1.4);
            case 3
                DrawFormattedText(window, ['SELL GAIN'], 'center', centerY + 100, [255 255 255], 80, 0, 0, 1.4);
            case 4
                DrawFormattedText(window, ['CHOICE LOSS'], 'center', centerY + 100, [255 255 255], 80, 0, 0, 1.4);
            case 5
               DrawFormattedText(window, ['BUY LOSS'], 'center', centerY + 100, [255 255 255], 80, 0, 0, 1.4);
            otherwise
               DrawFormattedText(window, ['SELL LOSS'], 'center', centerY + 100, [255 255 255], 80, 0, 0, 1.4);
        end
        
        if isSpeed
            DrawFormattedText(window, ['SPEED'], 'center', centerY + 150, fTextColor, 80, 0, 0, 1.4);
        else
            DrawFormattedText(window, ['PRECISION'], 'center', centerY + 150, fTextColor, 80, 0, 0, 1.4);
        end
        
        ShowCursor('Arrow');
        
        Screen('Flip', window, 0, 0);
        fixationClicked = 0;
        while fixationClicked == 0
            [xMouse, yMouse, buttons] = GetMouse;
            if any(buttons) && abs(xMouse - centerX) <= 40 && abs(yMouse - centerY) <= 40
                fixationClicked = 1;
            end
        end        

        Screen('Flip',window,0,0);
        pause(.3);

        
        %% Trial
        switch blockType
            case 1
                %% Binary gambles (+)
                dataMat.trial(trialNum).typeText = 'choice'; % records choice trial type
                dataMat.trial(trialNum).typeText2 = 'gain'; % records gain trial type
                dataMat.trial(trialNum).type = 1; % numerical code for choice trial
                 
                gpIndex = gPairOrder(nGP); % gpIndex = randomized gPairs with counter
                nGP = nGP + 1; % interates counter each loop
                dataMat.trial(trialNum).gambleNum = gpIndex;  % records gpIndex for each trial, tracks trialnumber within block
                if rand > .5 % randomize right and left presentation
                    gamble1pay = gPairs(gpIndex,1);
                    gamble1delay = gPairs(gpIndex,2);
                    gamble1prob = gPairs(gpIndex,3);
                    gamble2pay = gPairs(gpIndex,4);
                    gamble2delay = gPairs(gpIndex,5);
                    gamble2prob = gPairs(gpIndex,6);
                else
                    gamble1pay = gPairs(gpIndex,4);
                    gamble1delay = gPairs(gpIndex,5);
                    gamble1prob = gPairs(gpIndex,6);
                    gamble2pay = gPairs(gpIndex,1);
                    gamble2delay = gPairs(gpIndex,2);
                    gamble2prob = gPairs(gpIndex,3);
                end
                
                DrawFormattedText(window,[num2str(gamble1prob),'%','\n','gain $',num2str(gamble1pay,'%.2f'),'\n',num2str(gamble1delay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, [.4*centerX, 0, centerX, centerY*2]); % draws left stimulus
                DrawFormattedText(window,[num2str(gamble2prob),'%','\n','gain $',num2str(gamble2pay,'%.2f'),'\n',num2str(gamble2delay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, [centerX, 0, centerX*1.6, centerY*2]); % draws right stimulus

                Screen('Flip',window,0,0);
                
                t0 = GetSecs; % real-time at start of trial
                HideCursor();
                
                click = 0;
                
                while click == 0
                    [xMouse, yMouse, buttons] = GetMouse;
                    if buttons(1) || buttons(3)
                        thisRT = GetSecs - t0;
                        if buttons(1)
                            click = -1; % participant clicked left
                        elseif buttons(3)
                            click = 1; % participant clicked right
                        end
                    end
                end
                
                Screen('Flip',window,0,0);
                pause(.3);
                
                if isSpeed == 1 && thisRT > 3.5 % determines if clicked fast enough in speed condition. Are these too-slow trials treated differently in analysis?
                    DrawFormattedText(window,'Try to respond faster (< 3.5 seconds). Remember, this is a SPEED condition!','center','center',[255 255 100], 40, 0, 0, 1.5); % draws instructions to respond faster
                    Screen('Flip',window,0,0);
                    pause(3.5);
                end
                
                dataMat.trial(trialNum).resp = click; %records left/right choice
                dataMat.trial(trialNum).rt = thisRT; %records RT
                dataMat.trial(trialNum).stim = [gamble1pay,gamble1prob,gamble1delay,gamble2pay,gamble2prob,gamble2delay]; %records choice stimuli
                dataMat.trial(trialNum).traj = []; %records nothing for mouse trajectory, because there isn't anything to track
                dataMat.trial(trialNum).isSpeed = isSpeed; %records speed condition
                dataMat.trial(trialNum).blockNum = bN; %records block number
                dataMat.trial(trialNum).trialInBlock = tN; % records trial number
       
            case 2
                 %% Willingness to pay (buying) (+)
                dataMat.trial(trialNum).typeText = 'WTP'; % records WTP trial type
                dataMat.trial(trialNum).typeText2 = 'gain'; % records gain trial type
                dataMat.trial(trialNum).type = 2; % numerical code for WTP trial
                
                gIndex = gambleOrder(nG); % gIndex = randomized gambles with counter
                nG = nG + 1; % interates counter each loop
                dataMat.trial(trialNum).gambleNum = gIndex; % records gIndex for each trial, tracks trialnumber within block
                gamblePay = gambles(gIndex,1);
                gambleDelay = gambles(gIndex,2);
                gambleProb = gambles(gIndex,3);
                
                t0 = GetSecs; % real-time at start of trial
                traj = [0,0]; % starts mouse trajectory at x=0, y=0
                lastCheck = t0; % lastCheck = real-time at start of trial
                
                click = 0;
                
                while click == 0
                
                    DrawFormattedText(window,[num2str(gambleProb),'%','\n','gain $',num2str(gamblePay,'%.2f'),'\n',num2str(gambleDelay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, [0, 200, centerX*2, centerY*2]);
                    DrawFormattedText(window,'What price would you PAY to play this lottery (buy the lottery ticket)?','center','center',[255 255 255], 80, 0, 0, 1.5, 0, [0,centerY,centerX*2,centerY*2]);
                    tickAngles = linspace(pi, 2*pi, numTicks);
                    minorTickAngles = linspace(pi, 2*pi, numMinorTicks);

                    radialLines = zeros(2, numTicks*2); % DrawLines takes a 2x(n*2) vector of x-y coordinates, with each pair of pairs indicating the start and end point of the tick
                    minRadialLines = zeros(2, numMinorTicks*2);

                    for n = 1:numTicks
                        radialLines(1,(n*2-1)) = round(innerRadius * cos(tickAngles(n)) + center(1)); % inner x coordinate of tick
                        radialLines(2,(n*2-1)) = round(innerRadius * sin(tickAngles(n)) + center(2)); % inner y coordinate
                        radialLines(1,(n*2)) = round(outerRadius * cos(tickAngles(n)) + center(1)); % outer x coordinate
                        radialLines(2,(n*2)) = round(outerRadius * sin(tickAngles(n)) + center(2)); % outer y coordinate


                        textTick = ['$',num2str(majorTicks(n))]; 

                        textLocX = round(textRadius * center(2) * cos(tickAngles(n)) + center(1)) - 12;
                        textLocY = round(textRadius * .95 * center(2) * sin(tickAngles(n)) + center(2));

                        Screen('DrawText', window, textTick, textLocX, textLocY, textColor, [0 0 0], center(2));    


                    end

                    for n = 1:numMinorTicks
                        minRadialLines(1,(n*2-1)) = round(innerRadius * cos(minorTickAngles(n)) + center(1)); % inner x coordinate of tick
                        minRadialLines(2,(n*2-1)) = round(innerRadius * sin(minorTickAngles(n)) + center(2)); % inner y coordinate
                        minRadialLines(1,(n*2)) = round(minorRadius * cos(minorTickAngles(n)) + center(1)); % outer x coordinate
                        minRadialLines(2,(n*2)) = round(minorRadius * sin(minorTickAngles(n)) + center(2)); % outer y coordinate
                    end

                    Screen('DrawLines', window, radialLines, 3, scaleColor);
                    Screen('DrawLines', window, minRadialLines, 2, scaleColor);
                    Screen('FrameArc', window, scaleColor, [center(1)-innerRadius, center(2)-innerRadius, center(1)+innerRadius, center(2)+innerRadius], 270, 180, 5, 5);

                    ShowCursor('Arrow');

                    Screen('Flip',window,0,0);
                
               
                    [xMouse, yMouse, buttons] = GetMouse;
                    xDist = xMouse - center(1);
                    yDist = center(2) - yMouse;
                    rMouse = sqrt(xDist^2 + yDist^2);
                    thMouse = atan2(abs(yDist),xDist);
                    
                    if GetSecs - lastCheck > checkRate % if current time - start of trial (lastCheck) is > .2 (mouse checkRate)
                        traj = [traj; xDist,yDist]; % records mouse trajectory
                        lastCheck = GetSecs; % refreshes lastCheck to current time
                    end
                    
                    if rMouse >= innerRadius % if radius of mouse is at or beyond the inner radius of arc
                        resp = ((scaleMax - scaleMin) - (scaleMax-scaleMin)*thMouse/pi) + scaleMin; % determines value ($) of mouse position on or beyond arc
                        DrawFormattedText(window,['Response: \n $',num2str(round(resp*100)/100,'%.2f')],'center',centerY*.8,fTextColor, 80, 0, 0, 1.5, 0, [0,0,centerX*2,centerY*2]);
                    
                        if any(buttons) 
                            thisRT = GetSecs - t0; %records RT for choice
                            click = 1;
                        end
                    end
                end
                
                Screen('Flip',window,0,0);
                pause(.3);
                
                if isSpeed == 1 && thisRT > 7.5 % if speed trial and RT is >7.5s
                    DrawFormattedText(window,'Try to respond faster (< 7.5 seconds). Remember, this is a SPEED condition!','center','center',[255 255 100], 40, 0, 0, 1.5);
                    Screen('Flip',window,0,0);
                    pause(3.5);
                end
                
                dataMat.trial(trialNum).resp = resp; %records left/right choice
                dataMat.trial(trialNum).rt = thisRT; %records RT
                dataMat.trial(trialNum).stim = [gamblePay,gambleProb,gambleDelay]; %records choice stimuli
                dataMat.trial(trialNum).traj = traj; %records mouse trajectory (how does it know? [] shouldn't provide any information?)
                dataMat.trial(trialNum).isSpeed = isSpeed; %records speed condition
                dataMat.trial(trialNum).blockNum = bN; %records block number
                dataMat.trial(trialNum).trialInBlock = tN; % records trial number
                
                
            case 3
                %% Willingness to accept (selling) (+)
                dataMat.trial(trialNum).typeText = 'WTA'; % records WTA trial type
                dataMat.trial(trialNum).typeText2 = 'gain'; % records gain trial type
                dataMat.trial(trialNum).type = 3; % records numerical code for WTP trial
                
                gIndex = gambleOrder(nG);
                nG = nG + 1;
                dataMat.trial(trialNum).gambleNum = gIndex;
                gamblePay = gambles(gIndex,1);
                gambleDelay = gambles(gIndex,2);
                gambleProb = gambles(gIndex,3);
                
                t0 = GetSecs;
                traj = [0,0];
                lastCheck = t0;
                
                click = 0;
                
                while click == 0
                
                    DrawFormattedText(window,[num2str(gambleProb),'%','\n','gain $',num2str(gamblePay,'%.2f'),'\n',num2str(gambleDelay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, [0, 200, centerX*2, centerY*2]);
                    DrawFormattedText(window,'At what price would you SELL your chance to play this lottery (sell the lottery ticket)?','center','center',[255 255 255], 80, 0, 0, 1.5, 0, [0,centerY,centerX*2,centerY*2]); % Code identical to WTP trails, just with different instructions and trial type labels
                    tickAngles = linspace(pi, 2*pi, numTicks);
                    minorTickAngles = linspace(pi, 2*pi, numMinorTicks);

                    radialLines = zeros(2, numTicks*2); % DrawLines takes a 2x(n*2) vector of x-y coordinates, with each pair of pairs indicating the start and end point of the tick
                    minRadialLines = zeros(2, numMinorTicks*2);

                    for n = 1:numTicks
                        radialLines(1,(n*2-1)) = round(innerRadius * cos(tickAngles(n)) + center(1)); % inner x coordinate of tick
                        radialLines(2,(n*2-1)) = round(innerRadius * sin(tickAngles(n)) + center(2)); % inner y coordinate
                        radialLines(1,(n*2)) = round(outerRadius * cos(tickAngles(n)) + center(1)); % outer x coordinate
                        radialLines(2,(n*2)) = round(outerRadius * sin(tickAngles(n)) + center(2)); % outer y coordinate


                        textTick = ['$',num2str(majorTicks(n))];

                        textLocX = round(textRadius * center(2) * cos(tickAngles(n)) + center(1)) - 12;
                        textLocY = round(textRadius * .95 * center(2) * sin(tickAngles(n)) + center(2));

                        Screen('DrawText', window, textTick, textLocX, textLocY, textColor, [0 0 0], center(2));    


                    end

                    for n = 1:numMinorTicks
                        minRadialLines(1,(n*2-1)) = round(innerRadius * cos(minorTickAngles(n)) + center(1)); % inner x coordinate of tick
                        minRadialLines(2,(n*2-1)) = round(innerRadius * sin(minorTickAngles(n)) + center(2)); % inner y coordinate
                        minRadialLines(1,(n*2)) = round(minorRadius * cos(minorTickAngles(n)) + center(1)); % outer x coordinate
                        minRadialLines(2,(n*2)) = round(minorRadius * sin(minorTickAngles(n)) + center(2)); % outer y coordinate
                    end

                    Screen('DrawLines', window, radialLines, 3, scaleColor);
                    Screen('DrawLines', window, minRadialLines, 2, scaleColor);
                    Screen('FrameArc', window, scaleColor, [center(1)-innerRadius, center(2)-innerRadius, center(1)+innerRadius, center(2)+innerRadius], 270, 180, 5, 5);

                    ShowCursor('Arrow');

                    Screen('Flip',window,0,0);

               
                    [xMouse, yMouse, buttons] = GetMouse;
                    xDist = xMouse - center(1);
                    yDist = center(2) - yMouse;
                    rMouse = sqrt(xDist^2 + yDist^2);
                    thMouse = atan2(abs(yDist),xDist);
                    
                    if GetSecs - lastCheck > checkRate
                        traj = [traj; xDist,yDist];
                        lastCheck = GetSecs;
                    end
                    
                    if rMouse >= innerRadius
                        resp = ((scaleMax - scaleMin) - (scaleMax-scaleMin)*thMouse/pi) + scaleMin;
                        DrawFormattedText(window,['Response: \n $',num2str(round(resp*100)/100,'%.2f')],'center',centerY*.8,fTextColor, 80, 0, 0, 1.5, 0, [0,0,centerX*2,centerY*2]);
                    
                        if any(buttons)
                            thisRT = GetSecs - t0;
                            click = 1;
                        end
                    end
                end
                
                Screen('Flip',window,0,0);
                pause(.3);
                
                if isSpeed == 1 && thisRT > 7.5
                    DrawFormattedText(window,'Try to respond faster (< 7.5 seconds). Remember, this is a SPEED condition!','center','center',[255 255 100], 40, 0, 0, 1.5);
                    Screen('Flip',window,0,0);
                    pause(2.5);
                end
                
                dataMat.trial(trialNum).resp = resp;
                dataMat.trial(trialNum).rt = thisRT;
                dataMat.trial(trialNum).stim = [gamblePay,gambleProb,gambleDelay];
                dataMat.trial(trialNum).traj = traj;
                dataMat.trial(trialNum).isSpeed = isSpeed;
                dataMat.trial(trialNum).blockNum = bN;
                dataMat.trial(trialNum).trialInBlock = tN;
                
            case 4
                %% Binary gambles (-)
                dataMat.trial(trialNum).typeText = 'choice'; % records choice trial type
                dataMat.trial(trialNum).typeText2 = 'loss'; % records loss trial type
                dataMat.trial(trialNum).type = 4; % numerical code for choice trial
                 
                gpIndex = gPairOrder(nGP); % gpIndex = randomized gPairs with counter
                nGP = nGP + 1; % interates counter each loop
                dataMat.trial(trialNum).gambleNum = gpIndex;  % records gpIndex for each trial, tracks trialnumber within block
                if rand > .5 % randomize right and left presentation
                    gamble1pay = gPairs(gpIndex,1);
                    gamble1delay = gPairs(gpIndex,2);
                    gamble1prob = gPairs(gpIndex,3);
                    gamble2pay = gPairs(gpIndex,4);
                    gamble2delay = gPairs(gpIndex,5);
                    gamble2prob = gPairs(gpIndex,6);
                else
                    gamble1pay = gPairs(gpIndex,4);
                    gamble1delay = gPairs(gpIndex,5);
                    gamble1prob = gPairs(gpIndex,6);
                    gamble2pay = gPairs(gpIndex,1);
                    gamble2delay = gPairs(gpIndex,2);
                    gamble2prob = gPairs(gpIndex,3);
                end
                
                DrawFormattedText(window,[num2str(gamble1prob),'%','\n','lose ','$',num2str(gamble1pay,'%.2f'),'\n',num2str(gamble1delay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, [.4*centerX, 0, centerX, centerY*2]); % draws left stimulus
                DrawFormattedText(window,[num2str(gamble2prob),'%','\n','lose ','$',num2str(gamble2pay,'%.2f'),'\n',num2str(gamble2delay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, [centerX, 0, centerX*1.6, centerY*2]); % draws right stimulus

                Screen('Flip',window,0,0);
                
                t0 = GetSecs; % real-time at start of trial
                HideCursor();
                
                click = 0;
                
                while click == 0
                    [xMouse, yMouse, buttons] = GetMouse;
                    if buttons(1) || buttons(3)
                        thisRT = GetSecs - t0;
                        if buttons(1)
                            click = -1; % participant clicked left
                        elseif buttons(3)
                            click = 1; % participant clicked right
                        end
                    end
                end
                
                Screen('Flip',window,0,0);
                pause(.3);
                
                if isSpeed == 1 && thisRT > 3.5 % determines if clicked fast enough in speed condition. Are these too-slow trials treated differently in analysis?
                    DrawFormattedText(window,'Try to respond faster (< 3.5 seconds). Remember, this is a SPEED condition!','center','center',[255 255 100], 40, 0, 0, 1.5); % draws instructions to respond faster
                    Screen('Flip',window,0,0);
                    pause(3.5);
                end
                
                dataMat.trial(trialNum).resp = click; %records left/right choice
                dataMat.trial(trialNum).rt = thisRT; %records RT
                dataMat.trial(trialNum).stim = [gamble1pay,gamble1prob,gamble1delay,gamble2pay,gamble2prob,gamble2delay]; %records choice stimuli
                dataMat.trial(trialNum).traj = []; %records nothing for mouse trajectory, because there isn't anything to track
                dataMat.trial(trialNum).isSpeed = isSpeed; %records speed condition
                dataMat.trial(trialNum).blockNum = bN; %records block number
                dataMat.trial(trialNum).trialInBlock = tN; % records trial number
                
                
            case 5
                 %% Willingness to pay (buying)(-)
                dataMat.trial(trialNum).typeText = 'WTP'; % records WTP trial type
                dataMat.trial(trialNum).typeText2 = 'loss'; % records loss trial type
                dataMat.trial(trialNum).type = 5; % numerical code for WTP trial
                
                gIndex = gambleOrder(nG); % gIndex = randomized gambles with counter
                nG = nG + 1; % interates counter each loop
                dataMat.trial(trialNum).gambleNum = gIndex; % records gIndex for each trial, tracks trialnumber within block
                gamblePay = gambles(gIndex,1);
                gambleDelay = gambles(gIndex,2);
                gambleProb = gambles(gIndex,3);
                
                t0 = GetSecs; % real-time at start of trial
                traj = [0,0]; % starts mouse trajectory at x=0, y=0
                lastCheck = t0; % lastCheck = real-time at start of trial
                
                click = 0;
                
                while click == 0
                
                    DrawFormattedText(window,[num2str(gambleProb),'%','\n','lose ','$',num2str(gamblePay,'%.2f'),'\n',num2str(gambleDelay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, [0, 200, centerX*2, centerY*2]);
                    DrawFormattedText(window,'What price would you PAY to avoid this lottery (buy insurance)?','center','center',[255 255 255], 80, 0, 0, 1.5, 0, [0,centerY,centerX*2,centerY*2]);
                    tickAngles = linspace(pi, 2*pi, numTicks);
                    minorTickAngles = linspace(pi, 2*pi, numMinorTicks);

                    radialLines = zeros(2, numTicks*2); % DrawLines takes a 2x(n*2) vector of x-y coordinates, with each pair of pairs indicating the start and end point of the tick
                    minRadialLines = zeros(2, numMinorTicks*2);

                    for n = 1:numTicks
                        radialLines(1,(n*2-1)) = round(innerRadius * cos(tickAngles(n)) + center(1)); % inner x coordinate of tick
                        radialLines(2,(n*2-1)) = round(innerRadius * sin(tickAngles(n)) + center(2)); % inner y coordinate
                        radialLines(1,(n*2)) = round(outerRadius * cos(tickAngles(n)) + center(1)); % outer x coordinate
                        radialLines(2,(n*2)) = round(outerRadius * sin(tickAngles(n)) + center(2)); % outer y coordinate


                        textTick = ['$',num2str(majorTicks(n))]; 

                        textLocX = round(textRadius * center(2) * cos(tickAngles(n)) + center(1)) - 12;
                        textLocY = round(textRadius * .95 * center(2) * sin(tickAngles(n)) + center(2));

                        Screen('DrawText', window, textTick, textLocX, textLocY, textColor, [0 0 0], center(2));    


                    end

                    for n = 1:numMinorTicks
                        minRadialLines(1,(n*2-1)) = round(innerRadius * cos(minorTickAngles(n)) + center(1)); % inner x coordinate of tick
                        minRadialLines(2,(n*2-1)) = round(innerRadius * sin(minorTickAngles(n)) + center(2)); % inner y coordinate
                        minRadialLines(1,(n*2)) = round(minorRadius * cos(minorTickAngles(n)) + center(1)); % outer x coordinate
                        minRadialLines(2,(n*2)) = round(minorRadius * sin(minorTickAngles(n)) + center(2)); % outer y coordinate
                    end

                    Screen('DrawLines', window, radialLines, 3, scaleColor);
                    Screen('DrawLines', window, minRadialLines, 2, scaleColor);
                    Screen('FrameArc', window, scaleColor, [center(1)-innerRadius, center(2)-innerRadius, center(1)+innerRadius, center(2)+innerRadius], 270, 180, 5, 5);

                    ShowCursor('Arrow');

                    Screen('Flip',window,0,0);
                
               
                    [xMouse, yMouse, buttons] = GetMouse;
                    xDist = xMouse - center(1);
                    yDist = center(2) - yMouse;
                    rMouse = sqrt(xDist^2 + yDist^2);
                    thMouse = atan2(abs(yDist),xDist);
                    
                    if GetSecs - lastCheck > checkRate % if current time - start of trial (lastCheck) is > .2 (mouse checkRate)
                        traj = [traj; xDist,yDist]; % records mouse trajectory
                        lastCheck = GetSecs; % refreshes lastCheck to current time
                    end
                    
                    if rMouse >= innerRadius % if radius of mouse is at or beyond the inner radius of arc
                        resp = ((scaleMax - scaleMin) - (scaleMax-scaleMin)*thMouse/pi) + scaleMin; % determines value ($) of mouse position on or beyond arc
                        DrawFormattedText(window,['Response: \n $',num2str(round(resp*100)/100,'%.2f')],'center',centerY*.8,fTextColor, 80, 0, 0, 1.5, 0, [0,0,centerX*2,centerY*2]);
                    
                        if any(buttons) 
                            thisRT = GetSecs - t0; %records RT for choice
                            click = 1;
                        end
                    end
                end
                
                Screen('Flip',window,0,0);
                pause(.3);
                
                if isSpeed == 1 && thisRT > 7.5 % if speed trial and RT is >7.5s
                    DrawFormattedText(window,'Try to respond faster (< 7.5 seconds). Remember, this is a SPEED condition!','center','center',[255 255 100], 40, 0, 0, 1.5);
                    Screen('Flip',window,0,0);
                    pause(3.5);
                end
                
                dataMat.trial(trialNum).resp = resp; %records left/right choice
                dataMat.trial(trialNum).rt = thisRT; %records RT
                dataMat.trial(trialNum).stim = [gamblePay,gambleProb,gambleDelay]; %records choice stimuli
                dataMat.trial(trialNum).traj = traj; %records mouse trajectory (how does it know? [] shouldn't provide any information?)
                dataMat.trial(trialNum).isSpeed = isSpeed; %records speed condition
                dataMat.trial(trialNum).blockNum = bN; %records block number
                dataMat.trial(trialNum).trialInBlock = tN; % records trial number
                
                
            case 6
                %% Willingness to accept (selling) (-)
                dataMat.trial(trialNum).typeText = 'WTA'; % records WTA trial type
                dataMat.trial(trialNum).typeText2 = 'loss'; % records loss trial type
                dataMat.trial(trialNum).type = 6; % records numerical code for WTP trial
                
                gIndex = gambleOrder(nG);
                nG = nG + 1;
                dataMat.trial(trialNum).gambleNum = gIndex;
                gamblePay = gambles(gIndex,1);
                gambleDelay = gambles(gIndex,2);
                gambleProb = gambles(gIndex,3);
                
                t0 = GetSecs;
                traj = [0,0];
                lastCheck = t0;
                
                click = 0;
                
                while click == 0
                
                    DrawFormattedText(window,[num2str(gambleProb),'%','\n','lose ','$',num2str(gamblePay,'%.2f'),'\n',num2str(gambleDelay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, [0, 200, centerX*2, centerY*2]);
                    DrawFormattedText(window,'At what price would you SELL to take a chance to lose this lottery (sell insurance)?','center','center',[255 255 255], 80, 0, 0, 1.5, 0, [0,centerY,centerX*2,centerY*2]); % Code identical to WTP trails, just with different instructions and trial type labels
                    tickAngles = linspace(pi, 2*pi, numTicks);
                    minorTickAngles = linspace(pi, 2*pi, numMinorTicks);

                    radialLines = zeros(2, numTicks*2); % DrawLines takes a 2x(n*2) vector of x-y coordinates, with each pair of pairs indicating the start and end point of the tick
                    minRadialLines = zeros(2, numMinorTicks*2);

                    for n = 1:numTicks
                        radialLines(1,(n*2-1)) = round(innerRadius * cos(tickAngles(n)) + center(1)); % inner x coordinate of tick
                        radialLines(2,(n*2-1)) = round(innerRadius * sin(tickAngles(n)) + center(2)); % inner y coordinate
                        radialLines(1,(n*2)) = round(outerRadius * cos(tickAngles(n)) + center(1)); % outer x coordinate
                        radialLines(2,(n*2)) = round(outerRadius * sin(tickAngles(n)) + center(2)); % outer y coordinate


                        textTick = ['$',num2str(majorTicks(n))];

                        textLocX = round(textRadius * center(2) * cos(tickAngles(n)) + center(1)) - 12;
                        textLocY = round(textRadius * .95 * center(2) * sin(tickAngles(n)) + center(2));

                        Screen('DrawText', window, textTick, textLocX, textLocY, textColor, [0 0 0], center(2));    


                    end

                    for n = 1:numMinorTicks
                        minRadialLines(1,(n*2-1)) = round(innerRadius * cos(minorTickAngles(n)) + center(1)); % inner x coordinate of tick
                        minRadialLines(2,(n*2-1)) = round(innerRadius * sin(minorTickAngles(n)) + center(2)); % inner y coordinate
                        minRadialLines(1,(n*2)) = round(minorRadius * cos(minorTickAngles(n)) + center(1)); % outer x coordinate
                        minRadialLines(2,(n*2)) = round(minorRadius * sin(minorTickAngles(n)) + center(2)); % outer y coordinate
                    end

                    Screen('DrawLines', window, radialLines, 3, scaleColor);
                    Screen('DrawLines', window, minRadialLines, 2, scaleColor);
                    Screen('FrameArc', window, scaleColor, [center(1)-innerRadius, center(2)-innerRadius, center(1)+innerRadius, center(2)+innerRadius], 270, 180, 5, 5);

                    ShowCursor('Arrow');

                    Screen('Flip',window,0,0);

               
                    [xMouse, yMouse, buttons] = GetMouse;
                    xDist = xMouse - center(1);
                    yDist = center(2) - yMouse;
                    rMouse = sqrt(xDist^2 + yDist^2);
                    thMouse = atan2(abs(yDist),xDist);
                    
                    if GetSecs - lastCheck > checkRate
                        traj = [traj; xDist,yDist];
                        lastCheck = GetSecs;
                    end
                    
                    if rMouse >= innerRadius
                        resp = ((scaleMax - scaleMin) - (scaleMax-scaleMin)*thMouse/pi) + scaleMin;
                        DrawFormattedText(window,['Response: \n $',num2str(round(resp*100)/100,'%.2f')],'center',centerY*.8,fTextColor, 80, 0, 0, 1.5, 0, [0,0,centerX*2,centerY*2]);
                    
                        if any(buttons)
                            thisRT = GetSecs - t0;
                            click = 1;
                        end
                    end
                end
                
                Screen('Flip',window,0,0);
                pause(.3);
                
                if isSpeed == 1 && thisRT > 7.5
                    DrawFormattedText(window,'Try to respond faster (< 7.5 seconds). Remember, this is a SPEED condition!','center','center',[255 255 100], 40, 0, 0, 1.5);
                    Screen('Flip',window,0,0);
                    pause(2.5);
                end
                
                dataMat.trial(trialNum).resp = resp;
                dataMat.trial(trialNum).rt = thisRT;
                dataMat.trial(trialNum).stim = [gamblePay,gambleProb,gambleDelay];
                dataMat.trial(trialNum).traj = traj;
                dataMat.trial(trialNum).isSpeed = isSpeed;
                dataMat.trial(trialNum).blockNum = bN;
                dataMat.trial(trialNum).trialInBlock = tN;
                
            otherwise
                
        end
        save(fileName,'dataMat'); % saves data from the trial to filename
        save(shortName,'dataMat'); % saves data from the trial to shortname
        trialNum = trialNum + 1; % increments trialNum
    end        
end

%% Task end

DrawFormattedText(window,'You are all done with this session of the experiment! Please inform the experimenter.','center',centerY,[255 255 255], 80, 0, 0, 1.5);

Screen('Flip',window,0,0);

pause(2);

clicked = 0;
while clicked == 0 % does this loop just allow the participant to click without breaking anything? What if it was removed?
    [x,y,buttons] = GetMouse;
    if any(buttons)
        clicked = 1;
    end
end

toc % read elapsed time from stopwatch (total session time)
ListenChar(0); % turns off keystroke recording and clears buffer
Screen('CloseAll'); % close screens

rMax = length(dataMat.trial); % rMax = total number of trials
rSet = 1:rMax; % rSet = vector of all trials

%% Payment
disp(['Sampling ',num2str(nGamblePlays),' lotteries...']) % display value of 2 gambles (displays in command window?)

trialIndices = datasample(rSet,nGamblePlays); % pulls 1 trials from the rSet list

for m = 1:nGamblePlays 
    tgPlay = trialIndices(m); % determines which gambles were pulled
    tgSpeed = dataMat.trial(tgPlay).isSpeed; % determines if pulled gambles were speed trials
    
    if tgSpeed == 1
        if rand > .75 %% sometimes resample if speed trial is draw (makes precision more likely)
            tgPlay = datasample(rSet,1); % redraws one trial
            disp('Resampling trials to give more precision trials...')
        end
    end
    
    tgSpeed = dataMat.trial(tgPlay).isSpeed; % records trial information
    tgType = dataMat.trial(tgPlay).type;
    tgResp = dataMat.trial(tgPlay).resp;
    tgStim = dataMat.trial(tgPlay).stim;
    ev = (tgStim(1)*tgStim(2)/100)/(1+(.01*tgStim(3))); 
    tgRT = dataMat.trial(tgPlay).rt;
    
    disp('    ')
    
    if tgSpeed == 1
        disp(['Lottery #',num2str(m),': SPEED trial'])
        if (tgRT < 7.5 && tgType == 2 || tgType == 3 || tgType == 5 || tgType == 6) || (tgRT < 3.5 && tgType == 1 || tgType == 4) % if price, determines if RT was <5s, if choice, determines if RT was <2s #UPDATED
            disp('++ YOU COMPLETED THE TRIAL IN TIME! BONUS +$2 ++')
            dataMat.lotteryPlayed(m).speedBonus = 1; % records bonus from speed trial
        else
            disp('-- YOU DID NOT COMPLETE THE TRIAL IN TIME - NO BONUS. --')
            dataMat.lotteryPlayed(m).speedBonus = 0; % records no bonus from speed trial
        end
    else
        disp(['Lottery #',num2str(m),': PRECISION trial']);
        dataMat.lotteryPlayed(m).speedBonus = []; % records blank for speed bonus (precision trial, no bonus)
    end
        
    dataMat.lotteryPlayed(m).type = tgType;
    dataMat.lotteryPlayed(m).resp = tgResp;
    dataMat.lotteryPlayed(m).stim = tgStim;
    dataMat.lotteryPlayed(m).EV = ev;
    dataMat.lotteryPlayed(m).isSpeed = tgSpeed;
    
    
    
    
    if tgType == 1 % choice (+)
        if tgResp == 1
            disp(['You chose a lottery with ',num2str(tgStim(5),'%.0f'),'% chance of gaining $',num2str(tgStim(4),'%.2f'),' after a delay of ',num2str(tgStim(6)),' days','.'])
            disp(['++++ YOU WILL PLAY THIS LOTTERY ++++']); % where do they do the "playing" of this lottery? Does it occur outside of this script?
        else
            disp(['You chose a lottery with ',num2str(tgStim(2),'%.0f'),'% chance of gaining $',num2str(tgStim(1),'%.2f'),' after a delay of ',num2str(tgStim(3)),' days','.'])
            disp(['++++ YOU WILL PLAY THIS LOTTERY ++++']);
        end
        dataMat.lotteryPlayed(m).wasAccepted = 1;
        dataMat.lotteryPlayed(m).typeString = 'Choice gain';
    elseif tgType == 2 % buying (+)
        disp(['You bid $',num2str(tgResp,'%.2f'),' to obtain a lottery with ',num2str(tgStim(2),'%.0f'),'% chance of gaining $',num2str(tgStim(1),'%.2f'),' after a delay of ',num2str(tgStim(3)),' days','.'])
        if tgResp < min(3,ev/3) % if price was < ev/3 or 3 (whichever is lower) 
            disp('---- THIS BID WAS REJECTED FOR BEING TOO LOW, YOU WILL KEEP THE MONEY YOU OFFERED FOR IT ----');
            dataMat.lotteryPlayed(m).wasAccepted = 0;
        else
            disp('++++ THIS BID WAS ACCEPTED, YOU WILL PLAY THIS LOTTERY ++++')
            dataMat.lotteryPlayed(m).wasAccepted = 1;
        end
        dataMat.lotteryPlayed(m).typeString = 'Buying gain';
    elseif tgType == 3 % selling (+)
        disp(['You asked for $',num2str(tgResp,'%.2f'),' to sell a lottery with ',num2str(tgStim(2),'%.0f'),'% chance of gaining $',num2str(tgStim(1),'%.2f'),' after a delay of ',num2str(tgStim(3)),' days','.'])
        if tgResp > min(tgStim(1),1.5*ev) % if price was higher than the payout or 1.5*ev (whichever is lowest)
            disp('---- THIS PRICE WAS REJECTED FOR BEING TOO HIGH, YOU WILL KEEP (PLAY) THIS LOTTERY ----')
            dataMat.lotteryPlayed(m).wasAccepted = 0;
        else
            disp('++++ THIS PRICE WAS ACCEPTED, YOU WILL RECEIVE THE REQUESTED PRICE FOR THE LOTTERY ++++')
            dataMat.lotteryPlayed(m).wasAccepted = 1;
        end
        dataMat.lotteryPlayed(m).typeString = 'Selling gain';
    elseif tgType == 4 % choice (-)
        if tgResp == 1
            disp(['You chose a lottery with ',num2str(tgStim(5),'%.0f'),'% chance of losing $',num2str(tgStim(4),'%.2f'),' after a delay of ',num2str(tgStim(6)),' days','.'])
            disp(['++++ YOU WILL PLAY THIS LOTTERY ++++']); % where do they do the "playing" of this lottery? Does it occur outside of this script?
        else
            disp(['You chose a lottery with ',num2str(tgStim(2),'%.0f'),'% chance of losing $',num2str(tgStim(1),'%.2f'),' after a delay of ',num2str(tgStim(3)),' days','.'])
            disp(['++++ YOU WILL PLAY THIS LOTTERY ++++']);
        end
        dataMat.lotteryPlayed(m).wasAccepted = 1;
        dataMat.lotteryPlayed(m).typeString = 'Choice loss';
    elseif tgType == 5 % buying (-)
        disp(['You bid $',num2str(tgResp,'%.2f'),' to avoid a chance to lose a lottery with ',num2str(tgStim(2),'%.0f'),'% chance of losing $',num2str(tgStim(1),'%.2f'),' after a delay of ',num2str(tgStim(3)),' days','.'])
        if tgResp < min(3,ev/3) % if price was < ev/3 or 3 (whichever is lower) 
            disp('---- THIS BID WAS REJECTED FOR BEING TOO LOW, YOU WILL KEEP THE MONEY YOU OFFERED FOR IT AND PLAY THIS LOTTERY ----');
            dataMat.lotteryPlayed(m).wasAccepted = 0;
        else
            disp('++++ THIS BID WAS ACCEPTED, YOU AVOIDED PLAYING THIS LOTTERY ++++')
            dataMat.lotteryPlayed(m).wasAccepted = 1;
        end
        dataMat.lotteryPlayed(m).typeString = 'Buying loss';
    else % selling  (-)
        disp(['You asked for $',num2str(tgResp,'%.2f'),' to take on the chance to lose lottery with ',num2str(tgStim(2),'%.0f'),'% chance of losing $',num2str(tgStim(1),'%.2f'),' after a delay of ',num2str(tgStim(3)),' days','.'])
        if tgResp > min(tgStim(1),1.5*ev) % if price was higher than the payout or 1.5*ev (whichever is lowest)
            disp('---- THIS PRICE WAS REJECTED FOR BEING TOO HIGH, YOU WILL NOT PLAY THIS LOTTERY ----')
            dataMat.lotteryPlayed(m).wasAccepted = 0;
        else
            disp('++++ THIS PRICE WAS ACCEPTED, YOU WILL RECEIVE THE REQUESTED PRICE FOR THE LOTTERY AND PLAY THIS LOTTERY ++++')
            dataMat.lotteryPlayed(m).wasAccepted = 1;
        end
        dataMat.lotteryPlayed(m).typeString = 'Selling loss';
    end
end

save(fileName,'dataMat'); % save data to filename
save(shortName,'dataMat'); % save data to shortname