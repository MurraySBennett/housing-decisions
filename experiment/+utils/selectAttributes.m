function sel = selectAttributes(A, nAttrs, poolRatings, method, isMaxLevel)
%UTILS.SELECTATTRIBUTES  Choose which attributes to display on a trial.
%
%   sel = utils.selectAttributes(A, nAttrs, poolRatings)
%   sel = utils.selectAttributes(A, nAttrs, poolRatings, 'topk')
%
%   A           : struct from utils.attributes
%   nAttrs      : attribute level for this block (e.g. 2, 4, 6) -- COUNTS
%                 the core attributes, so nAttrs=2 means core + 1 from pool
%   poolRatings : 1 x A.nPool vector of this participant's importance
%                 ratings, normalised 0-1, in the order of A.pool
%   method      : 'stratified' (default) or 'topk'
%   isMaxLevel  : logical; if true, A.late attributes are appended
%
%   Method matters more than it looks:
%
%     'topk'        shows the participant's k most important attributes.
%                   Ecologically valid, but each step up the attribute
%                   ladder adds a LESS important attribute, so a load
%                   effect and a diminishing-importance effect become
%                   indistinguishable.
%
%     'stratified'  picks evenly spaced ranks, holding mean importance
%                   roughly constant across levels. Isolates load.
%
%   Either way, the rating and rank of every selected attribute are
%   returned so you can model it the other way round after the fact.

if nargin < 4 || isempty(method),     method = 'stratified'; end
if nargin < 5 || isempty(isMaxLevel), isMaxLevel = false;    end

nFromPool = nAttrs - A.nCore;
if nFromPool < 0
    error('hw:selectAttributes:tooFew', ...
        'nAttrs=%d is below the %d core attributes for %s.', ...
        nAttrs, A.nCore, A.domain);
end
if nFromPool > A.nPool
    error('hw:selectAttributes:tooMany', ...
        'nAttrs=%d needs %d pool attributes but %s only has %d.', ...
        nAttrs, nFromPool, A.domain, A.nPool);
end

if isempty(poolRatings)
    poolRatings = rand(1, A.nPool);   % testing fallback only
end
poolRatings = poolRatings(:)';
assert(numel(poolRatings) == A.nPool, ...
    'hw:selectAttributes:badRatings', ...
    'Expected %d pool ratings for %s, got %d.', A.nPool, A.domain, numel(poolRatings));

% Rank 1 = most important
[~, order] = sort(poolRatings, 'descend');
ranks = zeros(1, A.nPool);
ranks(order) = 1:A.nPool;

switch lower(method)
    case 'topk'
        pick = order(1:nFromPool);

    case 'stratified'
        if nFromPool == 0
            pick = [];
        elseif nFromPool == 1
            pick = order(round((A.nPool + 1) / 2));   % median importance
        else
            idx  = unique(round(linspace(1, A.nPool, nFromPool)));
            % linspace can collide after rounding; backfill if so
            k = 1;
            while numel(idx) < nFromPool
                cand = setdiff(1:A.nPool, idx);
                idx = sort([idx, cand(k)]);
                k = k + 1;
            end
            pick = order(idx);
        end

    otherwise
        error('hw:selectAttributes:badMethod', 'Unknown method "%s".', method);
end

% --- Assemble ---------------------------------------------------------
sel.identity = A.identity;
sel.shown    = [A.core, A.pool(pick)];
sel.poolPick = pick;
sel.ratings  = [nan(1, A.nCore), poolRatings(pick)];
sel.ranks    = [nan(1, A.nCore), ranks(pick)];
sel.method   = method;
sel.nAttrs   = nAttrs;

if isMaxLevel && ~isempty(A.late)
    sel.shown   = [sel.shown, A.late];
    sel.ratings = [sel.ratings, nan(1, numel(A.late))];
    sel.ranks   = [sel.ranks,   nan(1, numel(A.late))];
    sel.nAttrs  = sel.nAttrs + numel(A.late);
end

sel.meanRank = mean(sel.ranks(~isnan(sel.ranks)));

end
