function plan = buildPhotoPreferencePlan(stimTbl, nRating, nPwc, areaQuotas, rngStream)
%UTILS.BUILDPHOTOPREFERENCEPLAN  Sample house photos and pairwise trials.
%
%   plan = utils.buildPhotoPreferencePlan(stimTbl, 80, 160, quotas, rs)
%
%   The stimulus unit is an individual house photo, not a full listing.
%   photoTable has one row per image cell in house_stimuli.csv.

if nargin < 5 || isempty(rngStream), rngStream = RandStream.getGlobalStream; end
if nargin < 4, areaQuotas = struct(); end

areaVars   = {'extPic','kitPic','bedPic','bathPic','livPic','outPic'};
areaLabels = {'Exterior','Kitchen','Bedroom','Bathroom','Living room','Outdoor space'};
photoId = {};
houseIdx = [];
areaVar = {};
areaLabel = {};
imageFile = {};
zone = {};
listPrice = [];

for h = 1:height(stimTbl)
    for a = 1:numel(areaVars)
        v = areaVars{a};
        if ~ismember(v, stimTbl.Properties.VariableNames), continue; end
        photoId{end+1,1} = sprintf('%03d_%s', h, v); %#ok<AGROW>
        houseIdx(end+1,1) = h; %#ok<AGROW>
        areaVar{end+1,1} = v; %#ok<AGROW>
        areaLabel{end+1,1} = areaLabels{a}; %#ok<AGROW>
        imageFile{end+1,1} = stimTbl.(v){h}; %#ok<AGROW>
        zone{end+1,1} = char(string(stimTbl.Zone(h))); %#ok<AGROW>
        listPrice(end+1,1) = stimTbl.listPrice(h); %#ok<AGROW>
    end
end

photoTable = table(string(photoId), houseIdx, string(areaVar), ...
    string(areaLabel), string(imageFile), string(zone), listPrice, ...
    'VariableNames', {'photoId','houseIdx','areaVar','areaLabel', ...
                      'imageFile','zone','listPrice'});

if isempty(fieldnames(areaQuotas))
    areaQuotas = balancedQuotas(areaVars, nRating);
end

ratingPhotoRows = [];
for a = 1:numel(areaVars)
    v = areaVars{a};
    q = areaQuotas.(v);
    rows = find(photoTable.areaVar == string(v));
    if q > numel(rows)
        error('hw:photoPref:quotaTooLarge', ...
            'Area %s requested %d photos but only %d exist.', v, q, numel(rows));
    end
    ord = randperm(rngStream, numel(rows));
    ratingPhotoRows = [ratingPhotoRows; rows(ord(1:q))]; %#ok<AGROW>
end

if numel(ratingPhotoRows) ~= nRating
    error('hw:photoPref:badQuotaTotal', ...
        'AREA_QUOTAS total %d but N_RATING is %d.', numel(ratingPhotoRows), nRating);
end
ratingPhotoRows = ratingPhotoRows(randperm(rngStream, numel(ratingPhotoRows)));

pwcPairs = makePairs(ratingPhotoRows, nPwc, rngStream);

plan.photoTable       = photoTable;
plan.ratingPhotoRows  = ratingPhotoRows(:);
plan.pwcPairs         = pwcPairs;
plan.areaVars         = areaVars;
plan.areaLabels       = areaLabels;
plan.areaQuotas       = areaQuotas;
plan.nRating          = nRating;
plan.nPwc             = nPwc;
end


function q = balancedQuotas(areaVars, n)
base = floor(n / numel(areaVars));
remn = mod(n, numel(areaVars));
for k = 1:numel(areaVars)
    q.(areaVars{k}) = base + double(k <= remn);
end
end


function pairs = makePairs(photoRows, nPairs, rngStream)
n = numel(photoRows);
if n < 2
    error('hw:photoPref:tooFewPhotos', 'Need at least two photos for PWC.');
end

slots = repmat(photoRows(:), ceil(2*nPairs / n), 1);
slots = slots(randperm(rngStream, numel(slots)));
pairs = zeros(nPairs, 2);
seen = containers.Map('KeyType','char', 'ValueType','logical');

p = 1;
guard = 0;
while p <= nPairs
    guard = guard + 1;
    if guard > nPairs * 200
        error('hw:photoPref:pairBuildFailed', ...
            'Could not build %d non-repeated pairwise trials.', nPairs);
    end

    if numel(slots) < 2
        extra = repmat(photoRows(:), ceil((2*nPairs - 2*p + 4) / n), 1);
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
