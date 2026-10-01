function sess = startSession(varargin)
%UTILS.STARTSESSION  Create (or resume) a participant session record.
%
%   sess = utils.startSession('testing', true, 'participant', 9999, ...)
%   All name-value options optional; missing ones are prompted for unless testing.

p = inputParser;
p.addParameter('participant', [], @(x) isempty(x) || isnumeric(x));
p.addParameter('session',     [], @(x) isempty(x) || isnumeric(x));
p.addParameter('domain',      [], @(x) isempty(x) || (isnumeric(x) && ismember(x,1:3)));
p.addParameter('taskOrder',   [], @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && x >= 1 && x <= 6 && x == round(x)));
p.addParameter('confirmAssignment', true, @islogical);
p.addParameter('testing',     false, @islogical);
p.addParameter('trialsPerCell', [], @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && x >= 1 && x == round(x)));
% Empty means "use the rig profile's default"; only an explicit true/false overrides.
p.addParameter('eyeTracking', [], @(x) isempty(x) || islogical(x));
p.addParameter('showEyePos',  [], @(x) isempty(x) || islogical(x));
p.addParameter('projRoot',    '', @(x) ischar(x) || isstring(x));
p.addParameter('rig',         'lab', @(x) ismember(lower(char(x)), {'lab','dev'}));
p.addParameter('jobsArm',     'synthetic', @(x) ismember(lower(char(x)), ...
    {'synthetic','ecological','attenuated'}));
p.addParameter('runKind',     'participant', @(x) ismember(lower(char(x)), ...
    {'participant','practice'}));
p.addParameter('dataRoot',    '', @(x) ischar(x) || isstring(x));
p.addParameter('practiceDataRoot', '', @(x) ischar(x) || isstring(x));
p.addParameter('assetRoot',   '', @(x) ischar(x) || isstring(x));
p.addParameter('tobiiRoot',   '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opt = p.Results;

cfg = utils.config('projRoot', opt.projRoot, 'rig', opt.rig, ...
                'testing', opt.testing, 'jobsArm', opt.jobsArm, ...
                'trialsPerCell', opt.trialsPerCell, ...
                'runKind', opt.runKind, ...
                'dataRoot', opt.dataRoot, ...
                'practiceDataRoot', opt.practiceDataRoot, ...
                'assetRoot', opt.assetRoot, ...
                'tobiiRoot', opt.tobiiRoot);

if ~isempty(opt.eyeTracking), cfg.et.enabled  = opt.eyeTracking; end
if ~isempty(opt.showEyePos),  cfg.et.showGaze = opt.showEyePos;  end

% --- Identify the participant ----------------------------------------
if opt.testing
    if isempty(opt.participant), opt.participant = 9999; end
    % Session defaults to 1, not a sentinel, so PLAN rows keyed on real session numbers still match.
    if isempty(opt.session),     opt.session     = 1;    end
    if isempty(opt.domain),      opt.domain      = 1;    end
else
    if isempty(opt.participant)
        [opt.participant, pick] = nextParticipant(cfg);
        autoAssigned = true;
    else
        autoAssigned = false;
        pick = struct('kind', 'manual', 'resumeHours', NaN, 'stale', []);
    end
    if isempty(opt.session), opt.session = 1; end
    if isempty(opt.domain), opt.domain = domainNumber(assignedDomain(opt.participant)); end
    if opt.confirmAssignment && strcmpi(cfg.runKind, 'participant')
        opt = confirmAssignment(opt, cfg, autoAssigned, pick);
    end
end

if isempty(opt.taskOrder)
    opt.taskOrder = defaultTaskOrder(opt.participant);
end

sess.participant  = opt.participant;
sess.sessionNum   = opt.session;
sess.domainNum    = opt.domain;
sess.testing      = opt.testing;
sess.runKind      = cfg.runKind;
sess.cfg          = cfg;
sess.codeVersion  = cfg.codeVersion;
overrideFlag      = assignmentOverride(opt.participant, opt.session, opt.domain, opt.taskOrder);
sess.assignment   = struct( ...
    'assignedDomain', assignedDomain(sess.participant), ...
    'domain', char(domainName(sess.domainNum)), ...
    'domainIndex', ceil(sess.participant / 2), ...
    'taskOrder', opt.taskOrder, ...
    'assignmentOverride', overrideFlag);

% --- Manifest: one file per participant, appended to by every task ----
sess.manifestFile = fullfile(cfg.paths.sessions, ...
    sprintf('sub-%05d_manifest.mat', sess.participant));

% Testing always starts a fresh manifest; resume semantics are for real participants only.
if opt.testing && exist(sess.manifestFile, 'file')
    delete(sess.manifestFile);
end

if exist(sess.manifestFile, 'file')
    M = load(sess.manifestFile, 'manifest');
    manifest = M.manifest;
    if ~isfield(manifest, 'runKind'), manifest.runKind = sess.runKind; end
    if ~isfield(manifest, 'assignment'), manifest.assignment = sess.assignment; end
    if ~isfield(manifest.runs, 'runKind')
        oldRuns = manifest.runs;
        manifest.runs = emptyRuns();
        for r = 1:numel(oldRuns)
            manifest.runs(r) = struct( ...
                'task', oldRuns(r).task, ...
                'sessionNum', oldRuns(r).sessionNum, ...
                'runId', oldRuns(r).runId, ...
                'runKind', manifest.runKind, ...
                'domainOrderStr', oldRuns(r).domainOrderStr, ...
                'startedAt', oldRuns(r).startedAt, ...
                'finishedAt', oldRuns(r).finishedAt, ...
                'status', oldRuns(r).status, ...
                'dataFile', oldRuns(r).dataFile, ...
                'seed', oldRuns(r).seed, ...
                'codeVersion', oldRuns(r).codeVersion);
        end
        save(sess.manifestFile, 'manifest');
    end
    fprintf('\n--- Resuming participant %d ---\n', sess.participant);
    if ~isempty(manifest.runs)
        fprintf('Tasks already completed:\n');
        for k = 1:numel(manifest.runs)
            fprintf('   [%s] %s (session %d, %s) -- %s\n', ...
                manifest.runs(k).status, manifest.runs(k).task, ...
                manifest.runs(k).sessionNum, manifest.runs(k).domainOrderStr, ...
                manifest.runs(k).startedAt);
        end
    end
    if ~opt.testing
        go = input('Continue with this participant? (y/n): ', 's');
        if ~strcmpi(strtrim(go), 'y')
            error('hw:startSession:aborted', 'Aborted by experimenter.');
        end
    end
else
manifest = struct();
    manifest.participant = sess.participant;
    manifest.runKind     = sess.runKind;
    manifest.assignment   = sess.assignment;
    manifest.createdAt   = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
    manifest.runs        = emptyRuns();
    save(sess.manifestFile, 'manifest');
    fprintf('\n--- New participant %d, manifest created ---\n', sess.participant);
end

sess.manifest = manifest;

% --- Domain order -----------------------------------------------------
allDomains = {'jobs','houses'};
if sess.domainNum < 3
    sess.domains = allDomains(sess.domainNum);
else
    % Counterbalanced by parity, not at random, to stay balanced at small N.
    if mod(sess.participant, 2) == 0
        sess.domains = allDomains;
    else
        sess.domains = fliplr(allDomains);
    end
end
sess.domainOrderStr = strjoin(sess.domains, '>');

% --- Eye tracking -----------------------------------------------------
% Metadata only; the tasks themselves read cfg.et.enabled/showGaze.
sess.eyeTracking = cfg.et.enabled;
sess.showEyePos  = cfg.et.showGaze;

fprintf('Participant %d | session %d | domains: %s\n', ...
    sess.participant, sess.sessionNum, sess.domainOrderStr);
fprintf('Task order slot: %d | override: %s\n', ...
    sess.assignment.taskOrder, utils.ternary(sess.assignment.assignmentOverride, 'yes', 'no'));
fprintf('Run kind: %s | data root: %s\n', sess.runKind, sess.cfg.paths.data);

end

function runs = emptyRuns()
runs = struct('task',{},'sessionNum',{},'runId',{}, ...
              'runKind',{},'domainOrderStr',{},'startedAt',{}, ...
              'finishedAt',{},'status',{},'dataFile',{}, ...
              'seed',{},'codeVersion',{});
end

function [id, pick] = nextParticipant(cfg)
%NEXTPARTICIPANT  Propose the participant number for this session.
%   [id, pick] = nextParticipant(cfg)
%
%   A participant with incomplete runs is proposed for RESUMING, but only if the
%   incompleteness is recent (cfg.session.resumeWindowHours). Anything older is
%   treated as abandoned: it is skipped, and returned in pick.stale so the
%   console can show it rather than silently swallowing it.
%
%   pick.kind is 'resume' or 'new'. The caller MUST surface this -- proposing a
%   resume as though it were a fresh participant is how runs get appended to
%   someone else's data.
ids = [];
resumeIds = [];
resumeHrs = [];

if exist(cfg.paths.sessions, 'dir')
    d = dir(fullfile(cfg.paths.sessions, 'sub-*_manifest.mat'));
    ids = [ids, idsFromNames({d.name})]; %#ok<AGROW>
    for k = 1:numel(d)
        f = fullfile(d(k).folder, d(k).name);
        tok = regexp(d(k).name, 'sub-(\d+)', 'tokens', 'once');
        if isempty(tok), continue; end
        pid = str2double(tok{1});
        if pid < 1 || pid >= 9000, continue; end
        try
            M = load(f, 'manifest');
            if isfield(M, 'manifest') && isfield(M.manifest, 'runs') && ...
                    ~isempty(M.manifest.runs)
                statuses = {M.manifest.runs.status};
                if any(~strcmp(statuses, 'complete'))
                    resumeIds(end+1) = pid; %#ok<AGROW>
                    resumeHrs(end+1) = manifestAgeHours(M.manifest.runs); %#ok<AGROW>
                end
            end
        catch
        end
    end
end

taskNames = fieldnames(cfg.paths.taskData);
for k = 1:numel(taskNames)
    dpath = cfg.paths.taskData.(taskNames{k});
    if exist(dpath, 'dir')
        d = dir(fullfile(dpath, 'sub-*.csv'));
        ids = [ids, idsFromNames({d.name})]; %#ok<AGROW>
    end
end

ids = unique(ids(ids >= 1 & ids < 9000));

% Split resumable participants by how long they have been incomplete. Only a
% recent one is a genuine mid-session resume; an old one has abandoned the study
% and must not keep being proposed ahead of the next new participant.
window = 12;
if isfield(cfg, 'session') && isfield(cfg.session, 'resumeWindowHours')
    window = cfg.session.resumeWindowHours;
end
isFresh   = resumeHrs <= window;
fresh     = resumeIds(isFresh);
freshHrs  = resumeHrs(isFresh);
stale     = sort(resumeIds(~isFresh));

pick = struct('kind', 'new', 'resumeHours', NaN, 'stale', stale);

if ~isempty(fresh)
    % Most recently active wins, not lowest ID: with two unfinished participants
    % the one still in the chair is the one that was just touched.
    [pick.resumeHours, which] = min(freshHrs);
    id = fresh(which);
    pick.kind = 'resume';
    return
end

if isempty(ids)
    id = 1;
else
    id = max(ids) + 1;
end
end


function w = resumeWindow(cfg)
w = 12;
if isfield(cfg, 'session') && isfield(cfg.session, 'resumeWindowHours')
    w = cfg.session.resumeWindowHours;
end
end


function s = humanHours(h)
%HUMANHOURS  "40 min" / "3.5 h" / "2 days" -- an RA should not have to convert.
if isnan(h)
    s = 'an unknown time';
elseif h < 1
    s = sprintf('%d min', max(1, round(h * 60)));
elseif h < 48
    s = sprintf('%.1f h', h);
else
    s = sprintf('%.0f days', h / 24);
end
end


function h = manifestAgeHours(runs)
%MANIFESTAGEHOURS  Hours since the most recent activity in a manifest.
%   Inf when no timestamp can be read, so an unparseable manifest is treated as
%   abandoned rather than proposed as a live resume.
t = NaT;
for f = {'finishedAt', 'startedAt'}
    if ~isfield(runs, f{1}), continue; end
    vals = {runs.(f{1})};
    for k = 1:numel(vals)
        if isempty(vals{k}), continue; end
        try
            tk = datetime(vals{k}, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
            if isnat(t) || tk > t
                t = tk;
            end
        catch
            % Unreadable stamp; other runs may still carry a usable one.
        end
    end
end
if isnat(t)
    h = Inf;
else
    h = hours(datetime('now') - t);
end
end

function ids = idsFromNames(names)
ids = [];
for k = 1:numel(names)
    tok = regexp(names{k}, 'sub-(\d+)', 'tokens', 'once');
    if ~isempty(tok)
        ids(end+1) = str2double(tok{1}); %#ok<AGROW>
    end
end
end

function opt = confirmAssignment(opt, cfg, autoAssigned, pick)
if nargin < 4
    pick = struct('kind', 'manual', 'resumeHours', NaN, 'stale', []);
end
while true
    domain = char(domainName(opt.domain));
    order = defaultTaskOrder(opt.participant);
    if ~isempty(opt.taskOrder), order = opt.taskOrder; end
    fprintf('\n=== Proposed participant assignment ===\n');

    % A resume must never be presented as a fresh participant: continuing
    % appends runs to someone who has already done part of the battery.
    if autoAssigned && strcmp(pick.kind, 'resume')
        fprintf(2, ['*** THIS IS A RESUME, NOT A NEW PARTICIPANT. ***\n' ...
                    '    Participant %d has unfinished runs from %s ago.\n' ...
                    '    Continuing ADDS to their existing data. If the person\n' ...
                    '    in front of you is new, press e and type the next\n' ...
                    '    unused number instead.\n'], ...
            opt.participant, humanHours(pick.resumeHours));
        label = ' (RESUMING an unfinished participant)';
    elseif autoAssigned
        label = ' (next unused ID)';
    else
        label = '';
    end
    fprintf('Participant: %d%s\n', opt.participant, label);
    fprintf('Session:     %d\n', opt.session);
    fprintf('Domain:      %s (%s participant ID)\n', domain, ...
        utils.ternary(mod(opt.participant, 2) == 1, 'odd', 'even'));
    fprintf('Task order:  slot %d: %s\n', order, taskOrderLabel(order));
    fprintf('Run kind:    %s\n', cfg.runKind);
    fprintf('Data root:   %s\n', cfg.paths.data);

    % Skipped-over abandoned participants are shown, not swallowed: they are the
    % only trace that someone did not finish, and one of them may be back.
    if ~isempty(pick.stale)
        fprintf(2, ['\nNOTE: %d %s unfinished for more than %g h, and NOT ' ...
                    'proposed here: %s\n' ...
                    '    Expected if they withdrew. If one of them has come ' ...
                    'back to finish,\n    press e and type their number.\n'], ...
            numel(pick.stale), ...
            utils.ternary(numel(pick.stale) == 1, 'participant is', 'participants are'), ...
            resumeWindow(cfg), strjoin(compose('%d', pick.stale), ', '));
    end

    answ = lower(strtrim(input('Press Enter to continue, e to edit, q to abort: ', 's')));
    if isempty(answ)
        opt.taskOrder = order;
        return
    elseif strcmp(answ, 'q')
        error('hw:startSession:aborted', 'Aborted by experimenter.');
    elseif strcmp(answ, 'e')
        opt.participant = utils.promptNumeric('Participant #: ', 1, 99999);
        d = utils.promptNumeric('Jobs/wages (1) or houses (2): ', 1, 2);
        opt.domain = d;
        opt.session = 1;
        opt.taskOrder = utils.promptNumeric('Task-order slot (1-6): ', 1, 6);
        return
    end
end
end

function domain = assignedDomain(participant)
if mod(participant, 2) == 1
    domain = 'jobs';
else
    domain = 'houses';
end
end

function n = domainNumber(domain)
switch lower(char(domain))
    case 'jobs'
        n = 1;
    case 'houses'
        n = 2;
    otherwise
        n = 3;
end
end

function domain = domainName(n)
allDomains = {'jobs','houses','jobs+houses'};
domain = allDomains{n};
end

function slot = defaultTaskOrder(participant)
slot = mod(ceil(participant / 2) - 1, 6) + 1;
end

function label = taskOrderLabel(slot)
tasks = {'auction','contdc','pref'};
P = sortrows(perms(1:3));
label = strjoin(tasks(P(slot, :)), ' -> ');
end

function tf = assignmentOverride(participant, sessionNum, domainNum, taskOrder)
tf = ~strcmp(char(assignedDomain(participant)), char(domainName(domainNum))) || ...
     taskOrder ~= defaultTaskOrder(participant) || sessionNum ~= 1;
end
