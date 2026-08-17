clear; 



%% Eyetracker prep

% Eye tracker files path
% UPDATE -- add tobii files to path
% addpath(genpath('L:\Kvam Lab\TobiiPro.SDK.Matlab_1.9.0.59'));
% addpath(genpath('L:\Kvam Lab\JobHouse'));

% Eye tracker setup
% tobii = EyeTrackingOperations();
% found_eyetrackers = tobii.find_all_eyetrackers()
% my_eyetracker = found_eyetrackers(1)
% disp(["Address: ", my_eyetracker.Address])
% disp(["Model: ", my_eyetracker.Model])
% disp(["Name (It's OK if this is empty): ", my_eyetracker.Name])
% disp(["Serial number: ", my_eyetracker.SerialNumber])

%% Initalize experiment environment and Psychtoolbox

% subjectNum = input('Participant #: ');
% sessionNum = input('Session #: ');      % creates sessionNum variable by prompting subject to input session
% housingRange = input(['What range of house values would you like to see first?' newline ...
%     '1 = $0 - 250,000' newline ...
%     '2 = $250,001 - 400,000' newline ...
%     '3 = $400,001 - 500,000' newline ...
%     '4 = $500,001 - 700,000' newline ...
%     '5 = $700,000 - 1,000,000' newline ...
%     '6 = $1,000,000+' newline ...
%     'Enter the number corresponding to the price range you want to see: ']);
subjectNum = 9999;
sessionNum = 2;
housingRange = 1;

if subjectNum == 9999
    maxTime = 20;
else
    maxTime = 2000;
end


s = rng('shuffle');     % creates s variable, seeds random number generator based on the current time

dataMat = struct; % structure for storing data
dataMat.randomSeed = s;     % adds randomSeed = s to data array
dataMat.SubjectNumber = subjectNum;     % adds SubjectNumber = subjectNum to data array
dataMat.SessionNumber = sessionNum;     % adds SessionNumber = sessionNum to data array
dataMat.valueRange = housingRange;

fileName = strcat('Data\JHO',num2str(subjectNum),'_',datestr(now, 'yyyymmdd_HHMMSS'));      %creates fileName variable, concatenate string
shortName = strcat('JHO',num2str(subjectNum),'-',num2str(sessionNum));      %creates shortName variable, concatenate string

startTime = GetSecs;    %creates startTime variable, records real-time start

Screen('Preference', 'SkipSyncTests', 1)
% Screen('Preference','SyncTestSettings' ,0.002,50,0.1,5);
[window, ScreenRect] = Screen('OpenWindow', 2, 0);  %opens black rectangular window on the screen
centerX = (ScreenRect(3) - ScreenRect(1))/2;    %creates centerX variable at the center of the screen's X axis
centerY = (ScreenRect(4) - ScreenRect(2))/2;    %creates centerY variable at the center of the screen's Y axis
center = [centerX centerY];     %creates center varible with values from the center of the x and y axes
Screen('BlendFunction', window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);  %allows new colors to be blended with previous colors on screen and defines color blending type?
Screen('Flip', window, 0, 0); % update the window
Screen('TextSize', window, 24);     % text size set to 22
Screen('TextStyle',window,1);     

ListenChar(2);      % records keystroke but supresses input to MATLAB window
AssertOpenGL;       % checks if OpenGL graphics library is working

dataMat.startTime = startTime;  % adds startTime = startTime to data array

ShowCursor('Arrow');

%% Condition information

competitionLevels = [1 2]';
onMarketTimes = [gamrnd(2,15,[1,100]); gamrnd(4,15,[1,100])];

stimRanges = [0 250000 400000 500000 700000 1000000 10000000];

nBlocks = 6;

blockCompLevels = repmat(competitionLevels,[ceil(nBlocks/length(competitionLevels)),1]);
blockCompLevels = blockCompLevels(randperm(length(blockCompLevels)));

dataMat.compLevels = blockCompLevels;


%% Load stimuli and set up experimental conditions
opts = delimitedTextImportOptions("NumVariables", 14);

% Specify range and delimiter
opts.DataLines = [2, Inf];
opts.Delimiter = ",";

% Specify column names and types
opts.VariableNames = ["Zone", "Address", "nBeds", "nBaths", "sqft", "lotSize", "yearBuilt", "listPrice", "extPic", "kitPic", "bedPic", "bathPic", "livPic", "outPic"];
opts.VariableTypes = ["categorical", "string", "double", "double", "double", "double", "double", "double", "string", "string", "string", "string", "string", "string"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, ["Address", "extPic", "kitPic", "bedPic", "bathPic", "livPic", "outPic"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Zone", "Address", "extPic", "kitPic", "bedPic", "bathPic", "livPic", "outPic"], "EmptyFieldRule", "auto");
opts = setvaropts(opts, "listPrice", "TrimNonNumeric", true);
opts = setvaropts(opts, ["listPrice", "sqft"], "ThousandsSeparator", ",");

% Import the stimuli
houseStim = readtable("HouseStimuli.csv", opts);

listOfAttributes = {'Number of bedrooms', 'Number of bathrooms','Square feet', 'Year built','List Price', 'Exterior appearance','Kitchen appearance','Bedroom appearance','Living room appearance','Outside space'};


%% Intro and practice

blockText = ['Welcome to the experiment! Please make sure you have completed informed consent, then click the mouse to begin the experiment.'];
DrawFormattedText(window,blockText,'center',centerY-100,[255 255 255],80, 0, 0, 1.4);
Screen('Flip', window, 0, 0);

button1pressed = 0;
while button1pressed == 0
[xMouse, yMouse, buttons] = GetMouse(window);
if buttons(1)
    button1pressed = 1;
end
end

Screen('Flip',window,0,0);
WaitSecs(1);


blockText = ['Your first task will be to rank different elements of houses in terms of how much importance you place on them. You can do this by simply clicking on the scale provided to rate the importance of each attribute provided.'];
DrawFormattedText(window,blockText,'center',centerY-100,[255 255 255],80, 0, 0, 1.4);
DrawFormattedText(window,'Click the left mouse button to continue.','center',centerY+200,[255 255 255],80, 0, 0, 1.4);
Screen('Flip', window, 0, 0);

button1pressed = 0;
while button1pressed == 0
[xMouse, yMouse, buttons] = GetMouse(window);
if buttons(1)
    button1pressed = 1;
end
end

Screen('Flip',window,0,0);
WaitSecs(1);



%% Attribute rating task

ratingRTs = zeros(length(listOfAttributes),1);
ptsToDraw = [];

for n = 1:length(listOfAttributes)

    respEntered = 0;

    DrawFormattedText(window,'Please place this attribute on the line in terms of how important it would be to you when considering a home purchase.','center',centerY/2,[255 255 255],80, 0, 0, 1.4);
    DrawFormattedText(window,listOfAttributes{n},'center',centerY*.75,[255 255 255],80, 0, 0, 1.4);
    Screen('Flip',window,0,0);
    WaitSecs(1);

    t0 = GetSecs;
    ShowCursor('Arrow');

    while respEntered == 0

        DrawFormattedText(window,'Please place this attribute on the line in terms of how important it would be to you when considering a home purchase.','center',centerY/2,[255 255 255],80, 0, 0, 1.4);
        DrawFormattedText(window,listOfAttributes{n},'center',centerY*.75,[255 255 255],80, 0, 0, 1.4);

        Screen('DrawLines',window,[centerX*.2, centerX*1.8; centerY*1.2, centerY*1.2], 6)
        DrawFormattedText(window,'Entirely unimportant','center',centerY*1.15,[255 255 255],80, 0, 0, 1.4, 0, [0,0,centerX*.4,centerY*2]);
        DrawFormattedText(window,'Extremely important','center',centerY*1.15,[255 255 255],80, 0, 0, 1.4, 0, [centerX*1.6,0,centerX*2,centerY*2]);

        if ~isempty(ptsToDraw)
            Screen('DrawDots',window, ptsToDraw, 25, [155 155 155], [0,0], 1, 1);

            for m = 1:(n-1)
                Screen('DrawLines',window,[ptsToDraw(1,m), ptsToDraw(1,m); centerY*1.2, 20+centerY*1.2+20*m], 3, [155 155 155]);
                DrawFormattedText(window,listOfAttributes{m},ptsToDraw(1,m)+3, 20+ptsToDraw(2,m)+20*m,[155 155 155],80,0,0,1.4);
            end

        end

        [xMouse, yMouse, buttons] = GetMouse(window);

        if abs(xMouse-centerX) < centerX*.8
            if abs(yMouse-(centerY*1.2)) < 100
                Screen('DrawDots',window,[xMouse; centerY*1.2],25,[255 255 255], [0,0], 1, 1);
                if buttons(1)
                    respEntered = 1;
                    ratingRTs(n) = GetSecs - t0;
                    respLoc = [xMouse; centerY*1.2];
                    ptsToDraw = [ptsToDraw, respLoc];
                end
            end
        end

        Screen('Flip',window,0,0);

    end
end

attRatings = ptsToDraw(1,:);

dataMat.attRatings = attRatings;
dataMat.attRatingRTs = ratingRTs;
dataMat.attNames = listOfAttributes;

Screen('Flip',window,0,0);
WaitSecs(2);


%% Directions 2

DrawFormattedText(window,'Well done! In the main task, you will be shown groups of houses. Your task is to select a house you like (left click) and bid for it (scale) while filtering out houses you do not like (right clicks). Click the mouse to continue.','center','center',[255 255 255],80, 0, 0, 1.4);
Screen('Flip',window,0,0);

done = 0;
while done == 0
    [~,~,buttons] = GetMouse;
    if any(buttons)
        done = 1;
    end
end
Screen('Flip',window,0,0);
WaitSecs(1);


thisBox2 = [centerX,0,centerX*2,centerY*2];

%% Directions 3

DrawFormattedText(window,'The initial screen you see will have six "slots" for houses. Some of those will be occupied by houses you can bid for, but others will be blank.','center',centerY-300,[255 255 255],80, 0, 0, 1.4);
DrawFormattedText(window,'You can see the details of a house by left-clicking on it, or remove a house from a slot (allowing a future house to take its place) by right-clicking on it. Click on one of the houses below to see its details.','center',centerY-150,[255 255 255],80, 0, 0, 1.4);

currentStim = [0 0 0 1 2 3];
stimList = showHouseOverviewsDemo(houseStim, currentStim, ScreenRect, window);

dirClick = 0;
while dirClick == 0
    [houseNum, stimNum, buttons] = getHouseNumber(currentStim, ScreenRect, window);

    if buttons(1) && stimNum ~=0
        Screen('Flip',window,0,0);
        WaitSecs(.5);
    
        DrawFormattedText(window,'When you click on a house, you will see a screen like this one giving additional details and pictures of the house. At this point, you can enter a bid (left-click) or decide you do not like it after all (right-click, taking you back to the previous screen).','center', centerY-30,[255 255 255],60, 0, 0, 1.4,0,thisBox2);
        DrawFormattedText(window,'Click the left mouse button now to see what bidding for a house looks like.','center', centerY+300,[255 255 255],60, 0, 0, 1.4,0,thisBox2);
        singleStim = showHouseDetailsDemo(houseStim, stimNum, ScreenRect, window, 1);
        while any(buttons)
            [~,~,buttons] = GetMouse(window);
        end
        while ~any(buttons)
            [~,~,buttons] = GetMouse(window);
        end
        if buttons(1)
            DrawFormattedText(window,'To bid for a house, you should mouse over the scale shown above to move the blue dot around. When the dot is at the location of the bid you want to enter, click the left mouse button to enter the corresponding bid.','center', centerY+200,[255 255 255],60, 0, 0, 1.4,0,thisBox2);
            DrawFormattedText(window,'Click on the scale now to enter a bid for this house.','center', centerY+300,[255 255 255],60, 0, 0, 1.4,0,thisBox2);
            [pricePaid, pricingRT] = showPricingScaleDemo(houseStim, stimNum, ScreenRect, window, 1, 500000); % show response scale and record response
            Screen('Flip',window,0,0);
            dirClick = 1;
        end
    
        
    end
end

Screen('Flip',window,0,0);
WaitSecs(1);

%% Directions 4
DrawFormattedText(window,'You are all done with training and ready to start the main task! For some groups of houses, competition may be HIGH (houses disappear quickly, low bids rejected) or LOW (houses disappear quickly, some low bids accepted). You will be told at the beginning of each block of houses which one it will be.','center','center',[255 255 255],80, 0, 0, 1.4);
DrawFormattedText(window,'Click the left mouse button now to begin the main task.','center',centerY*1.7,[255 255 255],80, 0, 0, 1.4);
Screen('Flip',window,0,0);

done = 0;
while done == 0
    [~,~,buttons] = GetMouse;
    if any(buttons)
        done = 1;
    end
end
Screen('Flip',window,0,0);
WaitSecs(2);


%% Choice task

housingRangeOrder = mod(randperm(nBlocks),length(stimRanges)-1)+1;
dataMat.rangeOrder = housingRangeOrder;

blockNum = 0;
startTime = GetSecs;

while (GetSecs - startTime) < maxTime

    blockNum = blockNum + 1;
    competitionLevel = blockCompLevels(blockNum);

    

    Screen('Flip',window,0,0);
    WaitSecs(1);

    if competitionLevel == 1
        DrawFormattedText(window,'In this block of houses, there will be a LOW level of competition. Houses will disappear more slowly and lower bids might be accepted. Click the mouse to acknowledge this and continue.','center','center',[255 255 255],80, 0, 0, 1.4);
    else
        DrawFormattedText(window,'In this block of houses, there will be a HIGH level of competition. Houses will disappear more quickly and bids below list price are likely to be rejected. Click the mouse to acknowledge this and continue.','center','center',[255 255 255],80, 0, 0, 1.4);
    end
    Screen('Flip',window,0,0);

    trialStarted = 0;

    while trialStarted == 0
        [~,~,buttons] = GetMouse;
        if any(buttons)
            trialStarted = 1;
        end
    end
    Screen('Flip',window,0,0);
    WaitSecs(2);

    housingRange = housingRangeOrder(blockNum);
    minPrice = stimRanges(housingRange);
    maxPrice = stimRanges(housingRange+1)*1.2;
    stimInd = find((houseStim.listPrice >= stimRanges(housingRange)).*(houseStim.listPrice < stimRanges(housingRange+1)));
    stimInd = Shuffle(stimInd);
    
    
    blockStim = houseStim(stimInd,:); % list of stimuli attributes to display this block
    
    nStimsThisBlock = length(stimInd); % number of stimuli to display this block

    currentStim = [0 0 0 stimInd(1:3)'];
    currentStim = Shuffle(currentStim);

    presentedList = stimInd(1:3);
    displayedInd = 3;
    
    marketTimes = datasample(onMarketTimes(competitionLevel,:),nStimsThisBlock); % draw a list of on-market times for houses in the current set
    appearanceTimes = [0, 0, 0, 7:7:200];
    appearanceTimes = appearanceTimes(1:nStimsThisBlock);
    disappearanceTimes = marketTimes + appearanceTimes;

    dataMat.block(blockNum).appearanceTimes = appearanceTimes; 
    dataMat.block(blockNum).marketTimes = marketTimes; 
    dataMat.block(blockNum).disappearanceTimes = disappearanceTimes; 

    displayedHouses = zeros(size(appearanceTimes));
    displayedHouses(1:3) = 1;

    housesWaiting = blockStim(4:nStimsThisBlock,:);


    t0 = GetSecs;

    rejectedStim = [];
    rejectedRTs = [];
    bidsAccepted = [];
    bidsRejected = [];
    bidRTs = [];
    houseNumSelected = [];
    stimSelected = [];
    timeSelected = [];

    trialOver = 0;



    while trialOver == 0

        if (length(presentedList) >= nStimsThisBlock).*(~any(currentStim ~= 0)) % if all stimuli have been presented and none are on the display
            trialOver = 1;
        end
    
        stimList = showHouseOverviews(houseStim, currentStim, ScreenRect, window);
        [houseNum, stimNum, buttons] = getHouseNumber(currentStim, ScreenRect, window);

        toDisplay = (GetSecs-t0) > appearanceTimes;
        if any(double(toDisplay) ~= displayedHouses) % if there is a house that should be displayed that is not already visible
            if any(currentStim == 0)
                dispIndex = find(currentStim == 0);
                thisDisplayIndex = datasample(dispIndex,1); % choose a random spot in the display to add the new house
                displayedInd = displayedInd + 1; % increment the counter going through the stimuli
                currentStim(thisDisplayIndex) = stimInd(displayedInd); % add next stimulus to a zero-location 
                displayedHouses(displayedInd) = 1; % indicate that the next house has been displayed
                housesWaiting = housesWaiting(2:height(housesWaiting),:); % remove the first house on the waiting list
                presentedList = [presentedList; stimInd(displayedInd)];
            end
        end


        if buttons(1) && stimNum ~=0

            houseNumSelected = [houseNumSelected; houseNum];
            stimSelected = [stimSelected; stimNum];
            timeSelected = [timeSelected; GetSecs - t0];

            Screen('Flip',window,0,0);
            WaitSecs(.5);

            DrawFormattedText(window,'Left click = Bid for this house',centerX*1.5, centerY-30,[155 155 155],80, 0, 0, 1.4);
            DrawFormattedText(window,'Right click = Go back',centerX*1.5, centerY+30,[155 155 155],80, 0, 0, 1.4);
            singleStim = showHouseDetails(houseStim, stimNum, ScreenRect, window, 1);
            while any(buttons)
                [~,~,buttons] = GetMouse(window);
            end
            while ~any(buttons)
                [~,~,buttons] = GetMouse(window);
            end
            if buttons(1)
                chosenOption = stimNum;

                
                [pricePaid, pricingRT] = showPricingScale(houseStim, stimNum, ScreenRect, window, 1, maxPrice); % show response scale and record response


                if competitionLevel > 1
                    if pricePaid >= houseStim.listPrice(stimNum)*1.1
                        trialOver = 1;
                        bidAccepted = 1;
                    else
                        trialOver = 0;
                        bidAccepted = 0;
                    end
                else
                    if pricePaid >= houseStim.listPrice(stimNum)*.9
                        trialOver = 1;
                        bidAccepted = 1;
                    else
                        trialOver = 0;
                        bidAccepted = 0;
                    end
                end
                
                if bidAccepted == 1
                    DrawFormattedText(window,'Congrats, your bid was accepted!','center','center',[50 255 155],80,0,0,1.4);
                    bidsAccepted = [bidsAccepted; pricePaid, stimNum];
                    trialRT = GetSecs - t0;
                    Screen('Flip',window,0,0);
                    WaitSecs(3);
                else
                    DrawFormattedText(window,'You were outbid for this house. Keep searching!','center','center',[255 155 50],80,0,0,1.4);
                    Screen('Flip',window,0,0);
                    WaitSecs(3);

                    bidsRejected = [bidsRejected; pricePaid,stimNum];
                    stimList = showHouseOverviews(houseStim, currentStim, ScreenRect, window);
                end

                bidRTs = [bidRTs; pricingRT];

            elseif buttons(2)
                stimList = showHouseOverviews(houseStim, currentStim, ScreenRect, window);
            end

        elseif any(buttons)
            currentStim(houseNum) = 0;
            stimList = showHouseOverviews(houseStim, currentStim, ScreenRect, window);
            rejectedStim = [rejectedStim; stimNum, houseNum];
            rejectedRTs = [rejectedRTs; GetSecs-t0];
            dataMat.block(blockNum).rejectedStim = rejectedStim;
            dataMat.block(blockNum).rejectedRTs = rejectedRTs;
            while any(buttons)
                [~,~,buttons] = GetMouse(window);
            end
            
        end


    end

    dataMat.block(blockNum).bidRTs = bidRTs;
    dataMat.block(blockNum).stimList = stimList;
    dataMat.block(blockNum).bidsRejected = bidsRejected;
    dataMat.block(blockNum).bidsAccepted = bidsAccepted;
    dataMat.block(blockNum).trialRT = trialRT;
    dataMat.block(blockNum).rejectedStim = rejectedStim;
    dataMat.block(blockNum).rejectedRTs = rejectedRTs;
    dataMat.block(blockNum).trialOver = trialOver;
    dataMat.block(blockNum).lastBid = pricePaid;
    dataMat.block(blockNum).competitionLevel = competitionLevel;
   
    dataMat.block(blockNum).displayedHouses = displayedHouses;
    dataMat.block(blockNum).housesWaiting = housesWaiting;

    dataMat.block(blockNum).houseNumSelected = houseNumSelected;
    dataMat.block(blockNum).stimSelected = stimSelected;
    dataMat.block(blockNum).timeSelected = timeSelected;
    dataMat.block(blockNum).chosenOption = chosenOption;
    dataMat.block(blockNum).chosenAtts = houseStim(chosenOption,:);

    Screen('Flip',window,0,0);
    WaitSecs(1);

    DrawFormattedText(window,'You are all done with this block. Saving your data and loading the next block...','center','center',[255 255 255],80, 0, 0, 1.4);
    Screen('Flip',window,0,0);
    WaitSecs(2);
    save(shortName);
    save(fileName)
    Screen('Flip',window,0,0);

end



%% Task end

DrawFormattedText(window,'That''s all the time we have - you are all done with the experiment! Please inform the experimenter.','center',centerY,[255 255 255], 80, 0, 0, 1.5);

Screen('Flip',window,0,0);

pause(2);

clicked = 0;
while clicked == 0 
    [x,y,buttons] = GetMouse;
    if any(buttons)
        clicked = 1;
    end
end

ListenChar(0); % turns off keystroke recording and clears buffer
Screen('CloseAll'); % close screens


save(fileName,'dataMat'); % save data to filename
save(shortName,'dataMat'); % save data to shortname


%% Function for detecting which house number the mouse is on

function [houseNum, stimNum, buttons] = getHouseNumber(stimNums, ScreenRect, window)
    [xMouse,yMouse,buttons] = GetMouse(window);

    screenWidth = ScreenRect(3);
    screenHeight = ScreenRect(4);

    if xMouse < screenWidth / 3
        if yMouse < screenHeight/2
            houseNum = 1;
        else
            houseNum = 4;
        end
    elseif xMouse < screenWidth*2/3
        if yMouse < screenHeight/2
            houseNum = 2;
        else
            houseNum = 5;
        end
    else
        if yMouse < screenHeight/2
            houseNum = 3;
        else
            houseNum = 6;
        end
    end

    stimNum = stimNums(houseNum);

end

%% Function for showing house previews on the screen

function stimInDisplay = showHouseOverviews(houseStim, stimNums, ScreenRect, window)
    buffer = 40;

    minX = ScreenRect(1);
    maxX = ScreenRect(3);
    minY = ScreenRect(2);
    maxY = ScreenRect(4);

    xThird = floor((maxX-minX)/3);
    yHalf = floor((maxY-minY)/2);

    for j = 1:6
        thisBox = [(mod(j-1,3))*xThird, floor(j/3.01)*yHalf, (mod(j-1,3)+1)*xThird, ceil(j/3.01)*yHalf];
        thisBoxWidth = thisBox(3)-thisBox(1);
        thisBoxHeight = thisBox(4)-thisBox(2);

        Screen('FrameRect',window,[255 255 255], thisBox+[10 10 -10 -10], 5);

        if stimNums(j) ~= 0
            extImg = imread([pwd,'\Images\',houseStim.extPic{stimNums(j)}],'png');
            livImg = imread([pwd,'\Images\',houseStim.livPic{stimNums(j)}],'png');  

            extBox = [thisBox(1)+buffer,thisBox(2)+buffer,thisBox(1)+.5*thisBoxWidth-buffer, thisBox(2)+.4*thisBoxHeight];
            livBox = extBox + [thisBoxWidth/2, 0, thisBoxWidth/2, 0];

            extTexture = Screen('MakeTexture',window,extImg);
            Screen('DrawTexture',window,extTexture,[],extBox);
            livTexture = Screen('MakeTexture',window,livImg);
            Screen('DrawTexture',window,livTexture,[],livBox);

            nBeds = houseStim.nBeds(stimNums(j));
            nBaths = houseStim.nBaths(stimNums(j));
            sqft = houseStim.sqft(stimNums(j));
            listPrice = houseStim.listPrice(stimNums(j));

            DrawFormattedText(window,[num2str(nBeds),' bedrooms / ',num2str(nBaths),' bathrooms'],'center','center',[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
            DrawFormattedText(window,[num2str(sqft),' square feet'],'center',thisBox(2)+thisBoxHeight*.7,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
            DrawFormattedText(window,['List price: $',num2str(listPrice)],'center',thisBox(2)+thisBoxHeight*.85,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
        end
    end
    Screen('Flip',window,0,0);

    stimInDisplay = stimNums(stimNums ~= 0);

end


%% Function for showing complete house information

function stimInDisplay = showHouseDetails(houseStim, stimNum, ScreenRect, window, screenSide)
    buffer = 28;


    Screen('TextSize', window, 24);   

    minX = ScreenRect(1);
    maxX = ScreenRect(3);
    minY = ScreenRect(2);
    maxY = ScreenRect(4);

    centerX = floor((maxX-minX)/2);
    centerY = floor((maxY-minY)/2);

    thisBox = [(screenSide-1)*centerX, 0, screenSide*centerX, maxY];
    thisBoxWidth = thisBox(3)-thisBox(1);
    thisBoxHeight = thisBox(4)-thisBox(2);

    Screen('FrameRect',window,[255 255 255], thisBox+[10 10 -10 -10], 5);

    if stimNum ~= 0
        extImg = imread([pwd,'\Images\',houseStim.extPic{stimNum}],'png');
        livImg = imread([pwd,'\Images\',houseStim.livPic{stimNum}],'png');  
        bedImg = imread([pwd,'\Images\',houseStim.bedPic{stimNum}],'png');
        bathImg = imread([pwd,'\Images\',houseStim.bathPic{stimNum}],'png');  
        outImg = imread([pwd,'\Images\',houseStim.outPic{stimNum}],'png');
        kitImg = imread([pwd,'\Images\',houseStim.kitPic{stimNum}],'png');  

        extBox = [thisBox(1)+buffer,thisBox(2)+buffer,thisBox(1)+thisBoxWidth/3-buffer, thisBox(2)+thisBoxHeight*.25-buffer];
        livBox = extBox + [thisBoxWidth/3, 0, thisBoxWidth/3, 0];
        bedBox = extBox + [thisBoxWidth*2/3, 0, thisBoxWidth*2/3, 0];
        bathBox = extBox + [0, .25*thisBoxHeight, 0, .25*thisBoxHeight];
        outBox = extBox + [thisBoxWidth/3, .25*thisBoxHeight, thisBoxWidth/3, .25*thisBoxHeight];
        kitBox = extBox + [thisBoxWidth*2/3, .25*thisBoxHeight, thisBoxWidth*2/3, .25*thisBoxHeight];

        extTexture = Screen('MakeTexture',window,extImg);
        Screen('DrawTexture',window,extTexture,[],extBox);
        livTexture = Screen('MakeTexture',window,livImg);
        Screen('DrawTexture',window,livTexture,[],livBox);
        bedTexture = Screen('MakeTexture',window,bedImg);
        Screen('DrawTexture',window,bedTexture,[],bedBox);
        bathTexture = Screen('MakeTexture',window,bathImg);
        Screen('DrawTexture',window,bathTexture,[],bathBox);
        outTexture = Screen('MakeTexture',window,outImg);
        Screen('DrawTexture',window,outTexture,[],outBox);
        kitTexture = Screen('MakeTexture',window,kitImg);
        Screen('DrawTexture',window,kitTexture,[],kitBox);

        nBeds = houseStim.nBeds(stimNum);
        nBaths = houseStim.nBaths(stimNum);
        sqft = houseStim.sqft(stimNum);
        acres = houseStim.lotSize(stimNum);
        builtYear = houseStim.yearBuilt(stimNum);
        listPrice = houseStim.listPrice(stimNum);

        DrawFormattedText(window,['List price $',num2str(listPrice)],'center',thisBoxHeight*.55,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
        DrawFormattedText(window,[num2str(nBeds),' bedrooms / ',num2str(nBaths),' bathrooms'],'center',thisBoxHeight*.625,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
        DrawFormattedText(window,['Interior size: ',num2str(sqft),' square feet'],'center',thisBoxHeight*.7,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
        DrawFormattedText(window,['Lot size: ',num2str(acres),' acres'],'center',thisBoxHeight*.775,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
        DrawFormattedText(window,['Build year: ',num2str(builtYear)],'center',thisBoxHeight*.85,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
        
        
    end
    Screen('Flip',window,0,0);

    stimInDisplay = stimNum(stimNum ~= 0);

Screen('Close',extTexture);
Screen('Close',livTexture);
Screen('Close',bedTexture);
Screen('Close',bathTexture);
Screen('Close',outTexture);
Screen('Close',kitTexture);

    Screen('TextSize', window, 24);     % text size set to 22
end

%% Function for showing bidding scale

function [pricePaid, pricingRT] = showPricingScale(houseStim, stimNum, ScreenRect, window, screenSide, maxPrice)

Screen('Flip',window,0,0);
WaitSecs(.5);

t0 = GetSecs;

center = [ScreenRect(3)*.75, ScreenRect(4)*.5];

scaleMax = maxPrice;
scaleMin = 0;

scaleColor = [255 255 255]; %sets color to white
textColor = [255 255 255];

majorTicks = linspace(scaleMin,scaleMax,11); %generates 11 points between the scale min and max
minorTicks = linspace(scaleMin,scaleMax,51); %generates 51 points between the scale min and max

numTicks = length(majorTicks); %creates numTicks var with length = number of major ticks
numMinorTicks = length(minorTicks);

innerRadiusFraction = 0.4; % how far from the center the ticks should start
innerRadius = innerRadiusFraction*center(2); % set the radius of the confidence scale to be 75% of the way from the center to the edge of the screen
outerRadiusFraction = 0.45; % can be adjusted to whatever we want, 80% of the way to the edge of the screen is reasonable
outerRadius = outerRadiusFraction*center(2); % set the radius for the end point of the ticks on the scale
minorRadiusFraction = .415;
minorRadius = minorRadiusFraction*center(2);
textRadius = 0.54;  % how far from the center the text will be


buffer = 28;

%%%%%%%%%%%%%% draw scale

tickAngles = linspace(pi, 2*pi, numTicks);
minorTickAngles = linspace(pi, 2*pi, numMinorTicks);

radialLines = zeros(2, numTicks*2); % DrawLines takes a 2x(n*2) vector of x-y coordinates, with each pair of pairs indicating the start and end point of the tick
minRadialLines = zeros(2, numMinorTicks*2);

for n = 1:numTicks
    radialLines(1,(n*2-1)) = round(innerRadius * cos(tickAngles(n)) + center(1)); % inner x coordinate of tick
    radialLines(2,(n*2-1)) = round(innerRadius * sin(tickAngles(n)) + center(2)); % inner y coordinate
    radialLines(1,(n*2)) = round(outerRadius * cos(tickAngles(n)) + center(1)); % outer x coordinate
    radialLines(2,(n*2)) = round(outerRadius * sin(tickAngles(n)) + center(2)); % outer y coordinate


    textTick = ['$',num2str(majorTicks(n)/1000,'%.0f'),'k'];

    textLocX = round(textRadius * center(2) * cos(tickAngles(n)) + center(1)) - 40;
    textLocY = round(textRadius * center(2) * sin(tickAngles(n)) + center(2)) + 10;

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



%%%%%%%%%%%%%%%%%%%%%% Show stimuli


Screen('TextSize', window, 24);   

minX = ScreenRect(1);
maxX = ScreenRect(3);
minY = ScreenRect(2);
maxY = ScreenRect(4);

centerX = floor((maxX-minX)/2);
centerY = floor((maxY-minY)/2);

thisBox = [(screenSide-1)*centerX, 0, screenSide*centerX, maxY];
thisBoxWidth = thisBox(3)-thisBox(1);
thisBoxHeight = thisBox(4)-thisBox(2);
thisBox2 = [centerX, 0, centerX*2, maxY];

Screen('FrameRect',window,[255 255 255], thisBox+[10 10 -10 -10], 5);

extImg = imread([pwd,'\Images\',houseStim.extPic{stimNum}],'png');
livImg = imread([pwd,'\Images\',houseStim.livPic{stimNum}],'png');  
bedImg = imread([pwd,'\Images\',houseStim.bedPic{stimNum}],'png');
bathImg = imread([pwd,'\Images\',houseStim.bathPic{stimNum}],'png');  
outImg = imread([pwd,'\Images\',houseStim.outPic{stimNum}],'png');
kitImg = imread([pwd,'\Images\',houseStim.kitPic{stimNum}],'png');  

extBox = [thisBox(1)+buffer,thisBox(2)+buffer,thisBox(1)+thisBoxWidth/3-buffer, thisBox(2)+thisBoxHeight*.25-buffer];
livBox = extBox + [thisBoxWidth/3, 0, thisBoxWidth/3, 0];
bedBox = extBox + [thisBoxWidth*2/3, 0, thisBoxWidth*2/3, 0];
bathBox = extBox + [0, .25*thisBoxHeight, 0, .25*thisBoxHeight];
outBox = extBox + [thisBoxWidth/3, .25*thisBoxHeight, thisBoxWidth/3, .25*thisBoxHeight];
kitBox = extBox + [thisBoxWidth*2/3, .25*thisBoxHeight, thisBoxWidth*2/3, .25*thisBoxHeight];

extTexture = Screen('MakeTexture',window,extImg);
Screen('DrawTexture',window,extTexture,[],extBox);
livTexture = Screen('MakeTexture',window,livImg);
Screen('DrawTexture',window,livTexture,[],livBox);
bedTexture = Screen('MakeTexture',window,bedImg);
Screen('DrawTexture',window,bedTexture,[],bedBox);
bathTexture = Screen('MakeTexture',window,bathImg);
Screen('DrawTexture',window,bathTexture,[],bathBox);
outTexture = Screen('MakeTexture',window,outImg);
Screen('DrawTexture',window,outTexture,[],outBox);
kitTexture = Screen('MakeTexture',window,kitImg);
Screen('DrawTexture',window,kitTexture,[],kitBox);

nBeds = houseStim.nBeds(stimNum);
nBaths = houseStim.nBaths(stimNum);
sqft = houseStim.sqft(stimNum);
acres = houseStim.lotSize(stimNum);
builtYear = houseStim.yearBuilt(stimNum);
listPrice = houseStim.listPrice(stimNum);

DrawFormattedText(window,['List price $',num2str(listPrice)],'center',thisBoxHeight*.55,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
DrawFormattedText(window,[num2str(nBeds),' bedrooms'],'center',thisBoxHeight*.625,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
DrawFormattedText(window,[num2str(nBaths),' bathrooms'],'center',thisBoxHeight*.7,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
DrawFormattedText(window,['Interior size: ',num2str(sqft),' square feet'],'center',thisBoxHeight*.775,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
DrawFormattedText(window,['Lot size: ',num2str(acres),' acres'],'center',thisBoxHeight*.825,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
DrawFormattedText(window,['Build year: ',num2str(builtYear)],'center',thisBoxHeight*.9,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);


    
    
Screen('Flip',window,0,0);

stimInDisplay = stimNum(stimNum ~= 0);

priceEntered = 0;

while priceEntered == 0
    DrawFormattedText(window,['List price $',num2str(listPrice)],'center',thisBoxHeight*.55,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
    DrawFormattedText(window,[num2str(nBeds),' bedrooms / ',num2str(nBaths),' bathrooms'],'center',thisBoxHeight*.625,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
    DrawFormattedText(window,['Interior size: ',num2str(sqft),' square feet'],'center',thisBoxHeight*.7,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
    DrawFormattedText(window,['Lot size: ',num2str(acres),' acres'],'center',thisBoxHeight*.775,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
    DrawFormattedText(window,['Build year: ',num2str(builtYear)],'center',thisBoxHeight*.85,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
    Screen('DrawTexture',window,extTexture,[],extBox);
    Screen('DrawTexture',window,livTexture,[],livBox);
    Screen('DrawTexture',window,bedTexture,[],bedBox);
    Screen('DrawTexture',window,bathTexture,[],bathBox);
    Screen('DrawTexture',window,outTexture,[],outBox);
    Screen('DrawTexture',window,kitTexture,[],kitBox);
    Screen('FrameRect',window,[255 255 255], thisBox+[10 10 -10 -10], 5);

    for n = 1:numTicks
        radialLines(1,(n*2-1)) = round(innerRadius * cos(tickAngles(n)) + center(1)); % inner x coordinate of tick
        radialLines(2,(n*2-1)) = round(innerRadius * sin(tickAngles(n)) + center(2)); % inner y coordinate
        radialLines(1,(n*2)) = round(outerRadius * cos(tickAngles(n)) + center(1)); % outer x coordinate
        radialLines(2,(n*2)) = round(outerRadius * sin(tickAngles(n)) + center(2)); % outer y coordinate
    
        textTick = ['$',num2str(majorTicks(n)/1000,'%.0f'),'k'];
    
        textLocX = round(textRadius * center(2) * cos(tickAngles(n)) + center(1)) - 40;
        textLocY = round(textRadius * center(2) * sin(tickAngles(n)) + center(2)) + 10;
    
        Screen('DrawText', window, textTick, textLocX, textLocY, textColor, [0 0 0], center(2));    
    end
    
    for n = 1:numMinorTicks
        minRadialLines(1,(n*2-1)) = round(innerRadius * cos(minorTickAngles(n)) + center(1)); % inner x coordinate of tick
        minRadialLines(2,(n*2-1)) = round(innerRadius * sin(minorTickAngles(n)) + center(2)); % inner y coordinate
        minRadialLines(1,(n*2)) = round(minorRadius * cos(minorTickAngles(n)) + center(1)); % outer x coordinate
        minRadialLines(2,(n*2)) = round(minorRadius * sin(minorTickAngles(n)) + center(2)); % outer y coordinate
    end
    Screen('FrameRect',window,[255 255 255], thisBox+[10 10 -10 -10], 5);
    Screen('DrawLines', window, radialLines, 3, scaleColor);
    Screen('DrawLines', window, minRadialLines, 2, scaleColor);
    Screen('FrameArc', window, scaleColor, [center(1)-innerRadius, center(2)-innerRadius, center(1)+innerRadius, center(2)+innerRadius], 270, 180, 5, 5);

    [xM,yM,buttons] = GetMouse;
    xDev = xM-center(1);
    yDev = center(2)-yM;
    if abs(xDev) < ScreenRect(3)/2
        if yDev > 0
            respAngle = atan2(yDev,xDev);
            respPrice = maxPrice - (respAngle/pi)*maxPrice;
            DrawFormattedText(window,['Bid: $',num2str(respPrice,'%.0f')],'center',center(2)+100,[50 155 255],80,0,0,1.4,0,thisBox2);

            xdot = round(innerRadius * cos(respAngle) + center(1));
            ydot = round(center(2) - innerRadius * sin(respAngle));

            Screen('DrawDots',window,[xdot; ydot],20,[50 155 255],[],1)

            if any(buttons)
                priceEntered = 1;
                pricePaid = respPrice;
                pricingRT = GetSecs - t0;
            end
        end
    end
    imageData = screencapture(0); 
    save('screenshot.mat','imageData');
    Screen('Flip',window,0,0);
end

Screen('TextSize', window, 24);     % text size set to 22

Screen('Close',extTexture);
Screen('Close',livTexture);
Screen('Close',bedTexture);
Screen('Close',bathTexture);
Screen('Close',outTexture);
Screen('Close',kitTexture);

end

%% function for showing demo of house overviews 

function stimInDisplay = showHouseOverviewsDemo(houseStim, stimNums, ScreenRect, window)
    buffer = 40;

    minX = ScreenRect(1);
    maxX = ScreenRect(3);
    minY = ScreenRect(2);
    maxY = ScreenRect(4);

    xThird = floor((maxX-minX)/3);
    yHalf = floor((maxY-minY)/2);

    for j = 4:6
        thisBox = [(mod(j-1,3))*xThird, floor(j/3.01)*yHalf, (mod(j-1,3)+1)*xThird, ceil(j/3.01)*yHalf];
        thisBoxWidth = thisBox(3)-thisBox(1);
        thisBoxHeight = thisBox(4)-thisBox(2);

        Screen('FrameRect',window,[255 255 255], thisBox+[10 10 -10 -10], 5);

        if stimNums(j) ~= 0
            extImg = imread([pwd,'\Images\',houseStim.extPic{stimNums(j)}],'png');
            livImg = imread([pwd,'\Images\',houseStim.livPic{stimNums(j)}],'png');  

            extBox = [thisBox(1)+buffer,thisBox(2)+buffer,thisBox(1)+.5*thisBoxWidth-buffer, thisBox(2)+.4*thisBoxHeight];
            livBox = extBox + [thisBoxWidth/2, 0, thisBoxWidth/2, 0];

            extTexture = Screen('MakeTexture',window,extImg);
            Screen('DrawTexture',window,extTexture,[],extBox)
            livTexture = Screen('MakeTexture',window,livImg);
            Screen('DrawTexture',window,livTexture,[],livBox)

            nBeds = houseStim.nBeds(stimNums(j));
            nBaths = houseStim.nBaths(stimNums(j));
            sqft = houseStim.sqft(stimNums(j));
            listPrice = houseStim.listPrice(stimNums(j));

            DrawFormattedText(window,[num2str(nBeds),' bedrooms / ',num2str(nBaths),' bathrooms'],'center','center',[255 255 255], 80, 0, 0, 1.4, 0, thisBox)
            DrawFormattedText(window,[num2str(sqft),' square feet'],'center',thisBox(2)+thisBoxHeight*.7,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
            DrawFormattedText(window,['List price: $',num2str(listPrice)],'center',thisBox(2)+thisBoxHeight*.85,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
        end
    end
    Screen('Flip',window,0,0);

    stimInDisplay = stimNums(stimNums ~= 0);

end
%% Function for showing bidding scale in the demo instructions

function [pricePaid, pricingRT] = showPricingScaleDemo(houseStim, stimNum, ScreenRect, window, screenSide, maxPrice)

Screen('Flip',window,0,0);
WaitSecs(.5);

t0 = GetSecs;

center = [ScreenRect(3)*.75, ScreenRect(4)*.5];

scaleMax = maxPrice;
scaleMin = 0;

scaleColor = [255 255 255]; %sets color to white
textColor = [255 255 255];

majorTicks = linspace(scaleMin,scaleMax,11); %generates 11 points between the scale min and max
minorTicks = linspace(scaleMin,scaleMax,51); %generates 51 points between the scale min and max

numTicks = length(majorTicks); %creates numTicks var with length = number of major ticks
numMinorTicks = length(minorTicks);

innerRadiusFraction = 0.4; % how far from the center the ticks should start
innerRadius = innerRadiusFraction*center(2); % set the radius of the confidence scale to be 75% of the way from the center to the edge of the screen
outerRadiusFraction = 0.45; % can be adjusted to whatever we want, 80% of the way to the edge of the screen is reasonable
outerRadius = outerRadiusFraction*center(2); % set the radius for the end point of the ticks on the scale
minorRadiusFraction = .415;
minorRadius = minorRadiusFraction*center(2);
textRadius = 0.54;  % how far from the center the text will be


buffer = 28;

%%%%%%%%%%%%%% draw scale

tickAngles = linspace(pi, 2*pi, numTicks);
minorTickAngles = linspace(pi, 2*pi, numMinorTicks);

radialLines = zeros(2, numTicks*2); % DrawLines takes a 2x(n*2) vector of x-y coordinates, with each pair of pairs indicating the start and end point of the tick
minRadialLines = zeros(2, numMinorTicks*2);

for n = 1:numTicks
    radialLines(1,(n*2-1)) = round(innerRadius * cos(tickAngles(n)) + center(1)); % inner x coordinate of tick
    radialLines(2,(n*2-1)) = round(innerRadius * sin(tickAngles(n)) + center(2)); % inner y coordinate
    radialLines(1,(n*2)) = round(outerRadius * cos(tickAngles(n)) + center(1)); % outer x coordinate
    radialLines(2,(n*2)) = round(outerRadius * sin(tickAngles(n)) + center(2)); % outer y coordinate


    textTick = ['$',num2str(majorTicks(n)/1000,'%.0f'),'k'];

    textLocX = round(textRadius * center(2) * cos(tickAngles(n)) + center(1)) - 40;
    textLocY = round(textRadius * center(2) * sin(tickAngles(n)) + center(2)) + 10;

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



%%%%%%%%%%%%%%%%%%%%%% Show stimuli


Screen('TextSize', window, 24);   

minX = ScreenRect(1);
maxX = ScreenRect(3);
minY = ScreenRect(2);
maxY = ScreenRect(4);

centerX = floor((maxX-minX)/2);
centerY = floor((maxY-minY)/2);

thisBox = [(screenSide-1)*centerX, 0, screenSide*centerX, maxY];
thisBoxWidth = thisBox(3)-thisBox(1);
thisBoxHeight = thisBox(4)-thisBox(2);
thisBox2 = [centerX, 0, centerX*2, maxY];

Screen('FrameRect',window,[255 255 255], thisBox+[10 10 -10 -10], 5);

extImg = imread([pwd,'\Images\',houseStim.extPic{stimNum}],'png');
livImg = imread([pwd,'\Images\',houseStim.livPic{stimNum}],'png');  
bedImg = imread([pwd,'\Images\',houseStim.bedPic{stimNum}],'png');
bathImg = imread([pwd,'\Images\',houseStim.bathPic{stimNum}],'png');  
outImg = imread([pwd,'\Images\',houseStim.outPic{stimNum}],'png');
kitImg = imread([pwd,'\Images\',houseStim.kitPic{stimNum}],'png');  

extBox = [thisBox(1)+buffer,thisBox(2)+buffer,thisBox(1)+thisBoxWidth/3-buffer, thisBox(2)+thisBoxHeight*.25-buffer];
livBox = extBox + [thisBoxWidth/3, 0, thisBoxWidth/3, 0];
bedBox = extBox + [thisBoxWidth*2/3, 0, thisBoxWidth*2/3, 0];
bathBox = extBox + [0, .25*thisBoxHeight, 0, .25*thisBoxHeight];
outBox = extBox + [thisBoxWidth/3, .25*thisBoxHeight, thisBoxWidth/3, .25*thisBoxHeight];
kitBox = extBox + [thisBoxWidth*2/3, .25*thisBoxHeight, thisBoxWidth*2/3, .25*thisBoxHeight];

extTexture = Screen('MakeTexture',window,extImg);
Screen('DrawTexture',window,extTexture,[],extBox)
livTexture = Screen('MakeTexture',window,livImg);
Screen('DrawTexture',window,livTexture,[],livBox)
bedTexture = Screen('MakeTexture',window,bedImg);
Screen('DrawTexture',window,bedTexture,[],bedBox)
bathTexture = Screen('MakeTexture',window,bathImg);
Screen('DrawTexture',window,bathTexture,[],bathBox)
outTexture = Screen('MakeTexture',window,outImg);
Screen('DrawTexture',window,outTexture,[],outBox)
kitTexture = Screen('MakeTexture',window,kitImg);
Screen('DrawTexture',window,kitTexture,[],kitBox)

nBeds = houseStim.nBeds(stimNum);
nBaths = houseStim.nBaths(stimNum);
sqft = houseStim.sqft(stimNum);
acres = houseStim.lotSize(stimNum);
builtYear = houseStim.yearBuilt(stimNum);
listPrice = houseStim.listPrice(stimNum);

DrawFormattedText(window,['List price $',num2str(listPrice)],'center',thisBoxHeight*.55,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
DrawFormattedText(window,[num2str(nBeds),' bedrooms / ',num2str(nBaths),' bathrooms'],'center',thisBoxHeight*.625,[255 255 255], 80, 0, 0, 1.4, 0, thisBox)
DrawFormattedText(window,['Interior size: ',num2str(sqft),' square feet'],'center',thisBoxHeight*.7,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
DrawFormattedText(window,['Lot size: ',num2str(acres),' acres'],'center',thisBoxHeight*.775,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
DrawFormattedText(window,['Build year: ',num2str(builtYear)],'center',thisBoxHeight*.85,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);


    
    
Screen('Flip',window,0,0);

stimInDisplay = stimNum(stimNum ~= 0);

priceEntered = 0;

while priceEntered == 0
    DrawFormattedText(window,['List price $',num2str(listPrice)],'center',thisBoxHeight*.55,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
    DrawFormattedText(window,[num2str(nBeds),' bedrooms / ',num2str(nBaths),' bathrooms'],'center',thisBoxHeight*.625,[255 255 255], 80, 0, 0, 1.4, 0, thisBox)
    DrawFormattedText(window,['Interior size: ',num2str(sqft),' square feet'],'center',thisBoxHeight*.7,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
    DrawFormattedText(window,['Lot size: ',num2str(acres),' acres'],'center',thisBoxHeight*.775,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
    DrawFormattedText(window,['Build year: ',num2str(builtYear)],'center',thisBoxHeight*.85,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
    Screen('DrawTexture',window,extTexture,[],extBox)
    Screen('DrawTexture',window,livTexture,[],livBox)
    Screen('DrawTexture',window,bedTexture,[],bedBox)
    Screen('DrawTexture',window,bathTexture,[],bathBox)
    Screen('DrawTexture',window,outTexture,[],outBox)
    Screen('DrawTexture',window,kitTexture,[],kitBox)
    Screen('FrameRect',window,[255 255 255], thisBox+[10 10 -10 -10], 5);

    for n = 1:numTicks
        radialLines(1,(n*2-1)) = round(innerRadius * cos(tickAngles(n)) + center(1)); % inner x coordinate of tick
        radialLines(2,(n*2-1)) = round(innerRadius * sin(tickAngles(n)) + center(2)); % inner y coordinate
        radialLines(1,(n*2)) = round(outerRadius * cos(tickAngles(n)) + center(1)); % outer x coordinate
        radialLines(2,(n*2)) = round(outerRadius * sin(tickAngles(n)) + center(2)); % outer y coordinate
    
        textTick = ['$',num2str(majorTicks(n)/1000,'%.0f'),'k'];
    
        textLocX = round(textRadius * center(2) * cos(tickAngles(n)) + center(1)) - 40;
        textLocY = round(textRadius * center(2) * sin(tickAngles(n)) + center(2)) + 10;
    
        Screen('DrawText', window, textTick, textLocX, textLocY, textColor, [0 0 0], center(2));    
    end
    
    for n = 1:numMinorTicks
        minRadialLines(1,(n*2-1)) = round(innerRadius * cos(minorTickAngles(n)) + center(1)); % inner x coordinate of tick
        minRadialLines(2,(n*2-1)) = round(innerRadius * sin(minorTickAngles(n)) + center(2)); % inner y coordinate
        minRadialLines(1,(n*2)) = round(minorRadius * cos(minorTickAngles(n)) + center(1)); % outer x coordinate
        minRadialLines(2,(n*2)) = round(minorRadius * sin(minorTickAngles(n)) + center(2)); % outer y coordinate
    end
    Screen('FrameRect',window,[255 255 255], thisBox+[10 10 -10 -10], 5);
    Screen('DrawLines', window, radialLines, 3, scaleColor);
    Screen('DrawLines', window, minRadialLines, 2, scaleColor);
    Screen('FrameArc', window, scaleColor, [center(1)-innerRadius, center(2)-innerRadius, center(1)+innerRadius, center(2)+innerRadius], 270, 180, 5, 5);
    DrawFormattedText(window,'To bid for a house, you should mouse over the scale shown above to move the blue dot around. When the dot is at the location of the bid you want to enter, click the left mouse button to enter the corresponding bid.','center', centerY+200,[255 255 255],60, 0, 0, 1.4,0,thisBox2);
    DrawFormattedText(window,'Click on the scale now to enter a bid for this house.','center', centerY+400,[255 255 255],60, 0, 0, 1.4,0,thisBox2);


    [xM,yM,buttons] = GetMouse;
    xDev = xM-center(1);
    yDev = center(2)-yM;
    if abs(xDev) < ScreenRect(3)/2
        if yDev > 0
            respAngle = atan2(yDev,xDev);
            respPrice = maxPrice - (respAngle/pi)*maxPrice;
            DrawFormattedText(window,['Bid: $',num2str(respPrice,'%.0f')],'center',center(2)+100,[50 155 255],80,0,0,1.4,0,thisBox2);

            xdot = round(innerRadius * cos(respAngle) + center(1));
            ydot = round(center(2) - innerRadius * sin(respAngle));

            Screen('DrawDots',window,[xdot; ydot],20,[50 155 255],[],1)

            if any(buttons)
                priceEntered = 1;
                pricePaid = respPrice;
                pricingRT = GetSecs - t0;
            end
        end
    end
    Screen('Flip',window,0,0);
end


Screen('Close',extTexture);
Screen('Close',livTexture);
Screen('Close',bedTexture);
Screen('Close',bathTexture);
Screen('Close',outTexture);
Screen('Close',kitTexture);

end


%% Demonstration of house details screen

function stimInDisplay = showHouseDetailsDemo(houseStim, stimNum, ScreenRect, window, screenSide)
    buffer = 28;


    Screen('TextSize', window, 24);   

    minX = ScreenRect(1);
    maxX = ScreenRect(3);
    minY = ScreenRect(2);
    maxY = ScreenRect(4);

    centerX = floor((maxX-minX)/2);
    centerY = floor((maxY-minY)/2);

    thisBox = [(screenSide-1)*centerX, 0, screenSide*centerX, maxY];
    thisBoxWidth = thisBox(3)-thisBox(1);
    thisBoxHeight = thisBox(4)-thisBox(2);

    Screen('FrameRect',window,[255 255 255], thisBox+[10 10 -10 -10], 5);

    if stimNum ~= 0
        extImg = imread([pwd,'\Images\',houseStim.extPic{stimNum}],'png');
        livImg = imread([pwd,'\Images\',houseStim.livPic{stimNum}],'png');  
        bedImg = imread([pwd,'\Images\',houseStim.bedPic{stimNum}],'png');
        bathImg = imread([pwd,'\Images\',houseStim.bathPic{stimNum}],'png');  
        outImg = imread([pwd,'\Images\',houseStim.outPic{stimNum}],'png');
        kitImg = imread([pwd,'\Images\',houseStim.kitPic{stimNum}],'png');  

        extBox = [thisBox(1)+buffer,thisBox(2)+buffer,thisBox(1)+thisBoxWidth/3-buffer, thisBox(2)+thisBoxHeight*.25-buffer];
        livBox = extBox + [thisBoxWidth/3, 0, thisBoxWidth/3, 0];
        bedBox = extBox + [thisBoxWidth*2/3, 0, thisBoxWidth*2/3, 0];
        bathBox = extBox + [0, .25*thisBoxHeight, 0, .25*thisBoxHeight];
        outBox = extBox + [thisBoxWidth/3, .25*thisBoxHeight, thisBoxWidth/3, .25*thisBoxHeight];
        kitBox = extBox + [thisBoxWidth*2/3, .25*thisBoxHeight, thisBoxWidth*2/3, .25*thisBoxHeight];

        extTexture = Screen('MakeTexture',window,extImg);
        Screen('DrawTexture',window,extTexture,[],extBox);
        livTexture = Screen('MakeTexture',window,livImg);
        Screen('DrawTexture',window,livTexture,[],livBox);
        bedTexture = Screen('MakeTexture',window,bedImg);
        Screen('DrawTexture',window,bedTexture,[],bedBox);
        bathTexture = Screen('MakeTexture',window,bathImg);
        Screen('DrawTexture',window,bathTexture,[],bathBox);
        outTexture = Screen('MakeTexture',window,outImg);
        Screen('DrawTexture',window,outTexture,[],outBox);
        kitTexture = Screen('MakeTexture',window,kitImg);
        Screen('DrawTexture',window,kitTexture,[],kitBox);

        nBeds = houseStim.nBeds(stimNum);
        nBaths = houseStim.nBaths(stimNum);
        sqft = houseStim.sqft(stimNum);
        acres = houseStim.lotSize(stimNum);
        builtYear = houseStim.yearBuilt(stimNum);
        listPrice = houseStim.listPrice(stimNum);

        DrawFormattedText(window,['List price $',num2str(listPrice)],'center',thisBoxHeight*.55,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
        DrawFormattedText(window,[num2str(nBeds),' bedrooms'],'center',thisBoxHeight*.625,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
        DrawFormattedText(window,[num2str(nBaths),' bathrooms'],'center',thisBoxHeight*.7,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
        DrawFormattedText(window,['Interior size: ',num2str(sqft),' square feet'],'center',thisBoxHeight*.775,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
        DrawFormattedText(window,['Lot size: ',num2str(acres),' acres'],'center',thisBoxHeight*.825,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
        DrawFormattedText(window,['Build year: ',num2str(builtYear)],'center',thisBoxHeight*.9,[255 255 255], 80, 0, 0, 1.4, 0, thisBox);
        
        
    end
    Screen('Flip',window,0,0);

    stimInDisplay = stimNum(stimNum ~= 0);

Screen('Close',extTexture);
Screen('Close',livTexture);
Screen('Close',bedTexture);
Screen('Close',bathTexture);
Screen('Close',outTexture);
Screen('Close',kitTexture);

end
