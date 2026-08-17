load('RIEData.mat');

% trialType 
% 1 = choice both
% 2 = price both
% 3 = choice risk
% 4 = price risk
% 5 = choice delay
% 6 = price delay

uCond = unique(trialType);

%% Look at overall proportion of each attribute

% What condition and relationship to looking at each attribute
for c = 1:length(uCond)
    thisCond = find(trialType == uCond(c));
    lookProp = mean(avgEyeData(thisCond,:)) ./ sum(mean(avgEyeData(thisCond,:)));
    disp(['Condition ', num2str(c),': ', num2str(lookProp)])

end


% Individual differences / weights on each attribute



% Connection to model parameters?


%% Look at saccades / order of inspection

% Payoff first? Anchoring

% Attribute-wise vs alternative-wise


%% Directly link to model on trial-to-trial basis

% Look at payoff, move toward payoff (anchoring)
% Look at delay, move toward 0? (longer delay = faster toward 0?)
% Look at risk, move toward 0? (lower prob = faster toward 0?)