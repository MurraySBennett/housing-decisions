payoff = 10;
prob = .5;
delay = 100;

util = .8;
k = .1;
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

    lookingInd = mnrnd(1,[.45, .35, .2]);
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

zeroAngle = [1 0 1 0 1 0];
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