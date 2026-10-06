function nBad = check_syntax()
%CHECK_SYNTAX Parse every .m file in the repo and report syntax errors.
%
%   nBad = check_syntax()
%
%   Needs MATLAB only: no Psychtoolbox, no Tobii SDK, no tracker, no display,
%   no participant. Reads files and prints; writes nothing. Returns the number
%   of files that fail to parse.
%
%   Why this exists: the block-checkpoint code was written and reviewed without
%   MATLAB available, so no file in it has ever been parsed by MATLAB. A syntax
%   error anywhere in the task path stops a session at the first call, and the
%   shell and Python checks in scripts/ cannot see MATLAB syntax. checkcode
%   parses without executing, so this is safe to run on the rig at any time.
%
%   Run from the repository root:
%       addpath('experiment','scripts'); check_syntax

root = fileparts(fileparts(mfilename('fullpath')));
files = [ ...
    dir(fullfile(root, 'experiment', '*.m')); ...
    dir(fullfile(root, 'experiment', '+utils', '*.m')); ...
    dir(fullfile(root, 'scripts', '*.m')); ...
    dir(fullfile(root, 'scripts', 'tests', '*.m')); ...
    dir(fullfile(root, 'scripts', 'tests', 'fixtures', '*.m'))];

fprintf('\n==================== MATLAB syntax check ====================\n');
fprintf('Parsing %d files under %s\n\n', numel(files), root);

nBad = 0;
for k = 1:numel(files)
    path = fullfile(files(k).folder, files(k).name);
    relative = strrep(path, [root filesep], '');
    try
        messages = checkcode(path, '-struct', '-id');
    catch ME
        fprintf('  COULD NOT ANALYSE %s: %s\n', relative, ME.message);
        nBad = nBad + 1;
        continue
    end
    % checkcode reports genuine parse failures under these ids; style and
    % lint advice is deliberately ignored, since only parse errors stop a run.
    isSyntax = false(numel(messages), 1);
    for m = 1:numel(messages)
        id = messages(m).id;
        isSyntax(m) = any(strcmp(id, {'SYNER', 'MDEPR', 'PFPCT'})) || ...
            startsWith(id, 'SYN') || contains(lower(messages(m).message), 'parse error');
    end
    bad = messages(isSyntax);
    if ~isempty(bad)
        nBad = nBad + 1;
        fprintf('  FAIL %s\n', relative);
        for m = 1:numel(bad)
            fprintf('       line %d: %s\n', bad(m).line, bad(m).message);
        end
    end
end

fprintf('\n');
if nBad == 0
    fprintf('All %d files parse. No MATLAB syntax errors.\n', numel(files));
else
    fprintf('%d file(s) FAILED to parse. Fix these before any session.\n', nBad);
end
fprintf('=============================================================\n\n');

if nargout == 0
    clear nBad
end
end
