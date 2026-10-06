function report = sync_blocks(localRoot, shareRoot)
%SYNC_BLOCKS Explicit offline immutable replication; publishes receipts last.
% Roots are run-kind directories (e.g. Data/participant), not their parent.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'experiment'));
localRoot = char(java.io.File(char(localRoot)).getCanonicalPath());
shareRoot = char(java.io.File(char(shareRoot)).getCanonicalPath());
assert(isfolder(localRoot), 'hw:sync:source', 'Local root is missing.');
assert(~strcmp(localRoot,shareRoot) && ~startsWith([shareRoot filesep],[localRoot filesep]) && ...
    ~startsWith([localRoot filesep],[shareRoot filesep]), ...
    'hw:sync:sameRoot', 'Source and destination must be separate trees.');
cfg.paths.checkpoints = fullfile(localRoot,'blocks');
report = struct('id',{},'status',{},'message',{});
try
    syncSessions(localRoot,shareRoot);
catch ME
    report(end+1) = row('sessions',classify(ME),ME.message);
    return;
end
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

function syncSessions(sourceRoot,targetRoot)
% Keep byte-identical historical snapshots as well as usable current records.
history = dir(fullfile(sourceRoot,'session_history','**','*'));
for k = 1:numel(history)
    if history(k).isdir, continue; end
    source = fullfile(history(k).folder,history(k).name);
    utils.checkpointIO('copy',source,fullfile(targetRoot,source(numel(sourceRoot)+2:end)));
end
files = dir(fullfile(sourceRoot,'sessions','*'));
for k = 1:numel(files)
    name = files(k).name;
    if files(k).isdir || contains(name,'.partial'), continue; end
    if ~endsWith(name,{'.mat','.csv'}), continue; end
    source = fullfile(files(k).folder,name);
    target = fullfile(targetRoot,'sessions',name);
    digest = utils.checkpointIO('hash',source);
    utils.checkpointIO('copy',source,fullfile(targetRoot,'session_history',name,digest,name));
    if ~isfile(target)
        utils.checkpointIO('copy',source,target); continue;
    end
    if strcmp(digest,utils.checkpointIO('hash',target)), continue; end
    % Preserve the destination version before any compatible merge too.
    targetDigest = utils.checkpointIO('hash',target);
    utils.checkpointIO('copy',target,fullfile(targetRoot,'session_history',name,targetDigest,name));
    if endsWith(name,'_manifest.mat')
        a = load(source,'manifest'); b = load(target,'manifest');
        for field = {'participant','runKind','assignment'}
            assert(isfield(a.manifest,field{1}) && isfield(b.manifest,field{1}) && ...
                isequaln(a.manifest.(field{1}),b.manifest.(field{1})), ...
                'hw:sync:conflict','Participant manifest context differs: %s',name);
        end
        manifest = b.manifest;
        for r = 1:numel(a.manifest.runs)
            incoming = a.manifest.runs(r);
            ix = find(strcmp({manifest.runs.runId},incoming.runId));
            if isempty(ix), manifest.runs(end+1) = incoming; continue; end
            for field = {'task','sessionNum','domainOrderStr','seed','codeVersion'}
                assert(isequaln(manifest.runs(ix).(field{1}),incoming.(field{1})), ...
                    'hw:sync:conflict','Run manifest context differs: %s',incoming.runId);
            end
            % Completion is reconstructed from receipts on restart. Keep local
            % status rather than letting a stale remote manifest demote it.
        end
        utils.checkpointIO('write',target,struct('manifest',manifest),true);
    elseif endsWith(name,'_timing.csv')
        a = readtable(source,'TextType','string'); b = readtable(target,'TextType','string');
        assert(ismember('timing_id',a.Properties.VariableNames) && ismember('timing_id',b.Properties.VariableNames), ...
            'hw:sync:conflict','Legacy timing cannot be safely merged; both versions are preserved in session_history.');
        assert(isequal(a.Properties.VariableNames,b.Properties.VariableNames), ...
            'hw:sync:conflict','Timing schema differs.');
        merged = unique([b;a],'rows','stable');
        tmp = [target '.' utils.checkpointIO('id') '.partial.csv'];
        writetable(merged,tmp);
        check = readtable(tmp,'TextType','string');
        assert(isequaln(merged,check),'hw:sync:verify','Timing read-back changed values.');
        [ok,msg] = movefile(tmp,target,'f'); assert(ok,'hw:sync:rename','%s',msg);
    else
        error('hw:sync:conflict','Immutable session context/elicitation differs: %s',name);
    end
end
end
