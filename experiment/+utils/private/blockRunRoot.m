function root = blockRunRoot(cfg, id)
%BLOCKRUNROOT Where one logical run's block checkpoints live.
assert(ischar(id) && ~isempty(regexp(id, '^[A-Za-z0-9_-]+$', 'once')), ...
    'hw:blockStore:id', 'Invalid logical run ID.');
root = fullfile(cfg.paths.checkpoints, id);
end
