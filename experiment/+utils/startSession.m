function sess = startSession(varargin)
%UTILS.STARTSESSION  Create (or resume) a participant session record.
%
%   sess = utils.startSession()
%   sess = utils.startSession('testing', true, 'participant', 9999, ...)
%
%   Returns a struct that every task takes as its single argument. This is
%   the object that ties tasks to a participant. Each task still writes its
%   own independent data file -- the manifest is what joins them, so you can
%   run one task alone, both back to back, or between subjects without
%   changing any task code.
%
%   Name-value options (all optional; anything not supplied is prompted for
%   unless 'testing' is true):
%     'participant'  numeric participant ID
%     'session'      session number (1, 2, ...)
%     'domain'       1 = jobs, 2 = houses, 3 = both
%     'testing'      logical; skips prompts and uses placeholder values
%     'eyeTracking'  logical
%     'showEyePos'   logical (gaze dot overlay; debug/demo only)
%     'projRoot'     override project root

p = inputParser;
p.addParameter('participant', [], @(x) isempty(x) || isnumeric(x));
p.addParameter('session',     [], @(x) isempty(x) || isnumeric(x));
p.addParameter('domain',      [], @(x) isempty(x) || (isnumeric(x) && ismember(x,1:3)));
p.addParameter('testing',     false, @islogical);
p.addParameter('trialsPerCell', [], @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && x >= 1 && x == round(x)));
% Empty means "use the rig profile's default" -- only an EXPLICIT true/false
% here overrides it. The old default of `true` meant any bare call to
% startSession() silently forced eye tracking on even on the 'dev' rig,
% and separately, run_battery's EYETRACKING/SHOW_EYEPOS never actually
% reached cfg at all (see below) -- both are fixed together here.
p.addParameter('eyeTracking', [], @(x) isempty(x) || islogical(x));
p.addParameter('showEyePos',  [], @(x) isempty(x) || islogical(x));
p.addParameter('projRoot',    '', @(x) ischar(x) || isstring(x));
p.addParameter('rig',         'lab', @(x) ismember(lower(char(x)), {'lab','dev'}));
p.addParameter('jobsArm',     'synthetic', @(x) ismember(lower(char(x)), ...
    {'synthetic','ecological','attenuated'}));
p.parse(varargin{:});
opt = p.Results;

% This is the fix for cfg.testing.enabled staying false regardless of what
% was passed here: utils.config() previously took no testing/rig argument at
% all, so opt.testing never reached the struct the tasks actually read.
cfg = utils.config('projRoot', opt.projRoot, 'rig', opt.rig, ...
                'testing', opt.testing, 'jobsArm', opt.jobsArm, ...
                'trialsPerCell', opt.trialsPerCell);

% eyeTracking/showEyePos were computed onto sess.eyeTracking/sess.showEyePos
% below but NOTHING ever read those fields -- cfg.et.enabled came only from
% the rig profile, so passing EYETRACKING=false from run_battery silently
% did nothing. An explicit value here now overrides the rig default.
if ~isempty(opt.eyeTracking), cfg.et.enabled  = opt.eyeTracking; end
if ~isempty(opt.showEyePos),  cfg.et.showGaze = opt.showEyePos;  end

% --- Identify the participant ----------------------------------------
if opt.testing
    if isempty(opt.participant), opt.participant = 9999; end
    % Default to session 1, not a placeholder that can never match a real
    % PLAN entry -- PLAN in run_battery.m is keyed on real session numbers
    % (1, 2, ...), and a testing-only sentinel like 9999 guarantees
    % "No PLAN rows have session == 9999" on every dev run unless you
    % happen to override it. If your PLAN's rows span several sessions and
    % you want to smoke-test all of them in one go, pass 'session' to
    % startSession explicitly per session, or just add more PLAN rows to
    % session 1 while testing.
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

% Testing mode always starts a fresh manifest rather than resuming one.
% Participant 9999 (or whatever placeholder you use) is a disposable dev
% ID reused across many iterations in one sitting -- resuming it means
% every run's crash history piles onto the same file forever, which is
% exactly the wall of stale [crashed] entries that makes real problems
% hard to spot. Resume semantics only make sense for a real participant
% who might come back for session 2.
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
    % Counterbalance by participant parity rather than at random, so the
    % design stays balanced even with a small N.
    if mod(sess.participant, 2) == 0
        sess.domains = allDomains;
    else
        sess.domains = fliplr(allDomains);
    end
end
sess.domainOrderStr = strjoin(sess.domains, '>');

% --- Eye tracking -----------------------------------------------------
% Reflects the resolved values (rig default, overridden above if an
% explicit option was passed) -- this is metadata for anything reading
% `sess` directly; the tasks themselves read cfg.et.enabled/showGaze.
sess.eyeTracking = cfg.et.enabled;
sess.showEyePos  = cfg.et.showGaze;

fprintf('Participant %d | session %d | domains: %s\n', ...
    sess.participant, sess.sessionNum, sess.domainOrderStr);

end
