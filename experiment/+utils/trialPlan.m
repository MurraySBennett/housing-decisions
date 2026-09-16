function plan = trialPlan(cfg, nStimAvailable, rngStream, participant)
%UTILS.TRIALPLAN  Build the auction trial schedule.
%
%   Competition is BLOCKED, block order counterbalanced by participant
%   parity, with stimulus assignment balanced across trials.
%
%   Why blocked. Until 2026-09-16 every trial was independently low or
%   high: balanced, then randperm'd. Neither pilot participant noticed the
%   level changing, and that is the expected result -- with trial-wise
%   randomisation there is nothing to form an expectation FROM, so the
%   manipulation barely operates. Market expectations are not a confound
%   here, they are closer to the point: cfg.auction.thresholdNoise already
%   makes the regime learnable while leaving the outcome uncertain, which
%   is the case worth having. Real markets are persistently competitive
%   rather than re-rolled per listing.
%
%   Counterbalancing mirrors utils.batteryPlan's trick for task order --
%   odd participants start on the other level -- so the two are consistent
%   and neither needs a condition file.
%
%   Four blocks in ABBA order, not two. Two blocks -- one run per level --
%   maximises how learnable each regime is, but it also confounds
%   competition with first-half/second-half within a participant, and
%   counterbalancing only turns that into noise across the sample rather
%   than removing it. ABBA puts both levels at the same mean serial
%   position, so the contrast is clean within each participant too. Set
%   cfg.auction.nBlocks = 2 to go back; the code handles either.
%
%   With ~12 options per trial over 24 trials you need ~288 presentations
%   from a window holding perhaps 70 stimuli, so items necessarily repeat.
%   That is fine -- it gives a within-participant reliability check for
%   free -- but it has to be deliberate: balanced repetition, never the
%   same item twice inside one trial, and a repetition index logged so
%   memory effects can be tested rather than assumed away.

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
% Blocks come in low/high pairs and must divide the trial count evenly --
% an uneven split would silently give one level more trials than the other.
% Rather than assert, fall back to the largest even block count that does
% divide: cfg.rehearsal.trialsPerCell = 3 is 6 trials, which 4 blocks does
% not divide, and a dress rehearsal must not be the thing that discovers
% that. The fallback warns, because at full-study counts it means the
% config is wrong and quietly running a different design is worse than
% being noisy.
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

% Odd participants start high, even start low; blocks alternate from there.
% With no participant supplied (a bare utils.trialPlan call in a test) the
% start is drawn, so the function is never silently deterministic.
if isempty(participant)
    startsHigh = rand(rngStream) < 0.5;
else
    startsHigh = mod(participant, 2) == 1;
end

levels = cell(1, nTrials);
blockOf = zeros(1, nTrials);
blockPos = zeros(1, nTrials);
for b = 1:nBlocks
    % ABBA, not ABAB. At nBlocks = 2 the two are the same thing (AB), but
    % at 4 only ABBA puts each level at the same mean position in the
    % session, which is the entire reason to prefer 4 blocks over 2 --
    % ABAB would leave the time-on-task confound that blocking was meant
    % to remove and only cancel it across participants.
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
