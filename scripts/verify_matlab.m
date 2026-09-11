function verify_matlab()
%VERIFY_MATLAB Headless checks for source/control-flow pieces.

root = fileparts(fileparts(mfilename('fullpath')));
expDir = fullfile(root, 'experiment');
addpath(expDir);

tmpRoot = fullfile(tempdir, ['housing_decisions_verify_' char(java.util.UUID.randomUUID)]);
cleanup = onCleanup(@() cleanupTemp(tmpRoot));
cfg = utils.config('projRoot', tmpRoot, 'rig', 'dev', 'testing', true);
assert(isstruct(cfg.contdc.nPairs), 'cfg.contdc.nPairs must be per-domain struct');
assert(isfield(cfg.contdc.nPairs, 'houses') && isfield(cfg.contdc.nPairs, 'jobs'), ...
    'cfg.contdc.nPairs must define houses and jobs');
assert(~cfg.contdc.allowCrossLevelReuse, 'cross-level reuse should default off');
assert(isfield(cfg.et, 'sampleRateHz'), 'cfg.et.sampleRateHz missing');

stimCfg = struct();
stimCfg.stimFiles.houses = fullfile(expDir, 'stimuli', 'house_stimuli.csv');
stimCfg.stimFiles.jobs = fullfile(expDir, 'stimuli', 'prepared', 'job_stimuli_synthetic.csv');

houses = utils.readStimuli(stimCfg, 'houses');
jobs = utils.readStimuli(stimCfg, 'jobs');
assert(height(houses) > 0, 'houses stimuli did not load');
assert(height(jobs) > 0, 'jobs stimuli did not load');
for name = {'commuteMinutes','ptoDays','hoursPerWeek','workArrangement'}
    assert(ismember(name{1}, jobs.Properties.VariableNames), ...
        'prepared jobs file missing %s', name{1});
end

w = utils.sampleWindow([10 NaN 20 30]', 20, [0.5 1.5], 2);
assert(isequal(w.idx(:)', [1 3 4]), 'sampleWindow must return original table indices');

A = utils.attributes('jobs');
sel = utils.selectAttributes(A, 4, linspace(1, 0.1, A.nPool), 'stratified', false);
rs = RandStream('twister', 'Seed', 123);
[pairs, usedIdx] = utils.buildPairs(jobs, sel, A, 3, rs);
assert(numel(pairs) == 3, 'buildPairs did not produce requested smoke-test pairs');
assert(~isempty(usedIdx), 'buildPairs did not return used indices');

et = struct('enabled', false, 'obj', []);
sync = utils.clockSync(et);
assert(isfield(sync, 'ptbSecs') && isfield(sync, 'tobiiSystemTimeStamp') && isfield(sync, 'ok'), ...
    'clockSync output shape changed');

txt = utils.incentives('instructions', 'houses', cfg.incentives);
assert(contains(txt, 'Right-click'), 'auction instructions must describe right-click controls');

pf = preflight(2, 1, 'projRoot', expDir, 'rig', 'dev', ...
    'testing', true, 'runChecks', false);
assert(isstruct(pf) && isfield(pf, 'resolvedPlan'), 'preflight must return resolvedPlan');
assert(isfield(pf, 'estimatedMinutes'), 'preflight must return estimatedMinutes');
assert(numel(pf.resolvedPlan) == 2, 'participant 2 session 1 should have two plan rows');
assert(strcmp(pf.resolvedPlan(1).task, 'auction'), ...
    'even participant session 1 should start with auction');
assert(strcmp(pf.resolvedPlan(1).domains{1}, 'jobs'), ...
    'session 1 default domain should be jobs');

pfAoi = preflight(2, 1, 'projRoot', expDir, 'rig', 'lab', ...
    'testing', true, 'runChecks', true);
assert(isfield(pfAoi, 'allAoiOK') && pfAoi.allAoiOK, ...
    'preflight lab AOI checks must pass');

fprintf('verify_matlab: ok\n');
end

function cleanupTemp(path)
if exist(path, 'dir')
    try
        rmdir(path, 's');
    catch
    end
end
end
