function rig_checks(tobiiRoot)
%RIG_CHECKS Run every offline rig check, from wherever MATLAB happens to be.
%
%   rig_checks
%   rig_checks('C:\path\to\TobiiPro.SDK.Matlab_1.9.0.59')
%
%   Needs no participant, no tracker, no display and no Psychtoolbox. Reads
%   and prints; writes nothing outside the console.
%
%   This lives in experiment/ on purpose. The lab workflow opens MATLAB in
%   the clone's experiment/ folder, so a relative addpath('experiment',
%   'scripts') from there silently adds nothing and the scripts come back as
%   "Unrecognized function". This file finds the repository root from its own
%   location, so it works from any current folder as long as experiment/ is
%   on the path -- which the one-time rig setup already does.
%
%   Runs, in order:
%     1. check_syntax       -- does every .m file parse? (no SDK needed)
%     2. probe_sdk_types    -- the SDK facts the gaze codec depends on
%     3. verify_block_checkpoints -- the headless test suite
%
%   Paste the whole console output back. Stop at the first failure: a parse
%   error makes everything after it meaningless.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'experiment'), ...
        fullfile(root, 'scripts'), ...
        fullfile(root, 'scripts', 'tests'), ...
        fullfile(root, 'scripts', 'tests', 'fixtures'));

% Capture the whole transcript to a file. Reading this output off a photo of a
% phone screen loses exactly the detail that matters -- error identifiers,
% class names, stack lines -- so write it somewhere it can be opened as text.
% The share is preferred because Murray can read it without touching the rig.
logFile = resolveLog();
if ~isempty(logFile)
    diary(logFile);
    diaryCloser = onCleanup(@() diary('off')); %#ok<NASGU>
end

if nargin >= 1 && ~isempty(tobiiRoot)
    setenv('HW_TOBII_ROOT', char(tobiiRoot));
elseif isempty(getenv('HW_TOBII_ROOT'))
    % Same default as utils.config's shareRoot.
    setenv('HW_TOBII_ROOT', ...
        '\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\TobiiPro.SDK.Matlab_1.9.0.59');
end

fprintf('\n########################################################\n');
fprintf('Repository root : %s\n', root);
fprintf('Current folder  : %s\n', pwd);
fprintf('HW_TOBII_ROOT   : %s\n', getenv('HW_TOBII_ROOT'));
fprintf('MATLAB          : %s\n', version);
reportHead(root);
fprintf('########################################################\n');

fprintf('\n>>> 1/3  check_syntax\n');
nBad = check_syntax();
if nBad > 0
    fprintf(2, '\nSTOPPING: %d file(s) do not parse. Fix those before anything else.\n', nBad);
    return
end

fprintf('\n>>> 2/3  probe_sdk_types\n');
probe_sdk_types();

fprintf('\n>>> 3/3  verify_block_checkpoints\n');
try
    verify_block_checkpoints();
    fprintf('\nverify_block_checkpoints PASSED.\n');
catch ME
    fprintf(2, '\nverify_block_checkpoints FAILED: %s\n%s\n', ...
        ME.identifier, ME.message);
end

fprintf('\n########################################################\n');
if isempty(logFile)
    fprintf('Done. Could not open a transcript file; copy the text above.\n');
else
    fprintf('Done. Full transcript saved as TEXT -- send this file, not a photo:\n');
    fprintf('  %s\n', logFile);
end
fprintf('########################################################\n\n');
end


function logFile = resolveLog()
%RESOLVELOG Pick a writable transcript path, share first, tempdir second.
% Returns '' if neither works, in which case the checks still run.
candidates = { ...
    fullfile('\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages', ...
             'rig-checks.log'), ...
    fullfile(tempdir, 'rig-checks.log')};
for k = 1:numel(candidates)
    candidate = candidates{k};
    parent = fileparts(candidate);
    if ~isfolder(parent), continue; end
    fid = fopen(candidate, 'a');
    if fid >= 0
        fclose(fid);
        logFile = candidate;
        return
    end
end
logFile = '';
end


function reportHead(root)
%REPORTHEAD Print the checked-out commit, so we know which code ran.
% Confirms the pull actually landed. Never assume the clone is current.
gitDir = fullfile(root, '.git');
try
    headFile = fullfile(gitDir, 'HEAD');
    if ~isfile(headFile)
        fprintf('Commit          : (no .git here -- is this the clone?)\n');
        return
    end
    head = strtrim(fileread(headFile));
    if startsWith(head, 'ref: ')
        ref = strtrim(extractAfter(head, 'ref: '));
        refFile = fullfile(gitDir, ref);
        if isfile(refFile)
            sha = strtrim(fileread(refFile));
        else
            sha = resolvePacked(gitDir, ref);
        end
        fprintf('Branch          : %s\n', ref);
    else
        sha = head;
        fprintf('Branch          : (detached HEAD)\n');
    end
    if isempty(sha), sha = '(unresolved)'; end
    fprintf('Commit          : %s\n', sha);
catch ME
    fprintf('Commit          : (could not read: %s)\n', ME.message);
end
end


function sha = resolvePacked(gitDir, ref)
sha = '';
packed = fullfile(gitDir, 'packed-refs');
if ~isfile(packed), return; end
lines = strsplit(fileread(packed), newline);
for k = 1:numel(lines)
    parts = strsplit(strtrim(lines{k}));
    if numel(parts) == 2 && strcmp(parts{2}, ref)
        sha = parts{1};
        return
    end
end
end
