function pairs = samplePairs(rows, nPairs, rngStream)
%UTILS.SAMPLEPAIRS  Non-repeating pairwise trials with balanced exposure.
%
%   pairs = utils.samplePairs(rows, nPairs, rs)
%
%   Returns an nPairs x 2 matrix of values drawn from rows. No pair of
%   items ever repeats (in either order), left/right assignment is
%   randomized per trial, and items are dealt from repeated shuffled decks
%   so exposure counts stay as balanced as the trial count allows.
%
%   Extracted from buildPhotoPreferencePlan so the jobs preference task
%   can build cross-industry pairs from the same machinery.

n = numel(rows);
if n < 2
    error('hw:samplePairs:tooFewItems', 'Need at least two items to pair.');
end

slots = repmat(rows(:), ceil(2*nPairs / n), 1);
slots = slots(randperm(rngStream, numel(slots)));
pairs = zeros(nPairs, 2);
seen = containers.Map('KeyType','char', 'ValueType','logical');

p = 1;
guard = 0;
while p <= nPairs
    guard = guard + 1;
    if guard > nPairs * 200
        error('hw:samplePairs:pairBuildFailed', ...
            'Could not build %d non-repeated pairwise trials.', nPairs);
    end

    if numel(slots) < 2
        extra = repmat(rows(:), ceil((2*nPairs - 2*p + 4) / n), 1);
        slots = [slots; extra(randperm(rngStream, numel(extra)))]; %#ok<AGROW>
    end
    a = slots(1); b = slots(2); slots(1:2) = [];
    if a == b, slots(end+1) = b; continue; end %#ok<AGROW>

    key = sprintf('%d_%d', min(a,b), max(a,b));
    if isKey(seen, key)
        slots(end+1) = b; %#ok<AGROW>
        continue
    end
    seen(key) = true;

    if rand(rngStream) < 0.5
        pairs(p,:) = [a b];
    else
        pairs(p,:) = [b a];
    end
    p = p + 1;
end
end
