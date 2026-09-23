function sess = startSession(varargin)
%UTILS.STARTSESSION  Create (or resume) a participant session record.
%
%   sess = utils.startSession('testing', true, 'participant', 9999, ...)
%   All name-value options optional; missing ones are prompted for unless testing.

p = inputParser;
p.addParameter('participant', [], @(x) isempty(x) || isnumeric(x));
p.addParameter('session',     [], @(x) isempty(x) || isnumeric(x));
p.addParameter('domain',      [], @(x) isempty(x) || (isnumeric(x) && ismember(x,1:3)));
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
p.parse(varargin{:});
opt = p.Results;

cfg = utils.config('projRoot', opt.projRoot, 'rig', opt.rig, ...
                'testing', opt.testing, 'jobsArm', opt.jobsArm, ...
                'trialsPerCell', opt.trialsPerCell);

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
        opt.participant = utils.promptNumeric('Participant #: ', 1, 99999);
    end
    if isempty(opt.domain)
        fprintf(['(Domain is normally set per-run by PLAN in run_battery.m.\n' ...
                 ' This prompt only matters if a task is called standalone.)\n']);
        opt.domain = utils.promptNumeric('Jobs (1), Houses (2), or both (3): ', 1, 3);
    end
    if isempty(opt.session)
        opt.session = utils.promptNumeric('Session #: ', 1, 20);
    end
end

sess.participant  = opt.participant;
sess.sessionNum   = opt.session;
sess.domainNum    = opt.domain;
sess.testing      = opt.testing;
sess.cfg          = cfg;
sess.codeVersion  = cfg.codeVersion;

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
    manifest.createdAt   = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
    manifest.runs        = struct('task',{},'sessionNum',{},'runId',{}, ...
                                  'domainOrderStr',{},'startedAt',{}, ...
                                  'finishedAt',{},'status',{},'dataFile',{}, ...
                                  'seed',{},'codeVersion',{});
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

end
