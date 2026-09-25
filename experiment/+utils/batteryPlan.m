function rows = batteryPlan(participant, sessionNum, forceDomain, taskOrder)
%UTILS.BATTERYPLAN  Resolve the run_battery schedule for one participant.
%   rows = utils.batteryPlan(participant, sessionNum)
%   rows = utils.batteryPlan(participant, sessionNum, 'houses')
%   Single source of truth; run_battery.m executes rows, preflight.m validates.

if nargin < 3, forceDomain = ''; end
if nargin < 4, taskOrder = []; end
forceDomain = lower(char(forceDomain));

if sessionNum ~= 1
    error('hw:batteryPlan:noPlanForSession', ...
        'Between-subject collection uses session 1 only; got session == %d.', ...
        sessionNum);
end

assignedDomain = utils.ternary(mod(participant, 2) == 1, 'jobs', 'houses');
if ~isempty(forceDomain)
    assert(ismember(forceDomain, {'jobs','houses'}), ...
        'hw:batteryPlan:badForceDomain', ...
        'FORCE_DOMAIN must be '''', ''jobs'', or ''houses''.');
    assignedDomain = forceDomain;
end

PLAN = { ...
    struct('task', 'auction', 'domains', {{assignedDomain}}, 'session', 1), ...
    struct('task', 'contdc',  'domains', {{assignedDomain}}, 'session', 1), ...
    struct('task', 'pref',    'domains', {{assignedDomain}}, 'session', 1), ...
};
rows = PLAN;

domainIndex = ceil(participant / 2);
if isempty(taskOrder)
    taskOrder = mod(domainIndex - 1, 6) + 1;
else
    assert(isnumeric(taskOrder) && isscalar(taskOrder) && taskOrder == round(taskOrder) && ...
        taskOrder >= 1 && taskOrder <= 6, ...
        'hw:batteryPlan:badTaskOrder', 'taskOrder must be an integer from 1 to 6.');
end

% Counterbalancing; sortrows pins the list -- perms() row order is an implementation detail.
if numel(rows) == 3
    P = sortrows(perms(1:3));
    rows = rows(P(taskOrder, :));
elseif numel(rows) > 1 && mod(participant, 2) == 1
    rows = fliplr(rows);
end

end
