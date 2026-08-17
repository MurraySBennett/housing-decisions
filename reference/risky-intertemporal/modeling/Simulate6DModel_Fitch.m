clear;

payoff = 10;
prob = 1;
delay = 0;

util = .8;
k = .01;
b = .7;

stepSize = .01;

threshold = 2;

minPayoff = 0;
maxPayoff = 20;
minProb = 0;
maxProb = 1;
minDelay = 0;
maxDelay = 250;



s = [0,0,0,0,0,0];
traj = [];

while norm(s) < threshold

    lookingInd = mnrnd(1,[.34, .33, .33]);%mnrnd(1,[.45, .35, .2]);
    lookingAt = find(lookingInd);

    switch lookingAt
        case 1 % looking at the payoff
            stepDir = (pi/2)*(payoff/maxPayoff)^(util);
            s = s + stepSize * [cos(stepDir), sin(stepDir), 0, 0, 0, 0];
        case 2 % looking at risk
            stepDir = (pi/2) * exp(-(-log(prob))^b);
            s = s + stepSize * [0,0, cos(stepDir), sin(stepDir), 0, 0];

        case 3 % looking at delay
            stepDir = (pi/2) * 1 / (1 + k*delay);
            s = s + stepSize * [0, 0, 0, 0, cos(stepDir), sin(stepDir)];
    end

    traj = [traj; s];

    

end




%zeroAngle = [1 0 1 0 1 0];

% distance from origin = more gaze - more "weight"
% angle is related to the values of the attributes
% probability and delay have to be mapped onto payoff somehow - can't hold
% inherent value or else you would overpay for $.01
% When mapping, we want to conserve distance from origin/weight -
% semi-collapse the delay and probability vectors as proportions of the
% payoff's angle
% add each attribute's component together - final response angle
% this results in the payoff getting more "weight" than probability or
% delay
% strange predictions : 0 probability doesn't result in a 0 price unless
% they only look at probability

% issues with multiplying delay and risk - $10, 90%, 100 days, if they
% mostly look at the outcome and probability, you'd expect a high price -
% but if they glance at delay the delay component will be very small
% regardless of discounting - mutiplied with the probability component will
% result in the combined component being very small resulting in a low
% price.

% multiply all of it? - then you aren't constrained correctly - can assign
% prices higher than the payoff

payVec = [s(1),s(2)];
probVec = [s(3),s(4)];
delayVec = [s(5),s(6)];
payAngle = atan2(payVec(2),payVec(1));
probAngle = atan2(probVec(2),probVec(1));
delayAngle = atan2(delayVec(2),delayVec(1));


thisResp = (payAngle*probAngle*delayAngle / (pi/2)^3)^(1/util) * maxPayoff; % turn from utiles back into dollar values



probCompAngle = payAngle*(probAngle/(pi/2)); % angle of component = proportion of payoff angle % payoff angle times probability weight
probTheta = probAngle-probCompAngle;
probRotation = [cos(probTheta) -sin(probTheta); sin(probTheta) cos(probTheta)]; % rotation from prob-weighted payoff to probability
probComp = probVec*probRotation; % take probability weight and apply it to the payoff

delayCompAngle = payAngle*(delayAngle/(pi/2)); % payoff angle times discount factor
delayTheta = delayAngle-delayCompAngle;
delayRotation = [cos(delayTheta) -sin(delayTheta); sin(delayTheta) cos(delayTheta)];
delayComp = delayVec*delayRotation; % take discount factor and assign it to the payoff

%%%%% Assumption: apply accumulation vector while looking at an attribute.
%%%%% Also: apply rotation as soon as both have been seen?

respVec =  payVec+probComp+delayComp; % payVec.*(probComp.*delayComp); % payVec+(probComp.*delayComp);

resp = atan2(respVec(2),respVec(1))
price = (resp*2/pi)^(1/util) * maxPayoff


% respAngle = acos(dot(s,zeroAngle) / (norm(s)*norm(zeroAngle)))
% resp = respAngle / (pi/2) * maxPayoff
% resp = s(1)*s(3)*s(5) ___

figure(1)
subplot(1,3,1)
plot(traj(:,1),traj(:,2))
subplot(1,3,2)
plot(traj(:,3),traj(:,4))
subplot(1,3,3)
plot(traj(:,5),traj(:,6))

figure(2)
scatter(payVec(1),payVec(2))
hold on
scatter(probComp(1),probComp(2))
hold on
scatter(delayComp(1),delayComp(2))
hold on
scatter(respVec(1),respVec(2))
axis([0 pi 0 pi])
legend('Payoff','Prob','Delay','Resp')
hold off

