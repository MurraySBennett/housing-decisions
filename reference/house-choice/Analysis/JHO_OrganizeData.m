clear;

sList = 1:34;

screenBox = [1920 1080 1920 1080];
% Define hitboxes for summary screen
hitBoxExt = [29, 29, 293, 226;
    669,  29,  933,  226;
    1309, 29,  1573, 226;
    29,   568, 293,  765;
    669,  568, 933,  765;
    1309, 568, 1573, 765 ...
]./screenBox;

hitBoxInt = [353, 29, 611, 226;
    989,  29, 1253,  226;
    1635, 29, 1899,  226;
    353,  568, 611,  765;
    989,  568, 1253, 765;
    1635, 568, 1899, 765 ...
]./screenBox;

hitBoxBedrooms = [31, 252, 313, 318;
    659,  252, 941,  318;
    1307, 252, 1589, 318;
    31,   800, 313,  866;
    659,  800, 941,  866;
    1307, 800, 1589, 866 ...
]./screenBox;

hitBoxBathrooms = [313, 252, 595, 318;
    941, 252  1223. 318;
    1589,252, 1871, 318;
    313, 800, 595,  866;
    941, 800, 1223, 866;
    1589,800, 1871, 866 ...
]./screenBox;

hitBoxSqft = [115, 328, 531, 390;
    757,  328, 1173, 390;
    1399, 328, 1815, 390;
    115,  872, 531,  934;
    757,  872, 1173, 934;
    1399, 872, 1815, 390 ...
]./screenBox;

hitBoxPrice = [81, 408, 571, 470;
    720,  408, 1210, 470;
    1359, 408, 1849, 470;
    81,   950, 571,  1012;
    720,  950, 1210, 1012;
    1359, 950, 1849, 1012 ...
]./screenBox;

hitBoxes = [hitBoxExt; hitBoxInt; hitBoxBedrooms; hitBoxBathrooms; hitBoxSqft; hitBoxPrice];

% Define hitboxes for detailed screen
hitBoxDetails = [ ...
    20, 20, 300, 250; % exterior
    340, 20, 620, 250; % living room
    660, 20, 940, 250; % bedroom
    20, 290, 300, 520; % bathroom
    240, 290, 620, 520; % outdoor space
      660, 290, 940, 520; % kitchen
      350, 560, 600, 600; % list price
      315, 645, 473, 690; % # bedrooms
      475, 645, 640, 690; % # bathrooms
      300, 730, 660, 775; % interior sqft
      360, 810, 610, 855; % lot size
      375, 890, 590, 935 ...% build year
]./screenBox; 

%% Calculate looking times / proportions
bedProp     = zeros(length(sList),12);
extProp     = zeros(length(sList),12);
intProp     = zeros(length(sList),12);
bathProp    = zeros(length(sList),12);
sqftProp    = zeros(length(sList),12);
priceProp   = zeros(length(sList),12);

bedDetail   = zeros(length(sList),12);
extDetail   = zeros(length(sList),12);
livDetail   = zeros(length(sList),12);
bathDetail  = zeros(length(sList),12);
kitDetail   = zeros(length(sList),12);
outDetail   = zeros(length(sList),12);
nBedDetail  = zeros(length(sList),12);
nBathDetail = zeros(length(sList),12);
lotDetail   = zeros(length(sList),12);
yearDetail  = zeros(length(sList),12);
sqftDetail  = zeros(length(sList),12);
priceDetail = zeros(length(sList),12);

optionChosen    = zeros(length(sList),12);
chosenAttsBed   =  zeros(length(sList),12);
chosenAttsBath  =  zeros(length(sList),12);
chosenAttsSqft  =  zeros(length(sList),12);
chosenAttsLot   =  zeros(length(sList),12);
chosenAttsYear  =  zeros(length(sList),12);
chosenAttsPrice =  zeros(length(sList),12);
bidMade         = zeros(length(sList),12);
overallRT       = zeros(length(sList),12);

subject = zeros(length(sList),12);
block   = zeros(length(sList),12);

%%

for s = 1:length(sList)
    thisS = sList(s);
    if thisS <= 9
        fileList = dir(fullfile(['..\Data\SONA\JHO', num2str(thisS), '-*']));
    % else
    %     fileList = dir(fullfile(['Data\JHO',num2str(thisS),'*']));
    end

    for b = 1:length(fileList)
        file_path = [fileList(b).folder, '\', fileList(b).name]
        load(file_path,'dataMat');

        for j = 1:length(dataMat.block)
            [s,j];
            if ~isempty(dataMat.block(j).trialRT)
                thisTrialGazeInfo   = [];
                totalTrialTime      = dataMat.block(j).trialRT;
                timeOnSummary       = dataMat.block(j).timeSelected(1);

                % no gazeData...
                for k = 1:length(dataMat.block(j).gazeData)
                    thisGazePoint = dataMat.block(j).gazeData(k).RightEye.GazePoint.OnDisplayArea;
                    if k / length(dataMat.block(j).gazeData) < timeOnSummary/totalTrialTime
                        gazeChecks = ...
                            (thisGazePoint(1) >= hitBoxes(:,1)).* ...
                            (thisGazePoint(1) <= hitBoxes(:,3)).* ...
                            (thisGazePoint(2) >= hitBoxes(:,2)).* ...
                            (thisGazePoint(2) <= hitBoxes(:,4));
                        thisTrialGazeInfo   = [thisTrialGazeInfo, [gazeChecks; zeros(length(hitBoxDetails),1)]];
                    else
                        gazeChecks = ...
                            (thisGazePoint(1) >= hitBoxDetails(:,1)).* ...
                            (thisGazePoint(1) <= hitBoxDetails(:,3)).* ...
                            (thisGazePoint(2) >= hitBoxDetails(:,2)).* ...
                            (thisGazePoint(2) <= hitBoxDetails(:,4));
                        thisTrialGazeInfo = [thisTrialGazeInfo, [zeros(length(hitBoxes),1);gazeChecks]];
                    end
                end
                save(['GazeInfo',num2str(s),'-',num2str(j),'.mat'],'thisTrialGazeInfo');

                % load(['GazeInfo',num2str(s),'-',num2str(j),'.mat'],'thisTrialGazeInfo');
        
                bedProp(s,j)    = sum(mean(thisTrialGazeInfo(13:18,:),2));
                extProp(s,j)    = sum(mean(thisTrialGazeInfo(1:6,:),2));
                intProp(s,j)    = sum(mean(thisTrialGazeInfo(7:12,:),2));
                bathProp(s,j)   = sum(mean(thisTrialGazeInfo(19:24,:),2));
                sqftProp(s,j)   = sum(mean(thisTrialGazeInfo(25:30,:),2));
                priceProp(s,j)  = sum(mean(thisTrialGazeInfo(31:36,:),2));
        
                extDetail(s,j)  = sum(mean(thisTrialGazeInfo(37,:),2));
                livDetail(s,j)  = sum(mean(thisTrialGazeInfo(38,:),2));
                bedDetail(s,j)  = sum(mean(thisTrialGazeInfo(39,:),2));
                bathDetail(s,j) = sum(mean(thisTrialGazeInfo(40,:),2));
                outDetail(s,j)  = sum(mean(thisTrialGazeInfo(41,:),2));
                kitDetail(s,j)  = sum(mean(thisTrialGazeInfo(42,:),2));
                priceDetail(s,j)= sum(mean(thisTrialGazeInfo(43,:),2));
                nBedDetail(s,j) = sum(mean(thisTrialGazeInfo(44,:),2));
                nBathDetail(s,j)= sum(mean(thisTrialGazeInfo(45,:),2));
                sqftDetail(s,j) = sum(mean(thisTrialGazeInfo(46,:),2));
                lotDetail(s,j)  = sum(mean(thisTrialGazeInfo(47,:),2));
                yearDetail(s,j) = sum(mean(thisTrialGazeInfo(48,:),2));
        
                optionChosen(s,j)   = dataMat.block(j).chosenOption;
                chosenAttsBed(s,j)  = table2array(dataMat.block(j).chosenAtts(:,3));
                chosenAttsBath(s,j) = table2array(dataMat.block(j).chosenAtts(:,4));
                chosenAttsSqft(s,j) = table2array(dataMat.block(j).chosenAtts(:,5));
                chosenAttsLot(s,j)  = table2array(dataMat.block(j).chosenAtts(:,6));
                chosenAttsYear(s,j) = table2array(dataMat.block(j).chosenAtts(:,7));
                chosenAttsPrice(s,j)= table2array(dataMat.block(j).chosenAtts(:,8));
                bidMade(s,j)        = dataMat.block(j).lastBid;
                overallRT(s,j)      = dataMat.block(j).trialRT;
        
                marketTimes(s,j)    = mean(dataMat.block(j).marketTimes);
        
                subject(s,j) = s;
                block(s,j) = j;
            end
        end
    end

end

%% Create summary of the trial

block = block(:);
okInd = find(block ~= 0);
block = block(okInd);

vars = {...
    subject, marketTimes, optionChosen, bidMade, overallRT, ...
    chosenAttsBed, chosenAttsBath, chosenAttsSqft, chosenAttsLot, chosenAttsYear, chosenAttsPrice, ...
    bedProp, extProp, intProp, bathProp, sqftProp, priceProp, ...
    extDetail, livDetail, bedDetail, bathDetail, bathDetail, outDetail, kitDetail, priceDetail, ...
    nBedDetail, nBathDetail, sqftDetail, lotDetail, yearDetail ...
};

for var = 1:length(vars)
    vars{var} = process_var(vars{var}, okInd);
end
summaryTable = cell2table(vars{:}, 'VariableNames', variableNames);

% block = block(:);
% okInd = find(block ~= 0);
% block = block(okInd);

% subject = subject(:);
% subject = subject(okInd);

% marketTimes = marketTimes(:);
% marketTimes = marketTimes(okInd);

% optionChosen = optionChosen(:);
% optionChosen = optionChosen(okInd);
% bidMade = bidMade(:);
% bidMade = bidMade(okInd);
% overallRT = overallRT(:);
% overallRT= overallRT(okInd);
% chosenAttsBed = chosenAttsBed(:);
% chosenAttsBed = chosenAttsBed(okInd);
% chosenAttsBath = chosenAttsBath(:);
% chosenAttsBath = chosenAttsBath(okInd);
% chosenAttsSqft = chosenAttsSqft(:);
% chosenAttsSqft = chosenAttsSqft(okInd);
% chosenAttsLot = chosenAttsLot(:);
% chosenAttsLot= chosenAttsLot(okInd);
% chosenAttsYear = chosenAttsYear(:);
% chosenAttsYear= chosenAttsYear(okInd);
% chosenAttsPrice = chosenAttsPrice(:);
% chosenAttsPrice= chosenAttsPrice(okInd);
% bedProp = bedProp(:);
% bedProp = bedProp(okInd);
% extProp = extProp(:);
% extProp = extProp(okInd);
% intProp = intProp(:);
% intProp = intProp(okInd);
% bathProp = bathProp(:);
% bathProp= bathProp(okInd);
% sqftProp = sqftProp(:);
% sqftProp = sqftProp(okInd);
% priceProp = priceProp(:);
% priceProp = priceProp(okInd);
% extDetail=extDetail(:);
% extDetail= extDetail(okInd);
% livDetail = livDetail(:);
% livDetail= livDetail(okInd);
% bedDetail=bedDetail(:);
% bedDetail= bedDetail(okInd);
% bathDetail=bathDetail(:);
% bathDetail= bathDetail(okInd);
% outDetail = outDetail(:);
% outDetail= outDetail(okInd);
% kitDetail=kitDetail(:);
% kitDetail = kitDetail(okInd);
% priceDetail= priceDetail(:);
% priceDetail= priceDetail(okInd);
% nBedDetail =nBedDetail(:);
% nBedDetail= nBedDetail(okInd);
% nBathDetail =nBathDetail(:);
% nBathDetail= nBathDetail(okInd);
% sqftDetail =sqftDetail(:);
% sqftDetail = sqftDetail(okInd);
% lotDetail = lotDetail(:);
% lotDetail = lotDetail(okInd);
% yearDetail = yearDetail(okInd);

% summaryTable = table(subject, block, optionChosen, bidMade, overallRT, chosenAttsBed, ...
%      chosenAttsBath, chosenAttsSqft, chosenAttsLot, chosenAttsYear, chosenAttsPrice, ...
%      bedProp, extProp, intProp, bathProp, sqftProp, priceProp, ...
%      extDetail, livDetail, bedDetail, bathDetail, outDetail, kitDetail, ...
%      priceDetail, nBedDetail, nBathDetail, sqftDetail, lotDetail, yearDetail);

% % summaryMat = [subject(okInd), block(okInd), optionChosen(okInd), bidMade(okInd), overallRT(okInd), chosenAttsBed(okInd), ...
    % chosenAttsBath(okInd), chosenAttsSqft(okInd), chosenAttsLot(okInd), chosenAttsYear(okInd), chosenAttsPrice(okInd), ...
    % bedProp(okInd), extProp(okInd), intProp(okInd), bathProp(okInd), sqftProp(okInd), priceProp(okInd), ...
    % extDetail(okInd), livDetail(okInd), bedDetail(okInd), bathDetail(okInd), outDetail(okInd), kitDetail(okInd), ...
    % priceDetail(okInd), nBedDetail(okInd), nBathDetail(okInd), sqftDetail(okInd), lotDetail(okInd), yearDetail(okInd)];

save('JHO_Summary.mat');

%% functions

function arr = process_var(var, okInd)
    if ~isvector(var)
        error('Input variable must be a vector.');
    end
    if ~islogical(okInd) && ~isnumeric(okInd)
        error('Index variable must be logical or numeric.');
    end

    arr = var(:);
    arr = var(okInd);
end