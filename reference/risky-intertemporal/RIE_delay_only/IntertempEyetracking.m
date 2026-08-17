
%%

% Conditions :

% 5 = Delay - Binary choice
% 6 = Delay - Willingness to pay 

% The stimuli csv files have 6 columns for the three attributes. And not
% all the questions are tuned to be delay discounting questions, i.e.,
% there are a lot of "catch" trials as is.
% Along with this there are currently 6 locations things are displayed at,
% but a delay only version would only require four of the six locations.


%% experiment prep

clear;   % clears all vars from workspace, idk how it differs from clearvars

% Eye tracker files path
% UPDATE -- add tobii files to path
addpath(genpath('L:\Kvam Lab\TobiiPro.SDK.Matlab_1.9.0.59'));
addpath(genpath('L:\Kvam Lab\RiskyIntertemporalEyetracking'));

% Eye tracker setup
tobii = EyeTrackingOperations();
found_eyetrackers = tobii.find_all_eyetrackers()
my_eyetracker = found_eyetrackers(1)
disp(["Address: ", my_eyetracker.Address])
disp(["Model: ", my_eyetracker.Model])
disp(["Name (It's OK if this is empty): ", my_eyetracker.Name])
disp(["Serial number: ", my_eyetracker.SerialNumber])

tic     % starts stopwatch timer

Screen('Preference','SkipSyncTests', 1);    %Change global setting for screen to ignore sync tests (sync to monitor refresh rate - avoid flickering), idk what 1 at the end does?
Screen('Preference', 'SuppressAllWarnings', 1);     %Change global setting for screen to not display warnings, idk what 1 does?

subjectNum = input('Participant #: ');
sessionNum = input('Session #: ');      % creates sessionNum variable by prompting subject to input session

s = rng('shuffle');     %creates s variable, seeds random number generator based on the current time

dataMat = struct; % structure for storing data
dataMat.randomSeed = s;     % adds randomSeed = s to data array
dataMat.SubjectNumber = subjectNum;     % adds SubjectNumber = subjectNum to data array

fileName = strcat('Data\TimingITV',num2str(subjectNum),'_',datestr(now, 'yyyymmdd_HHMMSS'));      %creates fileName variable, concatenate string
shortName = strcat('TimingITV',num2str(subjectNum));      %creates shortName variable, concatenate string

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


halfX = .5*centerX;
hypDist = sqrt(centerY^2+halfX^2);
midAdjust = hypDist-halfX;

leftTop = [.5*centerX, 0, centerX, centerY]; % draws left top
leftBot = [.5*centerX, 0, centerX, centerY*3]; % draws left bottom
rightTop = [centerX, 0, centerX*1.5, centerY]; % draws right top
rightBot = [centerX, 0, centerX*1.5, centerY*3]; % draws right bottom

leftMid = [.5*centerX-midAdjust, 0, centerX, centerY*2]; % draws left middle
rightMid = [centerX, 0, centerX*1.5+midAdjust, centerY*2]; % draws right middle

%%
LocationMatrix = {leftTop,leftBot,rightTop,rightBot;...
                  leftBot,leftTop,rightBot,rightTop
                };
            
halfY = .5*centerY;
halfX = .5*centerX;
hypDist = sqrt(halfX^2+halfY^2);
topAdjust = hypDist-halfY;            
            
priceTop = [centerX, 0, centerX, centerY*1.5-topAdjust];
priceLeft = [0.5*centerX, 0, centerX, centerY*2.5];
priceRight = [centerX, 0, centerX*1.5, centerY*2.5];

priceLocationMatrix = {priceTop,priceLeft,priceRight;...
                  priceTop,priceRight,priceLeft;...
                  priceLeft,priceTop,priceRight;...
                  priceLeft,priceRight,priceTop;...
                  priceRight,priceTop,priceLeft;...
                  priceRight,priceLeft,priceTop
                };

            

%% Gambles Moved down to subject counterbalancing to make sure everyone prices the same gambles

gambles = csvread('RIEgambles.csv'); 
gambleOrder = randperm(length(gambles));  
nG = 1; % counter tracking the index of the current gamble

gPairs = csvread('RIEgamblepairs.csv'); % creates gPairs variable with data imported from gamblepairs csv file
gPairOrder = randperm(length(gPairs));  %creates gPairOrder variable with the gamblepairs randomly suffled, idk why listed twice?
nGP = 1; % counter tracking the index of the current gamble pair

%% Types of trials

% 42 choice trials (2 blocks)
% 84 pricing trials (2 blocks)    
nConds = [1 2]; % 1 choice, 2 price 
nBlocksEachCond = 2;       
nTrialsPerPriceBlock = 84; 
nTrialsPerChoiceBlock = 42;
nPractice = 12;  
nScalePractice = 8;  
 

if subjectNum == 9999     
    nBlocksEachCond = 2;    
    nTrialsPerBlock = 2;
    nPractice = 2;
    nScalePractice = 2;
end


trialNum = 1;




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

    textStr1 = ['In this experiment, you will price lotteries as well as make decisions between pairs of lotteries. Each lottery consists of a payoff ($), a chance of winning (%), and a delay (days).'];  %text strings to display
    textStr2 = [' 45% \n','$14 \n','7 days'];
    textStr3 = ['If you were to play this lottery, you would have a 45 in 100 chance of winning $14 after waiting 7 days, and a 55 in 100 chance of receiving $0.'];
    textStr4 = ['On one day of this three session experiment, these lotteries will be like the example.'];
    textStr5 = ['On one day every lottery will be certain (100% chance), and another day every lottery will be immediate (0 days). \n \n (Click the left mouse button to continue)'];
    
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
        '\n \n 2) BUY / indicate the maximum amount a person might pay to play the lottery.'];
   textStr3 = ['DECIDE and BUY are organized in blocks, so you only have to do one at a time',...
        '\n (Click the left mouse button to continue)'];

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
    
orderInd = randi([1 2],1,2);

nPracticeBlocks = round(nPractice/2);

for w = 1:nPracticeBlocks
    
    Order = orderInd(w);
    Locations = {LocationMatrix{Order,:}};
    
    for n = 1:(nPractice/nPracticeBlocks)
         DrawFormattedText(window, ['+'], 'center', 'center', [255 255 255], 80, 0, 0, 1.4); % draw gray fixation cross
         DrawFormattedText(window, ['(Click on the + to start)'],'center',centerY+150,[255 255 255],80, 0, 0, 1.4); %display instructions to click on fixation cross
         
         DrawFormattedText(window,['$'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{1}); % draws left stimulus
         DrawFormattedText(window,['days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{2}); % draws right stimulus
         DrawFormattedText(window,['$'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{3}); % draws left stimulus
         DrawFormattedText(window,['days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{4}); % draws right stimulus
        

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
        gamble1delay = round((rand*25000)/100); %generates a random delay 0-250 rounded to integer

        gamble2pay = round((rand*2000)/100);
        gamble2delay = round((rand*25000)/100);
        
       
        DrawFormattedText(window,['$',num2str(gamble1pay,'%.2f')], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{1}); % draws left stimulus
        DrawFormattedText(window,[num2str(gamble1delay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{2}); % draws right stimulus
        DrawFormattedText(window,['$',num2str(gamble2pay,'%.2f')], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{3}); % draws left stimulus
        DrawFormattedText(window,[num2str(gamble2delay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{4}); % draws right stimulus
      
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
end   

    %% Rating Instructions

    click = 0;
    while click == 0
        DrawFormattedText(window,'On BUY trials, you will enter the maximum buying price using a scale like this one.','center',centerY*1.3,[255 255 255], 80, 0, 0, 1.5);
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

    nSP = 1; 
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

    DrawFormattedText(window,'Click the left mouse button to begin the experiment.','center',centerY*1.6,[255 255 255], 80, 0, 0, 1.5);

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

%% Main loop

eachCond= randperm(2);
for bN = 1:nBlocksEachCond % repeat loop for the number of blocks
    pause(.5);
    blockType = eachCond(bN); 
    
    
    switch blockType % execute one statement for the corresponding blocktype
        case 1
            DrawFormattedText(window, ['The following are DECIDE trials. Click the right mouse button for a chance to obtain the option on the right, or the left mouse button for a chance to obtain the one on the left.'], 'center', centerY-50, [255 255 255], 80, 0, 0, 1.4);
        case 2
            DrawFormattedText(window, ['The following are BUY trials. Specify the maximum amount you might pay to play the lottery.'], 'center', centerY-50, [255 255 255], 80, 0, 0, 1.4);
   
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
    

    switch blockType % execute one statement for the corresponding blocktype
        case 1
            nTrialsPerBlock = nTrialsPerChoiceBlock;
        case 2
            nTrialsPerBlock = nTrialsPerPriceBlock;

    end 
    
    
    
 nTrials = round(nTrialsPerBlock/2);

 orderInd = randperm(nBlocksEachCond);

for w = 1:nBlocksEachCond
    
    Order = orderInd(w);
    Locations = {LocationMatrix{Order,:}};
    priceLocations = {priceLocationMatrix{Order,:}};
    
  
    for tN = 1:nTrials
        dataMat.trial(trialNum).type = blockType; % record block type for subsequent trials
        
        %% Fixation
        DrawFormattedText(window, ['+'], 'center', 'center', [255 255 255], 80, 0, 0, 1.4); % draw gray fixation cross
         
        switch blockType
            case 1
                DrawFormattedText(window, ['DECIDE'], 'center', centerY + 100, [255 255 255], 80, 0, 0, 1.4);
                DrawFormattedText(window,['$'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{1}); % draws left stimulus
                DrawFormattedText(window,['days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{2}); % draws right stimulus
                DrawFormattedText(window,['$'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{3}); % draws left stimulus
                DrawFormattedText(window,['days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{4}); % draws right stimulus
        
            case 2
                DrawFormattedText(window, ['BUY'], 'center', centerY + 100, [255 255 255], 80, 0, 0, 1.4);
                DrawFormattedText(window,['$'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, priceLocations{1}); % draws left stimulus
                DrawFormattedText(window,['days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, priceLocations{2}); % draws right stimulus
        
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
                %% Binary gambles delay
                dataMat.trial(trialNum).typeText = 'choice'; % records choice trial type
                dataMat.trial(trialNum).type = 1; % numerical code for choice trial
                 
                gpIndex = gPairOrder(nGP); % gpIndex = randomized gPairs with counter
                nGP = nGP + 1; % interates counter each loop
                dataMat.trial(trialNum).gambleNum = gpIndex;  % records gpIndex for each trial, tracks trialnumber within block
                sidePres = rand;
                if sidePres > .5 % randomize right and left presentation
                    gamble1pay = gPairs(gpIndex,1);
                    gamble1delay = gPairs(gpIndex,2);
                    gamble2pay = gPairs(gpIndex,3);
                    gamble2delay = gPairs(gpIndex,4);
                    largerSide = -1;
                else
                    gamble1pay = gPairs(gpIndex,3);
                    gamble1delay = gPairs(gpIndex,4);
                    gamble2pay = gPairs(gpIndex,1);
                    gamble2delay = gPairs(gpIndex,2);
                    largerSide = 1;
                end
                
            DrawFormattedText(window,['$',num2str(gamble1pay,'%.2f')], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{1}); % draws left stimulus
            DrawFormattedText(window,[num2str(gamble1delay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{2}); % draws right stimulus
            DrawFormattedText(window,['$',num2str(gamble2pay,'%.2f')], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{3}); % draws left stimulus
            DrawFormattedText(window,[num2str(gamble2delay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, Locations{4}); % draws right stimulus
        
                Screen('Flip',window,0,0);
                
                t0 = GetSecs; % real-time at start of trial
                HideCursor();
                
                %%% start eyetracking
                my_eyetracker.get_gaze_data();
                
                click = 0;
                
                while click == 0
                    [xMouse, yMouse, buttons] = GetMouse;
                    if buttons(1) || buttons(3)
                        thisRT = GetSecs - t0;
                        %%% stop eye tracking
                        gaze_data = my_eyetracker.get_gaze_data();
                        dataMat.trial(trialNum).gazeData = gaze_data;
                        my_eyetracker.stop_gaze_data()
                        %%%
                        if buttons(1)
                            click = -1; % participant clicked left
                        elseif buttons(3)
                            click = 1; % participant clicked right
                        end
                    end
                end
                
                if click == largerSide
                    choice = 1;
                else
                    choice = 0;
                end
                
                if gpIndex == 1
                    BonusChoice = choice;
                end
                
                Screen('Flip',window,0,0);
                pause(.3);
                
             
                dataMat.trial(trialNum).resp = choice; %records left/right choice
                dataMat.trial(trialNum).rt = thisRT; %records RT
                dataMat.trial(trialNum).stim = [gamble1pay,gamble1delay,gamble2pay,gamble2delay]; %records choice stimuli
                dataMat.trial(trialNum).traj = []; %records nothing for mouse trajectory, because there isn't anything to track
                dataMat.trial(trialNum).blockNum = bN; %records block number
                dataMat.trial(trialNum).trialInBlock = tN; % records trial number
                dataMat.trial(trialNum).StimLocation = Order; % records stimuli locations
                dataMat.trial(trialNum).largerSide = largerSide;
                
            case 2
                %% Willingness to accept (selling) (-)
                dataMat.trial(trialNum).typeText = 'price'; % records WTA trial type
                dataMat.trial(trialNum).type = 2; 
                
                gIndex = gambleOrder(nG);
                nG = nG + 1;
                dataMat.trial(trialNum).gambleNum = gIndex;
                gamblePay = gambles(gIndex,1);
                gambleDelay = gambles(gIndex,2);
                
                t0 = GetSecs;

                
                                %%% start eyetracking
                my_eyetracker.get_gaze_data(); % If broken, comment this out and uncomment start below
                
                click1 = 0;
                click = 1;
                
                while click1 == 0
                
                    DrawFormattedText(window,['$',num2str(gamblePay,'%.2f')], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, priceLocations{1}); % draws left stimulus
                    DrawFormattedText(window,[num2str(gambleDelay),' days'], 'center', 'center',[255 255 255], 80, 0, 0, 1.5, 0, priceLocations{2}); % draws right stimulus
                    DrawFormattedText(window,'What is the maximum price you would PAY to play this option? \n Once you have determined the price you would pay, right click to enter your price on the next screen','center','center',[255 255 255], 80, 0, 0, 1.5, 0, [0,centerY,centerX*2,centerY*2.5]);
                    
                    HideCursor();
                    
                    Screen('Flip',window,0,0);
                    
                    
                    [x,y,buttons] = GetMouse;
                    if buttons(3)
                            thisRT = GetSecs - t0; %records RT for choice
                            %%% stop eye tracking
                            gaze_data = my_eyetracker.get_gaze_data();
                            dataMat.trial(trialNum).gazeData = gaze_data;
                            my_eyetracker.stop_gaze_data()
                            %%%
                            click1 = 1;
                            click = 0;
                    end
                        
                    
                end
                
                traj = [0,0]; % Move traj outside while for other conds
                    t0 = GetSecs; % real-time at start of trial
                    lastCheck = t0;
                
                while click == 0
                    
                    
                    
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
                    
                
                    
                    %traj = [0,0];
               
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
                        DrawFormattedText(window,['Response: \n $',num2str(round(resp*100)/100,'%.2f')],'center',centerY*.8,[255 255 125], 80, 0, 0, 1.5, 0, [0,0,centerX*2,centerY*2]);
                    
                        if buttons(1) && click1 == 1
                            click = 1;
                        end
                    end
                end
                
                Screen('Flip',window,0,0);
                pause(.3);
                
                
                
                dataMat.trial(trialNum).resp = resp;
                dataMat.trial(trialNum).rt = thisRT;
                dataMat.trial(trialNum).stim = [gamblePay,gambleDelay];
                dataMat.trial(trialNum).traj = traj;
                dataMat.trial(trialNum).blockNum = bN;
                dataMat.trial(trialNum).trialInBlock = tN;
                dataMat.trial(trialNum).StimLocation = Order; % records stimuli locations
                dataMat.trial(trialNum).largerSide = [];
                
           
                
        end
        trialNum = trialNum + 1; % increments trialNum
    end        
end
DrawFormattedText(window,'Saving your data... please wait.','center',centerY,[255 255 255], 80, 0, 0, 1.5);

Screen('Flip',window,0,0);

save(fileName,'dataMat'); 
save(shortName,'dataMat'); 
end

%% Timing Experiment

fileName2 = strcat('TIME',num2str(subjectNum),'_',datestr(now, 'yyyymmdd_HHMMSS'));
shortName2 = strcat('TIME',num2str(subjectNum));

startTime2 = GetSecs;

Screen('Preference', 'SkipSyncTests', 1);
[window, ScreenRect] = Screen('OpenWindow', 0, 0);
centerX = (ScreenRect(3) - ScreenRect(1))/2;
centerY = (ScreenRect(4) - ScreenRect(2))/2;
center = [centerX centerY];

spf = Screen('GetFlipInterval', window); % seconds per frame
fps = floor(1/spf); % frames per second, used to see how often we can flip the screen

% ListenChar(2);
AssertOpenGL;
s = rng('shuffle');

dataMat2 = struct;
dataMat2.startTime = startTime2;
dataMat2.randSeed = s;

%% Experiment details

ballDistances = [.5 .8];
ballSpeeds = [1.5 3];
ballOcclusions = [150 400];

wallLoc = centerX*1.5;
ballSize = 10;

wallRect = [wallLoc-2; centerY/2; wallLoc+2; centerY*1.5];
occlusionBoxes = [wallRect(1)-ballOcclusions; centerY*.8,centerY*.8; ...
                  wallRect(1),wallRect(1); centerY*1.2,centerY*1.2];


if subjectNum == 9999
    nBlocksTime = 2;
    nTrialsPerTimeBlock = 4;
else
    
end

nCondsTime = length(ballDistances) * length(ballSpeeds) * length(ballOcclusions);
nTrialsTime = nBlocksTime * nTrialsPerTimeBlock;
nTrialsPerCond = nTrialsTime / nCondsTime;

condList2 = repmat(1:nCondsTime,[1,nTrialsPerCond]);
condList2 = condList2(randperm(length(condList2)));

HideCursor;

totalPts = 0;

%% Main trials

j = 1;

for b = 1:nBlocksTime
    for n = 1:nTrialsPerTimeBlock
        bPressed = 0;
        
        distNum = mod(condList2(j),2)+1;
        dist = ballDistances(distNum); % even trials = near, odd trials = far
        
        speedNum = ceil(condList2(j)*2/nConds);
        speed = ballSpeeds(ceil(condList2(j)*2/nConds));
        
        occNum = mod(ceil(condList2(j)/2),2)+1;
        occ = occlusionBoxes(:,occNum);
        
        ballLoc = [wallLoc-dist*centerX, centerY];
        Screen('FillRect',window,[255 255 255],wallRect);
        Screen('FillOval',window,[255 200 0],[ballLoc(1)-ballSize; ballLoc(2)-ballSize; ballLoc(1)+ballSize; ballLoc(2)+ballSize]);
        Screen('FillRect',window,[155 155 155],occ);
        DrawFormattedText(window, 'Click the mouse when you are ready to begin the trial.', 'center', centerY/2, [255 255 255], 80, 0, 0, 1.4);
        Screen('Flip',window,0,0);
        
        aPressed = 0;
        while aPressed == 0 % wait for button to be pressed to start the trial
            [xMouse, yMouse, buttons] = GetMouse;
            if any(buttons)
                aPressed = 1;
            end
        end
        
        while any(buttons) % wait for buttons to be released
            [xMouse, yMouse, buttons] = GetMouse;
        end
        
        t0 = GetSecs;
        my_eyetracker.get_gaze_data();
        while bPressed == 0
            [xMouse, yMouse, buttons] = GetMouse;
            
            if any(buttons)
                bPressed = 1;
                rt = GetSecs - t0;
                TimeGaze_data = my_eyetracker.get_gaze_data();
                dataMat2.trial(j).gazeData = TimeGaze_data;
                my_eyetracker.stop_gaze_data()
            end
            
            Screen('FillRect',window,[255 255 255],wallRect);
            if (ballLoc(1) + ballSize) < wallRect(1)
                Screen('FillOval',window,[255 200 0],[ballLoc(1)-ballSize; ballLoc(2)-ballSize; ballLoc(1)+ballSize; ballLoc(2)+ballSize]);
            end
            Screen('FillRect',window,[155 155 155],occ);
            Screen('Flip',window,0,0);
            ballLoc = [ballLoc(1) + speed, ballLoc(2)];
            
        end
        
        Screen('Flip',window,0,0);
        WaitSecs(.5);
        
        trueTime = spf * dist * centerX / speed;
        pts = round(10 - 5*abs(rt - trueTime)); % 0 - 10 points per trial
        totalPts = totalPts + pts;

        dataMat.trial(j).rt = rt;
        dataMat.trial(j).distNum = distNum;
        dataMat.trial(j).dist = dist;
        dataMat.trial(j).occNum = occNum;
        dataMat.trial(j).occ = occ;
        dataMat.trial(j).speedNum = speedNum;
        dataMat.trial(j).speed = speed;
        dataMat.trial(j).trueTime = trueTime;
        dataMat.trial(j).pts = pts;
        
        j = j + 1; % overall trial number
        
        save(fileName2,'dataMat2');
        
    end
    
    dataMat2.totalPts = totalPts;
    
end

save(fileName2,'dataMat2');
save(shortName2,'dataMat2');



ListenChar(0);
Screen('CloseAll');
 

    
    %% Task End

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

save(fileName,'dataMat'); % save data to filename
save(shortName,'dataMat'); % save data to shortname
save(fileName2,'dataMat2');
save(shortName2,'dataMat2');