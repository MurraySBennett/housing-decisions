function report = export_gaze_csv(derivedRoot, varargin)
%EXPORT_GAZE_CSV Flat CSVs for the R QC pipeline, from a combine_blocks tree.
%
%   report = export_gaze_csv(derivedRoot)
%   report = export_gaze_csv(derivedRoot, 'rawRoot', localRoot)
%
% Why this exists. combine_blocks already does the hard part: alignBlockGaze
% maps Tobii SystemTimeStamp onto PTB seconds and labels every sample with its
% trial and phase. But it writes -v7.3 (HDF5) MAT files, and the R side has no
% HDF5 reader -- analysis/R/io.R can currently only test that the gaze file
% exists. So gaze, AOI and stimulus identity never reach analysis at all.
%
% This writes the same information as CSV, which is the only format the R
% pipeline reads (see analysis/README.md "What it reads"):
%
%   <derived>/gaze_qc/<runId>_<domain>_gaze.csv   one row per sample
%   <derived>/gaze_qc/<runId>_<domain>_et.csv     one row per run: tracker metadata
%   <derived>/events/<runId>_events.csv           the event log, flattened
%   <derived>/aoi/<runId>_<domain>_aoi.csv        AOI rects and separation verdicts
%   <derived>/stimuli/<runId>_<domain>_stimuli_shown.csv  the resolved stimulus table
%   <derived>/plan/<runId>_<domain>_trial_plan.csv        the frozen auction plan
%
% The gaze column set is deliberately NOT every packed leaf. At 60 Hz a session
% is a few hundred thousand samples per run, and the QC questions -- did every
% trial get samples, were they valid, did the clock sync hold -- need position,
% validity, pupil and the trial/phase labels, not the full user-coordinate
% geometry. A complete per-leaf export for actual gaze analysis is a separate
% piece of work; this one is for quality control.
%
% Reads only. Nothing here modifies the raw or derived trees.

p = inputParser;
p.addParameter('rawRoot', '', @(x) ischar(x) || isstring(x));
p.addParameter('includePartial', false, @islogical);
p.parse(varargin{:});
rawRoot = char(p.Results.rawRoot);

derivedRoot = char(derivedRoot);
assert(isfolder(derivedRoot), 'hw:exportGaze:root', ...
    'Derived root is missing: %s. Run scripts/combine_blocks.m first.', derivedRoot);

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'experiment'));

report = struct('runId', {}, 'domain', {}, 'samples', {}, 'outputs', {});

roots = {derivedRoot};
if p.Results.includePartial && isfolder(fullfile(derivedRoot, 'partial'))
    roots{end+1} = fullfile(derivedRoot, 'partial');
end

for r = 1:numel(roots)
    base = roots{r};
    files = dir(fullfile(base, 'gaze', '*_gaze.mat'));
    for k = 1:numel(files)
    % One run per iteration, and one run's failure stays that run's failure:
    % the catch at the bottom of this loop prints it and moves on. Without it,
    % one malformed run aborted the WHOLE sweep -- and since every later
    % session re-sweeps the same tree, it aborted every later export too.
    try
        s = load(fullfile(files(k).folder, files(k).name), 'gazeExport');
        if ~isfield(s, 'gazeExport'), continue; end
        g = s.gazeExport;
        runId = char(g.logicalRunId);
        domain = char(g.domain);

        [samples, meta] = flattenBlocks(g);
        written = {};

        if ~isempty(samples)
            out = fullfile(base, 'gaze_qc', [runId '_' domain '_gaze.csv']);
            writeCsv(out, samples);
            written{end+1} = out; %#ok<AGROW>
        end

        % Tracker metadata lives in the per-block metadata inside the task MAT.
        etRow = eyeTrackingRow(base, runId, domain);
        if ~isempty(etRow)
            out = fullfile(base, 'gaze_qc', [runId '_' domain '_et.csv']);
            writeCsv(out, etRow);
            written{end+1} = out; %#ok<AGROW>
        end

        aoiTable = aoiRows(base, runId, domain);
        if ~isempty(aoiTable)
            out = fullfile(base, 'aoi', [runId '_' domain '_aoi.csv']);
            writeCsv(out, aoiTable);
            written{end+1} = out; %#ok<AGROW>
        end

        stimTable = stimuliShownRows(base, runId, domain);
        if ~isempty(stimTable)
            out = fullfile(base, 'stimuli', [runId '_' domain '_stimuli_shown.csv']);
            writeCsv(out, stimTable);
            written{end+1} = out; %#ok<AGROW>
        end

        if ~isempty(rawRoot)
            planTable = trialPlanRows(rawRoot, runId, domain);
            if ~isempty(planTable)
                out = fullfile(base, 'plan', [runId '_' domain '_trial_plan.csv']);
                writeCsv(out, planTable);
                written{end+1} = out; %#ok<AGROW>
            end
        end

        report(end+1) = struct('runId', runId, 'domain', domain, ...
            'samples', height(samples), 'outputs', {written}); %#ok<AGROW>
        fprintf('%s/%s: %d samples, %d file(s)\n', runId, domain, ...
            height(samples), numel(written));
        if ~isempty(meta.warning)
            fprintf('  NOTE: %s\n', meta.warning);
        end
    catch runME
        fprintf(2, '%s: EXPORT FAILED: %s (%s)\n', ...
            files(k).name, runME.message, runME.identifier);
    end
    end

    % The event log is per run, not per domain.
    eventFiles = dir(fullfile(base, 'events', '*_events.mat'));
    for k = 1:numel(eventFiles)
        s = load(fullfile(eventFiles(k).folder, eventFiles(k).name), 'events');
        if ~isfield(s, 'events') || isempty(s.events), continue; end
        name = eventFiles(k).name;
        runId = name(1:end-numel('_events.mat'));
        writeCsv(fullfile(base, 'events', [runId '_events.csv']), s.events);
    end
end

if isempty(report)
    warning('hw:exportGaze:nothing', ...
        'No gaze MAT files under %s/gaze. Was combine_blocks run against this root?', ...
        derivedRoot);
end

end

% ---------------------------------------------------------------------------

function [out, meta] = flattenBlocks(g)
%FLATTENBLOCKS One table of QC columns over every block of a run.
out = table();
meta = struct('warning', '');
blocks = g.blocks;
parts = cell(1, numel(blocks));

for b = 1:numel(blocks)
    gz = blocks{b};
    if ~isfield(gz, 'association') || isempty(gz.association), continue; end
    a = gz.association;
    n = height(a);
    if n == 0, continue; end

    packed = gz;
    if isfield(gz, 'samples'), packed = gz.samples; end

    T = table();
    % The association table already carries the export keys stamped on by
    % combine_blocks.m:113-117, so copy rather than reconstruct them.
    for f = {'participant','session','run_id','task','domain','run_kind', ...
             'block','attempt_id','complete','checkpoint_schema'}
        name = f{1};
        if ismember(name, a.Properties.VariableNames)
            T.(name) = a.(name);
        end
    end
    T.sampleIndex = a.sampleIndex;
    T.ptbTime = a.ptbTime;
    T.trial = a.trial;
    T.phase = string(a.phase);

    T.DeviceTimeStamp = leafColumn(packed, {'DeviceTimeStamp'}, n, 1);
    T.SystemTimeStamp = leafColumn(packed, {'SystemTimeStamp'}, n, 1);

    % Normalised display-area position, averaged over whichever eyes are valid
    % -- the same rule gazeToPixels.m:17-26 applies, in normalised units. The
    % validity accessor cannot be reused directly here because it reads sample
    % structs and this reads packed columns, so the two SDK spellings of
    % Validity are handled by matching either leaf path (see leafColumn).
    [lx, ly, lv] = eyeColumns(packed, 'LeftEye', n);
    [rx, ry, rv] = eyeColumns(packed, 'RightEye', n);

    both = lv & rv;
    x = nan(n, 1); y = nan(n, 1);
    x(both) = (lx(both) + rx(both)) / 2;
    y(both) = (ly(both) + ry(both)) / 2;
    onlyL = lv & ~rv; x(onlyL) = lx(onlyL); y(onlyL) = ly(onlyL);
    onlyR = rv & ~lv; x(onlyR) = rx(onlyR); y(onlyR) = ry(onlyR);

    T.gaze_x_norm = x;
    T.gaze_y_norm = y;
    T.gaze_validity = double(lv | rv);

    lp = leafColumn(packed, {'LeftEye','Pupil','Diameter'}, n, 1);
    rp = leafColumn(packed, {'RightEye','Pupil','Diameter'}, n, 1);
    lpv = validityColumn(packed, {'LeftEye','Pupil','Validity'}, n);
    rpv = validityColumn(packed, {'RightEye','Pupil','Validity'}, n);
    pupil = nan(n, 1);
    bp = lpv & rpv; pupil(bp) = (lp(bp) + rp(bp)) / 2;
    pupil(lpv & ~rpv) = lp(lpv & ~rpv);
    pupil(rpv & ~lpv) = rp(rpv & ~lpv);
    T.pupil_diameter = pupil;
    T.pupil_validity = double(lpv | rpv);

    if ~ismember('block', T.Properties.VariableNames)
        T.block = repmat(b, n, 1);
    end

    parts{b} = T;
end

parts = parts(~cellfun(@isempty, parts));
if isempty(parts), return; end
out = utils.stackTables(parts);

if any(out.phase == "unknown")
    meta.warning = sprintf(['%d of %d samples have phase=unknown: clockSync was ' ...
        'invalid or non-monotonic for that block, so they cannot be assigned ' ...
        'to a trial (alignBlockGaze.m:7-18).'], ...
        sum(out.phase == "unknown"), height(out));
end
end

function [x, y, valid] = eyeColumns(packed, eye, n)
%EYECOLUMNS Normalised x/y and a validity flag for one eye.
pos = leafColumn(packed, {eye,'GazePoint','OnDisplayArea'}, n, 2);
x = pos(:,1);
y = pos(:,2);
valid = validityColumn(packed, {eye,'GazePoint','Validity'}, n) & ...
    ~isnan(x) & ~isnan(y);
end

function v = validityColumn(packed, path, n)
%VALIDITYCOLUMN Validity as a logical, for either SDK spelling.
col = leafColumn(packed, path, n, 1);
v = ~isnan(col) & double(col) == 1;
end

function col = leafColumn(packed, path, n, width)
%LEAFCOLUMN One packed leaf as doubles, or NaN when the leaf is absent.
%
% Matches `path` exactly, then `[path 'value']`. The real SDK wraps Validity in
% an object exposing .value, which gazeCodec's describe() recurses into, so the
% packed path gains a trailing 'value' element; FakeGazeTracker stores a plain
% numeric and does not. Accepting both is what makes this work against real rig
% data and the test fixture alike -- the same divergence that hid the
% gazeToPixels bug fixed in d1cd402.
col = nan(n, width);
if ~isfield(packed, 'leafSchema') || ~isfield(packed, 'columns'), return; end
ix = findLeaf(packed.leafSchema, path);
if isempty(ix)
    ix = findLeaf(packed.leafSchema, [path {'value'}]);
end
if isempty(ix), return; end
raw = double(packed.columns{ix});
if size(raw, 1) ~= n, return; end
m = min(width, size(raw, 2));
col(:, 1:m) = raw(:, 1:m);
end

function ix = findLeaf(schema, path)
ix = [];
for k = 1:numel(schema)
    if isequal(schema(k).path, path), ix = k; return; end
end
end

% ---- metadata pulled from the task MAT ------------------------------------

function meta = loadMetadata(base, runId, domain)
%LOADMETADATA The per-block metadata cell written by combine_blocks.m:64.
meta = {};
for taskDir = {'auction','cont_dc','pref'}
    f = fullfile(base, taskDir{1}, [runId '.mat']);
    if ~isfile(f), continue; end
    s = load(f, 'dataMat');
    if ~isfield(s, 'dataMat') || ~isfield(s.dataMat, 'domainData'), continue; end
    dd = s.dataMat.domainData;
    if ~isfield(dd, domain) || ~isfield(dd.(domain), 'metadata'), continue; end
    meta = dd.(domain).metadata;
    return
end
end

function T = eyeTrackingRow(base, runId, domain)
%EYETRACKINGROW Requested vs actual sample rate, and the calibration flag.
%
% cfg.et.sampleRateHz is only ever REQUESTED: setupEyeTracker.m:70 reads the
% rate back from the tracker and nothing pushes it, so a tracker running at
% another rate is silent unless the two are compared. That comparison is the
% point of this file.
T = table();
meta = loadMetadata(base, runId, domain);
for k = 1:numel(meta)
    m = meta{k};
    if ~isstruct(m) || ~isfield(m, 'eyeTracking'), continue; end
    et = m.eyeTracking;
    T = table(string(runId), string(domain), 'VariableNames', {'run_id','domain'});
    T.requestedSampleRateHz = pick(et, 'sampleRateHz', NaN);
    T.actualSampleRateHz = pick(et, 'actualSampleRateHz', NaN);
    T.etEnabled = double(pick(et, 'enabled', NaN));
    % calibrated reaches disk only from preference_task.m:77; the other two
    % tasks omit it, so this is NaN for them rather than a silent false.
    T.calibrated = double(pick(et, 'calibrated', NaN));
    return
end
end

function T = aoiRows(base, runId, domain)
%AOIROWS One row per AOI, with the checkAOIs separation verdict when present.
T = table();
meta = loadMetadata(base, runId, domain);
rows = {};
for k = 1:numel(meta)
    m = meta{k};
    if ~isstruct(m), continue; end
    rows = [rows aoiFromStruct(m, runId, domain, k)]; %#ok<AGROW>
end
if isempty(rows), return; end
T = utils.stackTables(rows);
end

function rows = aoiFromStruct(m, runId, domain, blockOrdinal)
rows = {};
names = {};
rects = [];
verdicts = strings(0,1);

if isfield(m, 'aoiNames') && isfield(m, 'aoiRects')
    names = cellstr(string(m.aoiNames));
    rects = m.aoiRects;
elseif isfield(m, 'aoiLayouts')
    L = m.aoiLayouts;
    for j = 1:numel(L)
        if ~isstruct(L(j)) || ~isfield(L(j), 'names') || ~isfield(L(j), 'rects')
            continue
        end
        nm = cellstr(string(L(j).names));
        names = [names nm(:)']; %#ok<AGROW>
        rects = [rects; L(j).rects]; %#ok<AGROW>
    end
end
if isempty(names) || isempty(rects), return; end
if size(rects, 1) ~= numel(names), return; end

if isfield(m, 'aoiReport') && isstruct(m.aoiReport) && ...
        isfield(m.aoiReport, 'verdict')
    v = string(m.aoiReport.verdict);
    if numel(v) == numel(names), verdicts = v(:); end
end
if isempty(verdicts), verdicts = repmat("", numel(names), 1); end

T = table(repmat(string(runId), numel(names), 1), ...
    repmat(string(domain), numel(names), 1), ...
    repmat(blockOrdinal, numel(names), 1), ...
    string(names(:)), verdicts, ...
    rects(:,1), rects(:,2), rects(:,3), rects(:,4), ...
    'VariableNames', {'run_id','domain','block','aoiName','verdict', ...
                      'left','top','right','bottom'});
rows = {T};
end

function T = stimuliShownRows(base, runId, domain)
%STIMULISHOWNROWS The participant's resolved stimulus table.
%
% This is what makes a stimulus index mean something. For houses the index is
% already a stable row number into experiment/stimuli/house_stimuli.csv --
% fitToWindow.m:12-13 keeps every row with a usable value and applyWindow.m:19
% indexes with it, and no listPrice is missing. For jobs the table is cut to
% the participant's top industries first, so only this export resolves them.
T = table();
meta = loadMetadata(base, runId, domain);
for k = 1:numel(meta)
    m = meta{k};
    if ~isstruct(m) || ~isfield(m, 'stimuliShown'), continue; end
    S = m.stimuliShown;
    if ~istable(S) || isempty(S), continue; end
    S.stimIdx = (1:height(S))';
    S.run_id = repmat(string(runId), height(S), 1);
    S.domain = repmat(string(domain), height(S), 1);
    T = S;
    return
end
end

function T = trialPlanRows(rawRoot, runId, domain)
%TRIALPLANROWS The frozen auction plan, one row per trial x presented option.
%
% The auction CSV records only bidStimIdx and rejectedStimIdx -- the option bid
% on and the ones rejected -- never the full twelve presented. utils.frozenPlan
% freezes the whole plan, so this is the only route to within-trial duplicate
% detection and real exposure counts.
%
% Note for analysis: these are the PLANNED presentations. Retirement of won
% options happens at runtime (auction_task.m:374-379), so a won stimulus can
% legitimately still appear in a later trial's planned set and simply be
% skipped. Do not read a reappearance here as a retirement failure.
T = table();
f = fullfile(rawRoot, 'runs', runId, [domain '-plan.mat']);
if ~isfile(f), return; end
s = load(f, 'frozen');
if ~isfield(s, 'frozen') || ~isfield(s.frozen, 'plan'), return; end
plan = s.frozen.plan;
% Every task freezes its own shape into <domain>-plan.mat. Only the auction
% plan has per-trial stimIdx rows; the preference plan is a scalar struct of
% photo rows and pairs (buildPhotoPreferencePlan), and contdc freezes no plan
% at all. Anything that is not the auction shape simply has no plan CSV.
if ~isstruct(plan) || ~isfield(plan, 'stimIdx'), return; end
rows = cell(1, numel(plan));
for t = 1:numel(plan)
    idx = plan(t).stimIdx(:);
    rep = nan(numel(idx), 1);
    if isfield(plan(t), 'repIdx') && numel(plan(t).repIdx) == numel(idx)
        rep = double(plan(t).repIdx(:));
    end
    rows{t} = table(repmat(string(runId), numel(idx), 1), ...
        repmat(string(domain), numel(idx), 1), ...
        repmat(double(plan(t).trial), numel(idx), 1), ...
        repmat(string(plan(t).competition), numel(idx), 1), ...
        repmat(double(plan(t).block), numel(idx), 1), ...
        repmat(double(plan(t).blockPos), numel(idx), 1), ...
        double(idx), rep, ...
        'VariableNames', {'run_id','domain','trial','competition', ...
                          'block','blockPos','stimIdx','repIdx'});
end
rows = rows(~cellfun(@isempty, rows));
if isempty(rows), return; end
T = utils.stackTables(rows);
end

function v = pick(s, name, default)
v = default;
if isstruct(s) && isfield(s, name) && isscalar(s.(name)), v = double(s.(name)); end
end

function writeCsv(file, T)
%WRITECSV Atomic write, matching combine_blocks.m:121-124.
parent = fileparts(file);
if ~isfolder(parent), mkdir(parent); end
tmp = [file '.partial'];
writetable(T, tmp, 'FileType', 'text');
movefile(tmp, file, 'f');
end
