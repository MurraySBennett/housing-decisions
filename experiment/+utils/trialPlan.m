function plan = trialPlan(cfg, nStimAvailable, rngStream, participant)
%UTILS.TRIALPLAN  Build the auction trial schedule.
%
%   Competition blocked in ABBA order, counterbalanced by participant parity;
%   stimulus repetition is balanced, never within a trial, and logged as repIdx.

if nargin < 3, rngStream = RandStream.getGlobalStream; end
if nargin < 4, participant = []; end

nTrials  = cfg.auction.nTrials;
nOptions = cfg.auction.nOptionsPerTrial;

% --- Competition, blocked ---------------------------------------------
levelNames = {'low', 'high'};

nBlocks = 2;
if isfield(cfg.auction, 'nBlocks') && ~isempty(cfg.auction.nBlocks)
    nBlocks = cfg.auction.nBlocks;
end
% Blocks come in low/high pairs and must divide nTrials evenly; fall back (with a warning) to the largest even count that does.
requested = max(1, min(nBlocks, nTrials));
nBlocks = 0;
for b = (requested - mod(requested, 2)):-2:2
    if mod(nTrials, b) == 0
        nBlocks = b;
        break
    end
end
if nBlocks == 0
    nBlocks = 1;
    warning('hw:trialPlan:unevenBlocks', ...
        ['No even block count divides %d trials, so competition cannot be ' ...
         'balanced by block. Running a single block at one level. Check ' ...
         'cfg.auction.nTrials against cfg.auction.nBlocks.'], nTrials);
elseif nBlocks ~= requested
    warning('hw:trialPlan:blocksReduced', ...
        ['cfg.auction.nBlocks = %d does not divide %d trials; using %d ' ...
         'blocks of %d instead.'], requested, nTrials, nBlocks, nTrials / nBlocks);
end
perBlock = nTrials / nBlocks;

% Odd participants start high, even start low; no participant means a random start.
if isempty(participant)
    startsHigh = rand(rngStream) < 0.5;
else
    startsHigh = mod(participant, 2) == 1;
end

levels = cell(1, nTrials);
blockOf = zeros(1, nTrials);
blockPos = zeros(1, nTrials);
for b = 1:nBlocks
    % ABBA, not ABAB: only ABBA puts each level at the same mean serial position.
    which = 1 + mod(floor((b - 1) / 2) + (b - 1) + double(startsHigh), 2);
    rows = (b-1)*perBlock + (1:perBlock);
    levels(rows) = levelNames(which);
    blockOf(rows) = b;
    blockPos(rows) = 1:perBlock;
end

% --- Stimulus assignment ----------------------------------------------
need = nTrials * nOptions;
reps = ceil(need / nStimAvailable);
pool = repmat((1:nStimAvailable)', reps, 1);
pool = pool(randperm(rngStream, numel(pool)));
pool = pool(1:need);

plan = struct('trial', {}, 'competition', {}, 'block', {}, 'blockPos', {}, ...
              'stimIdx', {}, 'repIdx', {});
seen = zeros(nStimAvailable, 1);
cursor = 1;

for t = 1:nTrials
    chosen = [];
    guard = 0;
    while numel(chosen) < nOptions
        if cursor > numel(pool)                     % pool exhausted: reshuffle
            pool = [pool; pool(randperm(rngStream, numel(pool)))]; %#ok<AGROW>
        end
        cand = pool(cursor);
        cursor = cursor + 1;
        if ~ismember(cand, chosen)
            chosen(end+1) = cand; %#ok<AGROW>
        end
        guard = guard + 1;
        if guard > 50 * nOptions                    % degenerate: too few stimuli
            remaining = setdiff(1:nStimAvailable, chosen);
            take = min(nOptions - numel(chosen), numel(remaining));
            chosen = [chosen, remaining(1:take)]; %#ok<AGROW>
            break
        end
    end

    rep = zeros(1, numel(chosen));
    for k = 1:numel(chosen)
        seen(chosen(k)) = seen(chosen(k)) + 1;
        rep(k) = seen(chosen(k));
    end

    plan(t).trial       = t;
    plan(t).competition = levels{t};
    plan(t).block       = blockOf(t);
    plan(t).blockPos    = blockPos(t);
    plan(t).stimIdx     = chosen;
    plan(t).repIdx      = rep;
end

end
