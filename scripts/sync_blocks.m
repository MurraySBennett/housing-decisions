function report = sync_blocks(localRoot, shareRoot)
%SYNC_BLOCKS Explicit offline immutable replication; publishes receipts last.
% Roots are run-kind directories (e.g. Data/participant), not their parent.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'experiment'));
assert(isfolder(localRoot), 'hw:sync:source', 'Local root is missing.');
assert(~strcmp(char(java.io.File(localRoot).getCanonicalPath()), char(java.io.File(shareRoot).getCanonicalPath())), ...
    'hw:sync:sameRoot', 'Source and destination must differ.');
cfg.paths.checkpoints = fullfile(localRoot,'blocks');
report = struct('id',{},'status',{},'message',{});
% Immutable identity and frozen schedules are needed for cross-rig recovery.
files = dir(fullfile(localRoot,'runs','*','*.mat'));
for k = 1:numel(files)
    if contains(files(k).name, '.partial'), continue; end
    source = fullfile(files(k).folder,files(k).name);
    relative = source(numel(localRoot)+2:end);
    try
        utils.checkpointIO('copy',source,fullfile(shareRoot,relative));
    catch ME
        report(end+1) = row(relative, classify(ME), ME.message); %#ok<AGROW>
        return; % Never publish blocks under incompatible/missing context.
    end
end
runs = dir(fullfile(localRoot,'blocks','*')); runs = runs([runs.isdir]);
for k = 1:numel(runs)
    id = runs(k).name;
    if startsWith(id,'.'), continue; end
    try
        state = utils.blockStore('scan', cfg, id);
        for j = 1:numel(state.receipts)
            receipt = state.receipts(j); source = receipt.artifactDirectory;
            relative = source(numel(localRoot)+2:end); target = fullfile(shareRoot,relative);
            % Also validate destination lineage: a second valid attempt is a conflict.
            targetCfg.paths.checkpoints = fullfile(shareRoot,'blocks');
            existing = utils.blockStore('scan', targetCfg, id);
            if numel(existing.receipts) >= receipt.blockOrdinal
                assert(strcmp(existing.receipts(receipt.blockOrdinal).attemptId, receipt.attemptId), ...
                    'hw:sync:conflict', 'Destination has a different completed attempt.');
            end
            for name = {'entry.mat','behavior.mat','gaze.mat','prepared.mat','receipt.mat'}
                utils.checkpointIO('copy',fullfile(source,name{1}),fullfile(target,name{1}));
            end
            utils.blockStore('scan', targetCfg, id);
        end
        status = 'complete';
        pending = cellfun(@(e) e.attempt.blockOrdinal >= state.nextBlock, state.incomplete);
        if any(pending), status = 'pending'; end
        report(end+1) = row(id,status,sprintf('%d verified block(s); %d interrupted attempt(s) retained locally', ...
            numel(state.receipts),sum(pending))); %#ok<AGROW>
    catch ME
        report(end+1) = row(id,classify(ME),ME.message); %#ok<AGROW>
    end
end
end
function r = row(id,status,message)
r = struct('id',id,'status',status,'message',message);
end
function status = classify(ME)
status = 'pending';
if contains(ME.identifier,'conflict') || contains(ME.identifier,'corrupt') || contains(ME.identifier,'lineage')
    status = 'conflict';
end
end
