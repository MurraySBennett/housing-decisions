function destDir = mirrorDiagnostics(cfg, run, extraFiles)
%UTILS.MIRRORDIAGNOSTICS  Copy crash diagnostics to the share, after the fact.
%
%   destDir = utils.mirrorDiagnostics(cfg, run)
%   destDir = utils.mirrorDiagnostics(cfg, run, {extraFile1, extraFile2})
%
% Copies this run's progress log, plus any extra files named by the caller
% (normally the crash .mat just written), to
%   <cfg.paths.shareData>/<cfg.diagnostics.shareSubdir>/<host>/<runId>/
% so a rig crash can be read without visiting the rig.
%
% CALL THIS ONLY FROM A CRASH HANDLER, after cleanup and after the local dump
% has been written. config.m's rule is that storage never probes the share
% during capture; this runs once, after the session is already dead, so trial
% timing cannot be affected. The per-trial log stays on local disk (see
% progressLog.m) -- this copies the finished file, it does not relocate it.
%
% NEVER THROWS. Diagnostics must not replace the experiment's original error,
% which is the same contract progressLog.m holds. On any failure it prints a
% note and returns ''. An unreachable UNC path is the expected failure and is
% checked cheaply, before anything slow is attempted.

destDir = '';
if nargin < 3, extraFiles = {}; end

try
    if ~isfield(cfg, 'diagnostics') || ~cfg.diagnostics.mirrorToShare
        return;  % silenced deliberately; say nothing
    end

    shareRoot = cfg.paths.shareData;
    % isfolder on an unmounted UNC path returns false quickly. Checking it
    % first is what keeps a dead share from adding a timeout to a crash the
    % operator is already waiting on.
    if ~isfolder(shareRoot)
        fprintf(2, 'Crash diagnostics not mirrored: share not reachable (%s).\n', shareRoot);
        return;
    end

    runId = 'unknown-run';
    if isstruct(run) && isfield(run, 'runId') && ~isempty(run.runId)
        runId = char(run.runId);
    end

    subdir = 'Diagnostics';
    if isfield(cfg, 'diagnostics') && isfield(cfg.diagnostics, 'shareSubdir')
        subdir = char(cfg.diagnostics.shareSubdir);
    end

    % Host in the path because two rigs crashing on the same participant would
    % otherwise overwrite each other's evidence.
    candidate = fullfile(shareRoot, subdir, hostname(), runId);
    if ~isfolder(candidate) && ~mkdir(candidate)
        fprintf(2, 'Crash diagnostics not mirrored: could not create %s\n', candidate);
        return;
    end

    sources = {};
    logFile = fullfile(tempdir, 'housing-wages-logs', [runId '.log']);
    if isfile(logFile), sources{end+1} = logFile; end
    for k = 1:numel(extraFiles)
        f = extraFiles{k};
        if ~isempty(f) && ischar(f) && isfile(f), sources{end+1} = f; end %#ok<AGROW>
    end

    if isempty(sources)
        fprintf(2, 'Crash diagnostics not mirrored: nothing found to copy for %s.\n', runId);
        return;
    end

    % Copy each file independently. One unreadable file must not stop the
    % others -- the log and the dump carry different halves of the evidence.
    copied = 0;
    for k = 1:numel(sources)
        try
            copyfile(sources{k}, candidate);
            copied = copied + 1;
        catch copyME
            fprintf(2, 'Could not mirror %s: %s\n', sources{k}, copyME.message);
        end
    end

    if copied > 0
        destDir = candidate;
        fprintf(2, '\nCrash diagnostics mirrored (%d file(s)) to:\n  %s\n', copied, destDir);
    end

catch ME
    fprintf(2, 'Crash diagnostics not mirrored: %s (%s)\n', ME.message, ME.identifier);
end
end


function h = hostname()
h = getenv('COMPUTERNAME');
if isempty(h), h = getenv('HOSTNAME'); end
if isempty(h), h = 'unknown-host'; end
h = regexprep(char(h), '[^A-Za-z0-9_-]', '_');
end
