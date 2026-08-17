function plan = trialPlan(cfg, nStimAvailable, rngStream)
%UTILS.TRIALPLAN  Build the auction trial schedule.
%
%   12 trials, competition balanced and order-randomised, with stimulus
%   assignment balanced across trials.
%
%   With ~12 options per trial over 12 trials you need ~144 presentations
%   from a window holding perhaps 70 stimuli, so items necessarily repeat.
%   That is fine -- it gives a within-participant reliability check for
%   free -- but it has to be deliberate: balanced repetition, never the
%   same item twice inside one trial, and a repetition index logged so
%   memory effects can be tested rather than assumed away.

if nargin < 3, rngStream = RandStream.getGlobalStream; end

nTrials  = cfg.auction.nTrials;
nOptions = cfg.auction.nOptionsPerTrial;

% --- Competition, balanced then shuffled ------------------------------
levels = repmat({'low','high'}, 1, ceil(nTrials/2));
levels = levels(1:nTrials);
levels = levels(randperm(rngStream, nTrials));

% --- Stimulus assignment ----------------------------------------------
need = nTrials * nOptions;
reps = ceil(need / nStimAvailable);
pool = repmat((1:nStimAvailable)', reps, 1);
pool = pool(randperm(rngStream, numel(pool)));
pool = pool(1:need);

plan = struct('trial', {}, 'competition', {}, 'stimIdx', {}, 'repIdx', {});
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
    plan(t).stimIdx     = chosen;
    plan(t).repIdx      = rep;
end

end
