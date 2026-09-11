function [pairs, usedIdx] = buildPairs(stimTbl, sel, A, nPairs, rngStream, excludeIdx)
%UTILS.BUILDPAIRS  Construct money-vs-quality option pairs.
%
%   pairs = utils.buildPairs(stimTbl, sel, A, nPairs)
%
%   This is what makes the design capable of detecting a preference
%   reversal at all. Drawing two options at random -- which is what the
%   previous version did -- gives pairs that mostly differ on everything or
%   nothing, and the reversal effect washes out.
%
%   Classic reversal (Lichtenstein & Slovic) pits a P-bet (likely, small
%   payoff) against a $-bet (unlikely, large payoff): choice favours the
%   P-bet, pricing favours the $-bet. The analogue here is a MONEY option
%   against a QUALITY option:
%
%     jobs   : high wage / poor culture & work-life  vs  modest wage / excellent culture
%     houses : expensive but small & old             vs  cheap but large & modern
%
%   The prediction is that stating a dollar value pulls attention to the
%   monetary dimension while choosing pulls it to the qualitative ones.
%   Pairs are ranked by how cleanly they oppose the two dimensions, and the
%   contrast score is returned so weak pairs can be excluded in analysis.

if nargin < 5 || isempty(rngStream), rngStream = RandStream.getGlobalStream; end
if nargin < 6, excludeIdx = []; end
excludeIdx = excludeIdx(:)';

%   excludeIdx: stimulus indices that must NOT be used in these pairs --
%   pass the union of everything already used at other attribute levels to
%   stop a participant seeing the same house/job at more than one level.
%   Returns usedIdx so the caller can accumulate across levels.

n = height(stimTbl);
if n < 4
    error('hw:buildPairs:tooFewStimuli', ...
        'Need at least 4 stimuli to build pairs, have %d.', n);
end

% --- Money dimension --------------------------------------------------
money = zscore_(double(stimTbl.(A.valueVar))) * A.core(1).dir;

% --- Quality composite ------------------------------------------------
% Only numeric pool attributes that are actually on screen contribute, each
% signed by its direction so "higher is better" holds throughout.
q = [];
used = {};
for k = 1:numel(sel.shown)
    a = sel.shown(k);
    if strcmp(a.var, A.valueVar), continue; end
    if a.dir == 0, continue; end                       % images, categories
    if ~ismember(a.var, stimTbl.Properties.VariableNames), continue; end
    v = double(stimTbl.(a.var));
    if all(isnan(v)), continue; end
    q(:, end+1) = zscore_(v) * a.dir; %#ok<AGROW>
    used{end+1} = a.var; %#ok<AGROW>
end

if isempty(q)
    warning('hw:buildPairs:noQualityDim', ...
        ['No numeric non-value attributes are on screen at this level, so ' ...
         'no money-vs-quality contrast can be built. Falling back to ' ...
         'random pairing -- reversals will not be detectable.']);
    quality = zeros(n, 1);
else
    quality = mean(q, 2);
end

% --- Score every candidate pair ---------------------------------------
% A good pair has one option ahead on money and behind on quality, and the
% other the reverse. Contrast is the product of the two gaps: large only
% when the dimensions genuinely oppose.
best = zeros(0, 3);
for i = 1:n-1
    for j = i+1:n
        dm = money(i) - money(j);
        dq = quality(i) - quality(j);
        if dm * dq >= 0, continue; end                 % same direction: no contrast
        best(end+1, :) = [i, j, abs(dm) * abs(dq)]; %#ok<AGROW>
    end
end

if isempty(best)
    warning('hw:buildPairs:noOpposedPairs', ...
        'No opposed pairs found; falling back to random pairing.');
    idx = randperm(rngStream, n);
    take = min(nPairs, floor(n/2));
    best = [idx(1:take)', idx(take+1:2*take)', zeros(take,1)];
end

[~, ord] = sort(best(:,3), 'descend');
best = best(ord, :);

% --- Select, without reusing an item too often ------------------------
maxUse = max(2, ceil(2*nPairs / n));
use = zeros(n, 1);
pairs = struct('moneyIdx', {}, 'qualityIdx', {}, 'contrast', {}, ...
               'moneyGap', {}, 'qualityGap', {});

for r = 1:size(best, 1)
    if numel(pairs) >= nPairs, break; end
    i = best(r,1); j = best(r,2);
    if any(i == excludeIdx) || any(j == excludeIdx), continue; end
    if use(i) >= maxUse || use(j) >= maxUse, continue; end

    if money(i) > money(j), mi = i; qi = j; else, mi = j; qi = i; end

    pairs(end+1) = struct( ...
        'moneyIdx',   mi, ...
        'qualityIdx', qi, ...
        'contrast',   best(r,3), ...
        'moneyGap',   money(mi) - money(qi), ...
        'qualityGap', quality(qi) - quality(mi)); %#ok<AGROW>
    use(i) = use(i) + 1;
    use(j) = use(j) + 1;
end

if numel(pairs) < nPairs
    warning('utils:buildPairs:short', ...
        ['Requested %d pairs but only %d could be built from %d stimuli ' ...
         '(%d already used at other attribute levels). Either lower ' ...
         'cfg.contdc.nPairs for this domain, widen cfg.sampling.spread, or ' ...
         'allow cross-level reuse via cfg.contdc.allowCrossLevelReuse.'], ...
        nPairs, numel(pairs), n, numel(excludeIdx));
end

usedIdx = [];
for k = 1:numel(pairs)
    usedIdx(end+1) = pairs(k).moneyIdx;   %#ok<AGROW>
    usedIdx(end+1) = pairs(k).qualityIdx; %#ok<AGROW>
end
usedIdx = unique(usedIdx);

% Randomise which side each option lands on, per pair
for k = 1:numel(pairs)
    pairs(k).moneyOnLeft = rand(rngStream) < 0.5;
end

end


function z = zscore_(v)
%ZSCORE_  Local z-score, so no Statistics Toolbox dependency.
v = double(v(:));
mu = mean(v(~isnan(v)));
sd = std(v(~isnan(v)));
if sd == 0 || isnan(sd), sd = 1; end
z = (v - mu) / sd;
z(isnan(z)) = 0;
end
