function ok = verifyPaths(cfg)
%UTILS.VERIFYPATHS  Print every configured path and whether it exists.
%
%   utils.verifyPaths(utils.config('rig','lab'))
%
%   Run this ONCE on any new machine before touching run_battery.m. Every
%   path bug so far has been found by crashing mid-task rather than by
%   checking up front -- this checks all of them in one pass, in about a
%   second, with no PTB dependency.
%
%   MUST ALREADY EXIST (not auto-created; a missing one is a real problem):
%     root, tobii, experiment, stimuli, images, house/job stimulus files
%   AUTO-CREATED if missing (fine to be absent on a fresh machine):
%     data, sessions, taskData.auction/contdc, gaze, crashed, prepared

fprintf('\n=== Path check (rig: %s) ===\n\n', cfg.rig);

mustExist = { ...
    'paths.root',        cfg.paths.root,        'dir'; ...
    'paths.tobii',       cfg.paths.tobii,        'dir'; ...
    'paths.experiment',  cfg.paths.experiment,   'dir'; ...
    'paths.stimuli',     cfg.paths.stimuli,      'dir'; ...
    'paths.images',      cfg.paths.images,       'dir'; ...
    'stimFiles.houses',  cfg.stimFiles.houses,   'file'; ...
    'stimFiles.jobs',    cfg.stimFiles.jobs,     'file'; ...
};

autoCreated = { ...
    'paths.data',              cfg.paths.data; ...
    'paths.sessions',          cfg.paths.sessions; ...
    'paths.taskData.auction',  cfg.paths.taskData.auction; ...
    'paths.taskData.contdc',   cfg.paths.taskData.contdc; ...
    'paths.gaze',               cfg.paths.gaze; ...
    'paths.crashed',            cfg.paths.crashed; ...
    'paths.prepared',           cfg.paths.prepared; ...
};

ok = true;
fprintf('-- must already exist --\n');
for k = 1:size(mustExist, 1)
    [name, p, kind] = mustExist{k,:};
    present = exist(p, kind);
    tag = ternary_(present, 'OK  ', 'MISSING');
    if ~present, ok = false; end
    fprintf('  [%s] %-20s %s\n', tag, name, p);
end

fprintf('\n-- auto-created (fine if missing on a fresh machine) --\n');
for k = 1:size(autoCreated, 1)
    [name, p] = autoCreated{k,:};
    present = exist(p, 'dir');
    tag = ternary_(present, 'OK  ', 'will be created on first run');
    fprintf('  [%s] %-20s %s\n', tag, name, p);
end

if ~ok
    fprintf(2, ['\n*** One or more required paths are missing. Fix cfg.paths in\n' ...
                '    utils/config.m before running an experiment -- a missing\n' ...
                '    stimulus or Tobii path will crash mid-task rather than here.\n']);
else
    fprintf('\nAll required paths look correct.\n');
end
fprintf('\n');

end

function out = ternary_(cond, a, b)
if cond, out = a; else, out = b; end
end
