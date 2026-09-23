function sel = selectAttributes(A, nAttrs, poolRatings, method, isMaxLevel)
%UTILS.SELECTATTRIBUTES  Choose which attributes to display on a trial.
%
%   nAttrs counts the core attributes; 'stratified' (default) holds mean
%   importance roughly constant across levels, 'topk' takes the k most important.

if nargin < 4 || isempty(method),     method = 'stratified'; end
if nargin < 5 || isempty(isMaxLevel), isMaxLevel = false;    end

% The late tier is reserved inside nAttrs, so numel(sel.shown) == nAttrs at every level.
nLate = 0;
if isMaxLevel && ~isempty(A.late)
    nLate = numel(A.late);
end

nFromPool = nAttrs - A.nCore - nLate;
if nFromPool < 0
    error('hw:selectAttributes:tooFew', ...
        'nAttrs=%d is below the %d always-shown attributes (%d core + %d late) for %s.', ...
        nAttrs, A.nCore + nLate, A.nCore, nLate, A.domain);
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

if nLate > 0
    % Late slot was already reserved out of nFromPool; do not increment nAttrs.
    sel.shown   = [sel.shown, A.late];
    sel.ratings = [sel.ratings, nan(1, numel(A.late))];
    sel.ranks   = [sel.ranks,   nan(1, numel(A.late))];
end

sel.meanRank = mean(sel.ranks(~isnan(sel.ranks)));

end
