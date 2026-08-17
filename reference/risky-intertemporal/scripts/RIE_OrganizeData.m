% RIE_OrganizeData collects data from the risky intertemporal eyetracking
% experiment and saves it as one (MATLAB and CSV) file
clear; 
sList = 1:40;
ind = 1;

screenSize = [1920 1080 1920 1080];
hitBoxWidth = 180;
hitBoxHeight = 120;
hitBoxAdj = [-hitBoxWidth, -hitBoxHeight, hitBoxWidth, hitBoxHeight];

hitBoxT = ([960 402 960 402] + hitBoxAdj)./screenSize; 
hitBoxL = ([845 608 845 608] + hitBoxAdj)./screenSize; 
hitBoxR = ([1075 608 1075 608] + hitBoxAdj)./screenSize; 

hitBoxTC1 = ([720 270 720 270] + hitBoxAdj)./screenSize; 
hitBoxMC1 = ([575 540 575 540] + hitBoxAdj)./screenSize; 
hitBoxBC1 = ([720 810 720 810] + hitBoxAdj)./screenSize; 

hitBoxTC2 = ([1200 270 1200 270] + hitBoxAdj)./screenSize; 
hitBoxMC2 = ([1350 540 1350 540] + hitBoxAdj)./screenSize; 
hitBoxBC2 = ([1200 810 1200 810] + hitBoxAdj)./screenSize; 


for s = sList
    for j = 1:3
        disp(['[',num2str(s),', ',num2str(j),']'])
        thisFileName = ['RIE',num2str(100+s,'%.0f'),'-',num2str(j),'.mat'];
        if exist(thisFileName,'file')
            load(thisFileName);

            nTrials = length(dataMat.trial);

            for n = 1:nTrials
                thisRT = dataMat.trial(n).rt;
                if thisRT > .25 && thisRT < 15
                    resp(ind,1) = dataMat.trial(n).resp;
                    rt(ind,1) = dataMat.trial(n).rt;
                    subjectNum(ind,1) = s;
                    sessionNum(ind,1) = j;
                    blockNum(ind,1) = dataMat.trial(n).blockNum;
                    stimLoc(ind,1) = dataMat.trial(n).StimLocation;
                    stimNum(ind,1) = dataMat.trial(n).gambleNum;
                    trialType(ind,1) = dataMat.trial(n).type; % 1 = choice RD, 2 = price RD, 3 = choice D, 4 = price D, 5 = choice R, 6 = price R
    
                    if mod(trialType(ind,1),2) == 0
                        isChoice(ind,1) = 0;
                        stim(ind,:) = [dataMat.trial(n).stim, 0, 0, 0];
                        mouseTraj{ind} = dataMat.trial(n).traj;
                    else
                        isChoice(ind,1) = 1;
                        stim(ind,:) = dataMat.trial(n).stim;
                    end
                    if any(trialType(ind) == [1,2,5,6])
                        isDelay(ind,1) = 1;
                    else
                        isDelay(ind,1) = 0;
                    end
                    if trialType(ind) < 5
                        isRisk(ind,1) = 1;
                    else
                        isRisk(ind,1) = 0;
                    end
    
                    %% eyetracking data
                    thisTrialEyeData = [];
                    for k = 1:length(dataMat.trial(n).gazeData)
                        thisPt = dataMat.trial(n).gazeData(k).RightEye.GazePoint.OnDisplayArea;
                        if isChoice(ind) == 0
                            thisEyeData = [(thisPt(1)>= hitBoxT(1)).*(thisPt(2)>= hitBoxT(2)).*(thisPt(1)<= hitBoxT(3)).*(thisPt(2)<= hitBoxT(4)); ...
                                           (thisPt(1)>= hitBoxL(1)).*(thisPt(2)>= hitBoxL(2)).*(thisPt(1)<= hitBoxL(3)).*(thisPt(2)<= hitBoxL(4)); ...
                                           (thisPt(1)>= hitBoxR(1)).*(thisPt(2)>= hitBoxR(2)).*(thisPt(1)<= hitBoxR(3)).*(thisPt(2)<= hitBoxR(4))];
    
                            switch stimLoc(ind,1)
                                case 2 % 2 = payoff top, delay bottom, prob middle (flip 2 and 3)
                                    thisEyeData = thisEyeData([1,3,2],:);
                                case 3 % 3 = payoff middle, delay top, prob bottom (flip 1 and 2)
                                    thisEyeData = thisEyeData([2,1,3],:);
                                case 4 % 4 = payoff middle, delay bottom, prob top (1->2, 2->3, 3->1)
                                    thisEyeData = thisEyeData([2,3,1],:);
                                case 5 % 5 = payoff bottom, delay top, prob middle (1->3, 2->1, 3->2)
                                    thisEyeData = thisEyeData([3,1,2],:);
                                case 6 % 6 = payoff bottom, delay middle, prob top (flip 1 and 3)
                                    thisEyeData = thisEyeData([3,2,1],:);
                            end
    
                            thisTrialEyeData = [thisTrialEyeData, [thisEyeData;0;0;0]];
    
                        else
                            thisEyeData = [(thisPt(1)>= hitBoxTC1(1)).*(thisPt(2)>= hitBoxTC1(2)).*(thisPt(1)<= hitBoxTC1(3)).*(thisPt(2)<= hitBoxTC1(4)); ...
                                           (thisPt(1)>= hitBoxMC1(1)).*(thisPt(2)>= hitBoxMC1(2)).*(thisPt(1)<= hitBoxMC1(3)).*(thisPt(2)<= hitBoxMC1(4)); ...
                                           (thisPt(1)>= hitBoxBC1(1)).*(thisPt(2)>= hitBoxBC1(2)).*(thisPt(1)<= hitBoxBC1(3)).*(thisPt(2)<= hitBoxBC1(4)); ...
                                           (thisPt(1)>= hitBoxTC2(1)).*(thisPt(2)>= hitBoxTC2(2)).*(thisPt(1)<= hitBoxTC2(3)).*(thisPt(2)<= hitBoxTC2(4)); ...
                                           (thisPt(1)>= hitBoxMC2(1)).*(thisPt(2)>= hitBoxMC2(2)).*(thisPt(1)<= hitBoxMC2(3)).*(thisPt(2)<= hitBoxMC2(4)); ...
                                           (thisPt(1)>= hitBoxBC2(1)).*(thisPt(2)>= hitBoxBC2(2)).*(thisPt(1)<= hitBoxBC2(3)).*(thisPt(2)<= hitBoxBC2(4))];
    
                            switch stimLoc(ind,1)
                                case 2 % 2 = payoff top, delay bottom, prob middle (flip 2 and 3)
                                    thisEyeData = thisEyeData([1,3,2,4,6,5],:);
                                case 3 % 3 = payoff middle, delay top, prob bottom (flip 1 and 2)
                                    thisEyeData = thisEyeData([2,1,3,5,4,6],:);
                                case 4 % 4 = payoff middle, delay bottom, prob top (1->2, 2->3, 3->1)
                                    thisEyeData = thisEyeData([2,3,1,5,6,4],:);
                                case 5 % 5 = payoff bottom, delay top, prob middle (1->3, 2->1, 3->2)
                                    thisEyeData = thisEyeData([3,1,2,6,4,5],:);
                                case 6 % 6 = payoff bottom, delay middle, prob top (flip 1 and 3)
                                    thisEyeData = thisEyeData([3,2,1,6,5,4],:);
                            end
    
                            thisTrialEyeData = [thisTrialEyeData, thisEyeData];
                        end
                    end
                    eyeData{ind} = thisTrialEyeData;
                    avgEye = mean(thisTrialEyeData,2);
    
                    if ~isempty(avgEye)
                        avgEyeData(ind,:) = avgEye';
                    end
    
                    ind = ind + 1;

                end
                

          % 1 = payoff top, delay middle, prob bottom
          
         
          
          
          

            end

        end
    end
end

%% Save organized data
save('RIEData.mat')
dataTable = table(subjectNum, sessionNum, blockNum, isChoice, isDelay, isRisk, stimNum, stim, stimLoc, trialType, avgEyeData, resp, rt);
writetable(dataTable,'RIEData.csv')