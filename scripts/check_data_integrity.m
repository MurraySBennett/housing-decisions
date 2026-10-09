function reportFile = check_data_integrity(dataRoot)
%CHECK_DATA_INTEGRITY  Did a completed session actually collect good data?
%
%   check_data_integrity
%   check_data_integrity('C:\...\housing-wages\Data\participant')
%
% READ-ONLY. Opens nothing but .mat files and writes one text report. Needs no
% PTB, no Tobii SDK, and no eye tracker -- it reads the packed gaze columns
% directly rather than reconstructing SDK objects, so it runs on any machine
% that can see the data.
%
% "Uninterrupted" is not "fine". A session can run end to end and still have
% collected nothing usable, in ways nothing on screen would show:
%   - the tracker connected but marked every sample invalid
%   - the effective sample rate collapsed well below the configured 60 Hz
%   - a response widget returned one constant value for a whole block
%   - a block committed behaviour but never its gaze
% Those are what this checks. Every check is independently guarded, so one
% unreadable file degrades that line instead of aborting the report.
%
% Read the FLAGs. Absence of flags is not proof of quality, but any flag is a
% reason to stop and look before running more participants.

if nargin < 1 || isempty(dataRoot)
    dataRoot = fullfile(getenv('LOCALAPPDATA'), 'housing-wages', 'Data', 'participant');
end
dataRoot = char(dataRoot);

reportFile = resolveReport();
[fid, msg] = fopen(reportFile, 'w');
if fid < 0, error('hw:integrity:open', 'Could not open %s: %s', reportFile, msg); end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>

nFlag = 0;

section(fid, 'CONTEXT');
emit(fid, 'Collected   : %s', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
emit(fid, 'Computer    : %s', hostname());
emit(fid, 'MATLAB      : %s', version('-release'));
emit(fid, 'Data root   : %s', dataRoot);
if ~isfolder(dataRoot)
    emit(fid, 'FLAG: data root does not exist. Nothing to check.');
    finish(fid, reportFile, 1); return;
end

% --- Manifests: what the session itself believes happened ----------------
section(fid, 'SESSIONS (manifest status per run)');
try
    mans = dir(fullfile(dataRoot, 'sessions', '*_manifest.mat'));
    if isempty(mans)
        emit(fid, 'FLAG: no manifest found under %s', fullfile(dataRoot, 'sessions'));
        nFlag = nFlag + 1;
    end
    for m = 1:numel(mans)
        emit(fid, '');
        emit(fid, '%s', mans(m).name);
        S = load(fullfile(mans(m).folder, mans(m).name));
        names = fieldnames(S); mf = S.(names{1});
        if ~isfield(mf, 'runs') || isempty(mf.runs)
            emit(fid, '  FLAG: manifest has no runs.'); nFlag = nFlag + 1; continue;
        end
        for r = 1:numel(mf.runs)
            run = mf.runs(r);
            status = char(fieldOr(run, 'status', '?'));
            emit(fid, '  run %d: task=%-8s status=%-9s started=%-19s finished=%-19s', ...
                r, char(fieldOr(run, 'task', '?')), status, ...
                char(fieldOr(run, 'startedAt', '')), char(fieldOr(run, 'finishedAt', '')));
            if ~strcmpi(status, 'complete')
                emit(fid, '    FLAG: status is not complete.'); nFlag = nFlag + 1;
            end
        end
    end
catch ME
    emit(fid, 'COULD NOT READ MANIFESTS: %s (%s)', ME.message, ME.identifier);
end

% --- Blocks: completeness, then gaze health, then response health -------
section(fid, 'BLOCKS');
try
    runDirs = dir(fullfile(dataRoot, 'blocks', '*'));
    runDirs = runDirs([runDirs.isdir] & ~ismember({runDirs.name}, {'.', '..'}));
    if isempty(runDirs)
        emit(fid, 'FLAG: no block directories under %s', fullfile(dataRoot, 'blocks'));
        nFlag = nFlag + 1;
    end
    for r = 1:numel(runDirs)
        runPath = fullfile(runDirs(r).folder, runDirs(r).name);
        emit(fid, '');
        emit(fid, '=== %s ===', runDirs(r).name);
        blocks = dir(fullfile(runPath, 'block-*'));
        blocks = blocks([blocks.isdir]);
        if isempty(blocks)
            emit(fid, '  FLAG: no blocks.'); nFlag = nFlag + 1; continue;
        end
        releases = {};
        for b = 1:numel(blocks)
            blockPath = fullfile(blocks(b).folder, blocks(b).name);
            attempts = dir(fullfile(blockPath, 'attempt-*'));
            attempts = attempts([attempts.isdir]);
            committed = {};
            for a = 1:numel(attempts)
                if isfile(fullfile(attempts(a).folder, attempts(a).name, 'receipt.mat'))
                    committed{end+1} = fullfile(attempts(a).folder, attempts(a).name); %#ok<AGROW>
                end
            end
            emit(fid, '  %s: %d attempt(s), %d committed', blocks(b).name, numel(attempts), numel(committed));
            if numel(attempts) > 1
                emit(fid, '    NOTE: more than one attempt -- a block was retried or resumed.');
            end
            if isempty(committed)
                emit(fid, '    FLAG: no attempt has receipt.mat. This block never committed.');
                nFlag = nFlag + 1;
                continue;
            end
            dirPath = committed{end};
            [nf, rel] = inspectBlock(fid, dirPath);
            nFlag = nFlag + nf;
            if ~isempty(rel), releases{end+1} = rel; end %#ok<AGROW>
        end
        % 882cf9a stamps the release per block; mixing them inside one
        % participant is an analysis hazard the checkpoint system will not stop.
        releases = releases(~cellfun('isempty', releases));
        if numel(unique(releases)) > 1
            emit(fid, '  FLAG: blocks in this run were recorded under DIFFERENT MATLAB releases: %s', ...
                strjoin(unique(releases), ', '));
            nFlag = nFlag + 1;
        end
    end
catch ME
    emit(fid, 'COULD NOT WALK BLOCKS: %s (%s)', ME.message, ME.identifier);
end

% --- Emergency folders: gaze preserved but never committed --------------
section(fid, 'EMERGENCY GAZE (preserved but NOT committed)');
try
    em = dir(fullfile(dataRoot, 'emergency', '*'));
    em = em([em.isdir] & ~ismember({em.name}, {'.', '..'}));
    if isempty(em)
        emit(fid, 'None. No block had to dump its gaze to the emergency path.');
    else
        emit(fid, 'FLAG: %d emergency folder(s). Each is a block whose gaze was', numel(em));
        emit(fid, 'preserved after a failure and never written to gaze.mat. Recoverable,');
        emit(fid, 'but NOT part of the committed dataset until deliberately recovered.');
        nFlag = nFlag + 1;
        for k = 1:numel(em)
            chunks = dir(fullfile(em(k).folder, em(k).name, 'chunk-*.mat'));
            emit(fid, '  %s  (%d chunk file(s))', em(k).name, numel(chunks));
        end
    end
catch ME
    emit(fid, 'COULD NOT LIST: %s (%s)', ME.message, ME.identifier);
end

finish(fid, reportFile, nFlag);
end


% =========================================================================

function [nFlag, release] = inspectBlock(fid, dirPath)
%INSPECTBLOCK Gaze health and response health for one committed attempt.
nFlag = 0; release = '';

% ---- gaze -------------------------------------------------------------
try
    G = load(fullfile(dirPath, 'gaze.mat'));
    packed = G.gaze.packed;
    n = packed.sampleCount;
    emit(fid, '    gaze: %d samples', n);
    if n == 0
        emit(fid, '    FLAG: zero gaze samples in a committed block.');
        nFlag = nFlag + 1;
    else
        % Effective rate from the SDK's own clock. Column is microseconds.
        ti = findLeaves(packed.leafSchema, 'system.?time.?stamp');
        if ~isempty(ti)
            ts = double(packed.columns{ti(1)}(:, 1));
            secs = (max(ts) - min(ts)) / 1e6;
            if secs > 0
                hz = n / secs;
                emit(fid, '    gaze: %.1f s span, effective %.1f Hz', secs, hz);
                % config.m:220 sets 60 Hz. A large shortfall means dropped
                % samples, which no error anywhere would have reported.
                if hz < 45 || hz > 75
                    emit(fid, '    FLAG: effective rate is far from the configured 60 Hz.');
                    nFlag = nFlag + 1;
                end
            end
        else
            emit(fid, '    NOTE: no timestamp leaf found; cannot compute sample rate.');
        end

        % Validity. This is the check that catches "it ran fine and tracked
        % nothing" -- the single most likely silent failure in this study.
        vi = findLeaves(packed.leafSchema, 'valid');
        if isempty(vi)
            emit(fid, '    NOTE: no validity leaf found; cannot assess tracking quality.');
        else
            worst = 1;
            for k = vi
                col = packed.columns{k};
                frac = mean(double(col(:)) ~= 0);
                emit(fid, '    valid %-46s %5.1f%%', strjoin(packed.leafSchema(k).path, '.'), 100 * frac);
                worst = min(worst, frac);
            end
            if worst < 0.5
                emit(fid, '    FLAG: a validity channel is below 50%%. Tracking was poor or absent.');
                nFlag = nFlag + 1;
            end
        end
    end
catch ME
    emit(fid, '    FLAG: could not read gaze.mat: %s (%s)', ME.message, ME.identifier);
    nFlag = nFlag + 1;
end

% ---- behaviour --------------------------------------------------------
try
    B = load(fullfile(dirPath, 'behavior.mat'));
    beh = B.behavior;
    trials = fieldOr(beh, 'trials', []);
    emit(fid, '    trials: %d', numel(trials));
    if isempty(trials)
        emit(fid, '    FLAG: committed block with no trials.'); nFlag = nFlag + 1;
    end

    expected = fieldOr(beh, 'expectedSamples', NaN);
    if ~isnan(expected)
        emit(fid, '    expectedSamples recorded: %d', expected);
    end

    md = fieldOr(beh, 'metadata', struct());
    release = char(fieldOr(md, 'matlabRelease', ''));

    % Degenerate responses. This is the 0.841-repeated-27-times pattern seen
    % in the 2026-10-09 test log: a widget that returns one constant value
    % produces a complete, uninterrupted, worthless block.
    if isstruct(trials) && numel(trials) >= 10
        fn = fieldnames(trials);
        for f = 1:numel(fn)
            try
                vals = [trials.(fn{f})];
                if ~isnumeric(vals) || numel(vals) ~= numel(trials), continue; end
                good = vals(~isnan(vals));
                if isempty(good)
                    emit(fid, '    FLAG: field "%s" is all NaN across %d trials.', fn{f}, numel(trials));
                    nFlag = nFlag + 1; continue;
                end
                u = numel(unique(good));
                nanFrac = 1 - numel(good) / numel(vals);
                if u <= 2
                    emit(fid, '    FLAG: field "%s" takes only %d distinct value(s) over %d trials (e.g. %g).', ...
                        fn{f}, u, numel(trials), good(1));
                    nFlag = nFlag + 1;
                end
                if nanFrac > 0.2
                    emit(fid, '    FLAG: field "%s" is %.0f%% NaN.', fn{f}, 100 * nanFrac);
                    nFlag = nFlag + 1;
                end
            catch
                % Non-scalar or non-concatenable field; not a degeneracy signal.
            end
        end
    end
catch ME
    emit(fid, '    FLAG: could not read behavior.mat: %s (%s)', ME.message, ME.identifier);
    nFlag = nFlag + 1;
end
end


function idx = findLeaves(leafSchema, pattern)
idx = [];
for k = 1:numel(leafSchema)
    joined = strjoin(leafSchema(k).path, '.');
    if ~isempty(regexpi(joined, pattern, 'once')), idx(end+1) = k; end %#ok<AGROW>
end
end


function finish(fid, reportFile, nFlag)
section(fid, 'VERDICT');
if nFlag == 0
    emit(fid, 'No flags raised. Note what this does NOT prove: it checks');
    emit(fid, 'completeness, sample rate, validity and response variability, not');
    emit(fid, 'calibration accuracy or whether the participant understood the task.');
else
    emit(fid, '%d FLAG(S) RAISED. Search this file for "FLAG:" and resolve each', nFlag);
    emit(fid, 'before running more participants.');
end
fprintf('\n========================================================\n');
if nFlag == 0
    fprintf('  NO FLAGS RAISED\n');
else
    fprintf('  %d FLAG(S) RAISED -- read the report\n', nFlag);
end
fprintf('  SEND THIS FILE:\n    %s\n', reportFile);
fprintf('========================================================\n\n');
end


function reportFile = resolveReport()
% Share first so it can be read without touching the rig; tempdir second.
% Same order as rig_checks.m:89.
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
name = ['integrity_' hostname() '_' stamp '.txt'];
candidates = { ...
    fullfile('\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages', name), ...
    fullfile(tempdir, name)};
for k = 1:numel(candidates)
    if ~isfolder(fileparts(candidates{k})), continue; end
    fid = fopen(candidates{k}, 'a');
    if fid >= 0, fclose(fid); reportFile = candidates{k}; return; end
end
error('hw:integrity:noWritablePath', 'Could not write to the share or to %s.', tempdir);
end


function v = fieldOr(s, name, default)
if isstruct(s) && isfield(s, name), v = s.(name); else, v = default; end
end


function h = hostname()
h = getenv('COMPUTERNAME');
if isempty(h), h = getenv('HOSTNAME'); end
if isempty(h), h = 'unknown-host'; end
h = regexprep(char(h), '[^A-Za-z0-9_-]', '_');
end


function section(fid, title)
fprintf(fid, '\n########################################################\n');
fprintf(fid, '## %s\n', title);
fprintf(fid, '########################################################\n');
end


function emit(fid, fmt, varargin)
fprintf(fid, [fmt '\n'], varargin{:});
end
