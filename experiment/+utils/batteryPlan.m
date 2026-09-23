function rows = batteryPlan(participant, sessionNum, forceDomain)
%UTILS.BATTERYPLAN  Resolve the run_battery schedule for one participant.
%
%   rows = utils.batteryPlan(participant, sessionNum)
%   rows = utils.batteryPlan(participant, sessionNum, 'houses')
%
%   This is the single source of truth for PLAN resolution: session
%   filtering, optional FORCE_DOMAIN, and odd-participant task-order
%   counterbalancing. run_battery.m executes these rows; preflight.m prints
%   and validates them before a lab run.

if nargin < 3, forceDomain = ''; end
forceDomain = lower(char(forceDomain));

PLAN = { ...
    struct('task', 'auction', 'domains', {{'jobs'}},   'session', 1), ...
    struct('task', 'contdc',  'domains', {{'jobs'}},   'session', 1), ...
    struct('task', 'pref',    'domains', {{'jobs'}},   'session', 1), ...
    struct('task', 'auction', 'domains', {{'houses'}}, 'session', 2), ...
    struct('task', 'contdc',  'domains', {{'houses'}}, 'session', 2), ...
    struct('task', 'pref',    'domains', {{'houses'}}, 'session', 2), ...
};

rows = PLAN(cellfun(@(r) r.session == sessionNum, PLAN));
if isempty(rows)
    error('hw:batteryPlan:noPlanForSession', ...
        'No PLAN rows have session == %d. Check utils.batteryPlan or the session number entered.', ...
        sessionNum);
end

if ~isempty(forceDomain)
    assert(ismember(forceDomain, {'jobs','houses'}), ...
        'hw:batteryPlan:badForceDomain', ...
        'FORCE_DOMAIN must be '''', ''jobs'', or ''houses''.');
    for k = 1:numel(rows)
        rows{k}.domains = {forceDomain};
    end
end

% Task-order counterbalancing. Three tasks per session get the full set
% of 6 orders keyed to participant number; any other multi-row session
% keeps the original parity flip. sortrows pins the permutation list to a
% fixed order -- perms() row order is an implementation detail.
if numel(rows) == 3
    P = sortrows(perms(1:3));
    rows = rows(P(mod(participant, 6) + 1, :));
elseif numel(rows) > 1 && mod(participant, 2) == 1
    rows = fliplr(rows);
end

end
