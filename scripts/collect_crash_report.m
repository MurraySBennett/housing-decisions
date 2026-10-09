function reportFile = collect_crash_report(nSessions)
%COLLECT_CRASH_REPORT  Bundle a rig crash into one text file to send off-rig.
%
%   collect_crash_report       % newest session
%   collect_crash_report(3)    % newest 3 sessions
%
% Run it in MATLAB on the rig, from the folder the RA already opens (the repo
% root works, so does anywhere). Needs no PTB, no tracker, no eye-tracking SDK,
% and does not touch participant data. It only reads.
%
% Why this exists: a crash leaves its error in two places on local disk -- the
% per-trial progress log (run_battery.m:113, written first in the catch) and the
% crash .mat holding the live ME (run_battery.m:131). The log is plain text and
% can just be emailed; the .mat cannot, and getReport on the saved ME is the
% only way to see the stack and the cause chain. This collects both, plus the
% commit the rig actually ran, into one file.
%
% Every section is guarded: a missing or unreadable piece prints a note and the
% collection continues. A partial report is worth more than no report.

if nargin < 1 || isempty(nSessions), nSessions = 1; end

reportFile = resolveReport();
if isempty(reportFile)
    error('hw:collectCrash:noWritablePath', ...
        'Could not write to the share or to %s.', tempdir);
end

[fid, msg] = fopen(reportFile, 'w');
if fid < 0
    error('hw:collectCrash:open', 'Could not open %s: %s', reportFile, msg);
end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>

root = fileparts(fileparts(mfilename('fullpath')));
dataRoot = fullfile(getenv('LOCALAPPDATA'), 'housing-wages', 'Data');

section(fid, 'WHEN AND WHERE');
emit(fid, 'Collected    : %s', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
emit(fid, 'Computer     : %s', hostname());
emit(fid, 'MATLAB       : %s (%s)', version('-release'), version);
emit(fid, 'Repo root    : %s', root);
emit(fid, 'Data root    : %s', dataRoot);
emit(fid, 'Log root     : %s', fullfile(tempdir, 'housing-wages-logs'));

% The commit matters as much as the error: a report against an unknown tree
% cannot be matched to a line number.
section(fid, 'WHICH COMMIT THE RIG RAN');
runGit(fid, root, 'log -1 --format=%H%n%ci%n%s');
emit(fid, '--- uncommitted local changes (empty means clean) ---');
runGit(fid, root, 'status --porcelain');

section(fid, 'PROGRESS LOGS (newest first)');
logs = sortedDir(fullfile(tempdir, 'housing-wages-logs', '*.log'));
if isempty(logs)
    emit(fid, 'NONE FOUND. Either no session has run on this machine, or tempdir');
    emit(fid, 'differs from the one the session used.');
else
    for k = 1:numel(logs)
        emit(fid, '%d. %s  (%s, %d bytes)', k, logs(k).name, ...
            datestr(logs(k).datenum, 'yyyy-mm-dd HH:MM:SS'), logs(k).bytes); %#ok<DATST>
    end
    for k = 1:min(nSessions, numel(logs))
        dumpText(fid, fullfile(logs(k).folder, logs(k).name));
    end
end

% The .mat is the only copy of the stack and the cause chain.
section(fid, 'CRASH DUMPS (newest first)');
dumps = sortedDir(fullfile(dataRoot, '**', '*_crash.mat'));
if isempty(dumps)
    emit(fid, 'NONE FOUND under %s', dataRoot);
    emit(fid, 'A crash that got as far as run_battery''s handler should leave one;');
    emit(fid, 'none means it died earlier, or the dump write itself failed.');
else
    for k = 1:min(nSessions, numel(dumps))
        dumpError(fid, fullfile(dumps(k).folder, dumps(k).name));
    end
end

section(fid, 'MANIFESTS (run status per module)');
manifests = sortedDir(fullfile(dataRoot, '**', '*_manifest.mat'));
if isempty(manifests)
    emit(fid, 'NONE FOUND under %s', dataRoot);
else
    for k = 1:min(nSessions, numel(manifests))
        dumpManifest(fid, fullfile(manifests(k).folder, manifests(k).name));
    end
end

% Which blocks got a receipt tells us how far the save path got, independently
% of anything the error text claims.
section(fid, 'BLOCK CHECKPOINTS (which blocks committed)');
dumpBlocks(fid, fullfile(dataRoot, '**', 'receipt.mat'));

fprintf('\n');
fprintf('========================================================\n');
fprintf('  SEND THIS FILE:\n    %s\n', reportFile);
fprintf('========================================================\n');
fprintf('It is plain text. Attach it; do not retype it.\n\n');

end


% ---------------------------------------------------------------------------

function reportFile = resolveReport()
%RESOLVEREPORT Pick a writable path, share first, tempdir second.
% Same order as rig_checks.m:89 -- the share is preferred because it can be
% read without touching the rig at all.
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
name = ['crash-report_' hostname() '_' stamp '.txt'];
candidates = { ...
    fullfile('\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages', name), ...
    fullfile(tempdir, name)};
reportFile = '';
for k = 1:numel(candidates)
    parent = fileparts(candidates{k});
    if ~isfolder(parent), continue; end
    fid = fopen(candidates{k}, 'a');
    if fid >= 0
        fclose(fid);
        reportFile = candidates{k};
        return;
    end
end
end


function d = sortedDir(pattern)
%SORTEDDIR dir() newest first, directories dropped.
d = dir(pattern);
if isempty(d), return; end
d = d(~[d.isdir]);
if isempty(d), return; end
[~, order] = sort([d.datenum], 'descend');
d = d(order);
end


function dumpText(fid, path)
emit(fid, '');
emit(fid, '----- FULL TEXT: %s -----', path);
try
    txt = fileread(path);
    % Logs are one line per trial, so a long session is large. The error report
    % is appended last, so the tail is the part that matters.
    limit = 40000;
    if numel(txt) > limit
        emit(fid, '[truncated: showing last %d of %d characters]', limit, numel(txt));
        txt = txt(end-limit+1:end);
    end
    fprintf(fid, '%s\n', txt);
catch ME
    emit(fid, 'COULD NOT READ: %s (%s)', ME.message, ME.identifier);
end
emit(fid, '----- END %s -----', path);
end


function dumpError(fid, path)
emit(fid, '');
emit(fid, '----- CRASH DUMP: %s -----', path);
try
    S = load(path);
    if isfield(S, 'ME') && isa(S.ME, 'MException')
        emit(fid, 'identifier : %s', S.ME.identifier);
        emit(fid, 'message    : %s', S.ME.message);
        emit(fid, '');
        emit(fid, '--- extended report (stack) ---');
        fprintf(fid, '%s\n', getReport(S.ME, 'extended', 'hyperlinks', 'off'));
        % A wrapped error hides the real one; walk the chain.
        cause = S.ME.cause;
        for c = 1:numel(cause)
            emit(fid, '');
            emit(fid, '--- cause %d of %d ---', c, numel(cause));
            fprintf(fid, '%s\n', getReport(cause{c}, 'extended', 'hyperlinks', 'off'));
        end
    else
        emit(fid, 'No ME field. Variables present: %s', strjoin(fieldnames(S)', ', '));
    end
    if isfield(S, 'run')
        emit(fid, '');
        emit(fid, 'run.runId  : %s', fieldOr(S.run, 'runId', '(absent)'));
        emit(fid, 'run.task   : %s', fieldOr(S.run, 'task', '(absent)'));
        emit(fid, 'run.seed   : %s', num2str(fieldOr(S.run, 'seed', NaN)));
    end
catch ME
    emit(fid, 'COULD NOT LOAD: %s (%s)', ME.message, ME.identifier);
end
emit(fid, '----- END %s -----', path);
end


function dumpManifest(fid, path)
emit(fid, '');
emit(fid, '----- MANIFEST: %s -----', path);
try
    S = load(path);
    names = fieldnames(S);
    m = S.(names{1});
    if isfield(m, 'runs')
        for k = 1:numel(m.runs)
            r = m.runs(k);
            emit(fid, 'run %d: task=%-8s status=%-10s runId=%s', k, ...
                char(fieldOr(r, 'task', '?')), ...
                char(fieldOr(r, 'status', '?')), ...
                char(fieldOr(r, 'runId', '?')));
        end
    else
        emit(fid, 'No runs field. Fields: %s', strjoin(fieldnames(m)', ', '));
    end
catch ME
    emit(fid, 'COULD NOT LOAD: %s (%s)', ME.message, ME.identifier);
end
emit(fid, '----- END %s -----', path);
end


function dumpBlocks(fid, pattern)
try
    r = sortedDir(pattern);
    if isempty(r)
        emit(fid, 'NO receipt.mat anywhere. No block has committed on this machine.');
        return;
    end
    emit(fid, '%d committed block(s), newest 20 shown:', numel(r));
    for k = 1:min(20, numel(r))
        emit(fid, '  %s  %s', datestr(r(k).datenum, 'yyyy-mm-dd HH:MM:SS'), ... %#ok<DATST>
            strrep(r(k).folder, fullfile(getenv('LOCALAPPDATA'), 'housing-wages', 'Data'), '...'));
    end
catch ME
    emit(fid, 'COULD NOT LIST: %s (%s)', ME.message, ME.identifier);
end
end


function runGit(fid, root, argstr)
%RUNGIT Best effort; git may not be on the rig's PATH at all.
try
    [status, out] = system(sprintf('git -C "%s" %s', root, argstr));
    if status == 0
        fprintf(fid, '%s\n', strtrim(out));
    else
        emit(fid, 'git failed (status %d): %s', status, strtrim(out));
        emit(fid, 'If git is not installed, read .git\\HEAD and .git\\refs\\heads\\main by hand.');
    end
catch ME
    emit(fid, 'git unavailable: %s', ME.message);
end
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
fprintf(fid, '\n');
fprintf(fid, '########################################################\n');
fprintf(fid, '## %s\n', title);
fprintf(fid, '########################################################\n');
end


function emit(fid, fmt, varargin)
fprintf(fid, [fmt '\n'], varargin{:});
end
