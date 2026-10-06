function report = combine_blocks(localRoot, outputRoot, varargin)
%COMBINE_BLOCKS Offline canonical exports, only from a validated single lineage.
% Partial exports go under outputRoot/partial and never enter normal R globs.
% legacyFiles explicitly archives old MAT/CSV files under legacy/ unchanged;
% they are not assigned invented blocks, trials, or exact gaze onset times.
p = inputParser; p.addParameter('allowPartial',false,@islogical);
p.addParameter('legacyFiles',{},@iscell); p.parse(varargin{:});
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'experiment'));
localRoot = char(localRoot); outputRoot = char(outputRoot);
sourcePath = char(java.io.File(localRoot).getCanonicalPath());
outputPath = char(java.io.File(outputRoot).getCanonicalPath());
assert(~strcmp(sourcePath,outputPath) && ~startsWith([outputPath filesep],[sourcePath filesep]) && ...
    ~startsWith([sourcePath filesep],[outputPath filesep]), ...
    'hw:combine:output', 'Use separate raw and derived trees.');
assert(isfolder(localRoot), 'hw:combine:source', 'Raw root is missing.');
cfg.paths.checkpoints = fullfile(localRoot,'blocks');
report = struct('runId',{},'complete',{},'trialCount',{},'sampleCount',{},'output',{});
files = dir(fullfile(localRoot,'runs','*','run.mat'));
for k = 1:numel(files)
    record = load(fullfile(files(k).folder,files(k).name),'record'); run = record.record.run;
    states = cell(1,numel(run.domains)); complete = true;
    for d = 1:numel(run.domains)
        domain = run.domains{d}; planFile = fullfile(files(k).folder,[domain '-plan.mat']);
        expected = Inf;
        if isfile(planFile)
            f = load(planFile,'frozen'); expected = f.frozen.blockCount;
        end
        states{d} = utils.blockStore('scan',cfg,[run.runId '_' domain]);
        complete = complete && numel(states{d}.receipts) == expected;
    end
    assert(complete || p.Results.allowPartial, 'hw:combine:incomplete', ...
        '%s is incomplete; explicitly enable allowPartial to export verified blocks only.',run.runId);
    destination = outputRoot;
    if ~complete, destination = fullfile(outputRoot,'partial'); end
    behaviorTables = {}; events = {}; domainData = struct(); sampleCount = 0;
    attemptInventory = struct('domain',{},'blockOrdinal',{},'attemptId',{},'parentAttemptId',{}, ...
        'status',{},'reason',{},'evidencePath',{});
    for d = 1:numel(run.domains)
        domain = run.domains{d}; state = states{d}; blocks = cell(1,numel(state.receipts));
        for j = 1:numel(state.incomplete)
            a = state.incomplete{j}.attempt; a.directory = state.incomplete{j}.artifactDirectory; reason = 'interrupted; no verified completion';
            if a.blockOrdinal < state.nextBlock, reason = 'superseded interrupted attempt'; end
            attemptInventory(end+1) = inventory(a,'excluded',reason); %#ok<AGROW>
        end
        trialCells = {}; metadata = {};
        for b = 1:numel(state.receipts)
            receipt = state.receipts(b);
            a = receipt.identity; a.directory = receipt.artifactDirectory;
            attemptInventory(end+1) = inventory(a,'included','verified canonical lineage'); %#ok<AGROW>
            s = load(fullfile(receipt.artifactDirectory,'behavior.mat'),'behavior');
            g = load(fullfile(receipt.artifactDirectory,'gaze.mat'),'gaze');
            T = keys(s.behavior.trialTable,run,domain,receipt,complete);
            behaviorTables{end+1} = T; %#ok<AGROW>
            events{end+1} = keys(s.behavior.events,run,domain,receipt,complete); %#ok<AGROW>
            g.gaze.association = keys(g.gaze.association,run,domain,receipt,complete);
            blocks{b} = g.gaze; sampleCount = sampleCount + receipt.sampleCount;
            trialCells{end+1} = s.behavior.trials; metadata{end+1} = s.behavior.metadata; %#ok<AGROW>
        end
        % Cell blocks retain distinct clock epochs/schemas and exact integer columns.
        gazeExport = struct('schemaVersion',1,'logicalRunId',run.runId,'domain',domain, ...
            'complete',complete,'blocks',{blocks},'alignmentRule','half-open event intervals; unknown when clocks invalid');
        utils.checkpointIO('write',fullfile(destination,'gaze',[run.runId '_' domain '_gaze.mat']), ...
            struct('gazeExport',gazeExport));
        domainData.(domain) = struct('trialBlocks',{trialCells},'metadata',{metadata});
        if strcmp(run.task,'contdc')
            allTrials = struct([]);
            for b = 1:numel(trialCells), allTrials = [allTrials reshape(trialCells{b},1,[])]; end %#ok<AGROW>
            domainData.(domain).reversals = utils.scoreReversals(allTrials);
        end
    end
    trialTable = utils.stackTables(behaviorTables); eventTable = utils.stackTables(events);
    taskDir = run.task; if strcmp(taskDir,'contdc'), taskDir = 'cont_dc'; end
    stem = fullfile(destination,taskDir,run.runId);
    dataMat = struct('schemaVersion',1,'run',run,'signature',record.record.signature, ...
        'complete',complete,'domains',{run.domains},'domainData',domainData,'events',eventTable, ...
        'attemptInventory',attemptInventory);
    utils.checkpointIO('write',[stem '.mat'],struct('dataMat',dataMat,'trialTable',trialTable));
    writeCsv([stem '.csv'],trialTable);
    utils.checkpointIO('write',fullfile(destination,'events',[run.runId '_events.mat']),struct('events',eventTable));
    report(end+1) = struct('runId',run.runId,'complete',complete,'trialCount',height(trialTable), ...
        'sampleCount',sampleCount,'output',stem); %#ok<AGROW>
end
for k = 1:numel(p.Results.legacyFiles)
    source = p.Results.legacyFiles{k}; [~,name,ext] = fileparts(source);
    digest = utils.checkpointIO('hash',source);
    target = fullfile(outputRoot,'legacy',digest,[name ext]);
    utils.checkpointIO('copy',source,target);
    limitation = struct('source',source,'sha256',digest,'timing','Legacy timing unverified; no exact onsets reconstructed.');
    utils.checkpointIO('write',[target '.provenance.mat'],struct('limitation',limitation));
end
end
function T = keys(T,run,domain,r,complete)
n = height(T);
% The task's own block column and the checkpoint ordinal are the same number
% by construction -- auction_task.m:315-320 passes plan(t).block AS the
% ordinal, and recovery matches plan.block == recovery.nextBlock, so they
% cannot drift apart. This used to overwrite the column without checking,
% which silently relabels any row where that stops being true. Practice rows
% carry block = NaN (auction_task.m:713), and relabelling one of those as a
% real block would be invisible in the exported CSV.
if n > 0 && ismember('block', T.Properties.VariableNames)
    existing = T.block;
    if isnumeric(existing)
        mismatch = ~isnan(existing) & existing ~= r.blockOrdinal;
    else
        mismatch = string(existing) ~= string(r.blockOrdinal);
    end
    assert(~any(mismatch), 'hw:combine:blockMismatch', ...
        ['Trial block column disagrees with checkpoint ordinal %d in %s/%s ' ...
         '(%d of %d rows). Export would relabel them; resolve before analysis.'], ...
        r.blockOrdinal, run.runId, domain, nnz(mismatch), n);
end
T.participant = repmat(run.participant,n,1); T.session = repmat(run.sessionNum,n,1);
T.run_id = repmat(string(run.runId),n,1); T.task = repmat(string(run.task),n,1);
T.domain = repmat(string(domain),n,1); T.run_kind = repmat(string(run.runKind),n,1);
T.block = repmat(r.blockOrdinal,n,1); T.attempt_id = repmat(string(r.attemptId),n,1);
T.complete = repmat(complete,n,1); T.checkpoint_schema = ones(n,1);
end
function writeCsv(file,T)
parent = fileparts(file); if ~isfolder(parent), mkdir(parent); end
tmp = [tempname(parent) '.csv']; cleaner = onCleanup(@() removeTemp(tmp)); %#ok<NASGU>
writetable(T,tmp);
utils.checkpointIO('copy',tmp,file);
end
function removeTemp(file)
if isfile(file), delete(file); end
end

function row = inventory(a,status,reason)
row = struct('domain',a.domain,'blockOrdinal',a.blockOrdinal,'attemptId',a.attemptId, ...
    'parentAttemptId',a.parentAttemptId,'status',status,'reason',reason,'evidencePath',a.directory);
end
