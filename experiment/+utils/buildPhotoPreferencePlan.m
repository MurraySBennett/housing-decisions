function plan = buildPhotoPreferencePlan(stimTbl, nRating, nPwc, areaQuotas, rngStream)
%UTILS.BUILDPHOTOPREFERENCEPLAN  Sample house photos and pairwise trials.
%   plan = utils.buildPhotoPreferencePlan(stimTbl, 80, 160, quotas, rs)
%   Pairwise trials always compare two photos of the same area.

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

[pwcPairs, pwcPairsPerArea] = makeWithinAreaPairs(ratingPhotoRows, ...
    photoTable, areaVars, nPwc, rngStream);

plan.photoTable       = photoTable;
plan.ratingPhotoRows  = ratingPhotoRows(:);
plan.pwcPairs         = pwcPairs;
plan.pwcPairsPerArea  = pwcPairsPerArea;
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


function [pairs, perArea] = makeWithinAreaPairs(photoRows, photoTable, areaVars, nPwc, rngStream)
% Same-area pairs; trials allocated across areas by largest remainder, then shuffled.
counts = zeros(numel(areaVars), 1);
rowsByArea = cell(numel(areaVars), 1);
for a = 1:numel(areaVars)
    rowsByArea{a} = photoRows(photoTable.areaVar(photoRows) == string(areaVars{a}));
    counts(a) = numel(rowsByArea{a});
end

alloc = floor(nPwc * counts / sum(counts));
remainder = nPwc * counts / sum(counts) - alloc;
[~, ord] = sort(remainder, 'descend');
short = nPwc - sum(alloc);
alloc(ord(1:short)) = alloc(ord(1:short)) + 1;

pairs = zeros(0, 2);
for a = 1:numel(areaVars)
    if alloc(a) == 0, continue; end
    maxUnique = counts(a) * (counts(a) - 1) / 2;
    if alloc(a) > maxUnique
        error('hw:photoPref:areaPairsTooMany', ...
            'Area %s needs %d pairs but its %d photos only make %d unique pairs.', ...
            areaVars{a}, alloc(a), counts(a), maxUnique);
    end
    pairs = [pairs; utils.samplePairs(rowsByArea{a}, alloc(a), rngStream)]; %#ok<AGROW>
end
pairs = pairs(randperm(rngStream, size(pairs, 1)), :);

perArea = struct();
for a = 1:numel(areaVars)
    perArea.(areaVars{a}) = alloc(a);
end
end
