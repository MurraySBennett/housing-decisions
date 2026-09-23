function w = fitToWindow(values, anchor, spread, minN)
%UTILS.FITTOWINDOW  Map EVERY stimulus onto the anchor-centred window.
%
%   w = utils.fitToWindow(stimuli.listPrice, budget, [0.6 1.6], 12)
%   Rank-based geometric map of the whole set onto [anchor*spread]; the
%   alternative to utils.sampleWindow when the set cannot fill a window.

if nargin < 3 || isempty(spread), spread = [0.6 1.6]; end
if nargin < 4 || isempty(minN),   minN = 12;          end

values = values(:);
valid = ~isnan(values);
idx = find(valid);
n = numel(idx);

lo = anchor * spread(1);
hi = anchor * spread(2);

if n == 0
    error('hw:fitToWindow:noStimuli', ...
        'No stimuli have a usable value for the anchored attribute.');
end

% Tie-averaged ranks; not tiedrank(), which needs the Statistics Toolbox.
v = values(idx);
[sorted, ord] = sort(v);
r = zeros(n, 1);
k = 1;
while k <= n
    j = k;
    while j < n && sorted(j+1) == sorted(k)
        j = j + 1;
    end
    r(ord(k:j)) = (k + j) / 2;      % mean rank of the tied group
    k = j + 1;
end

if n == 1
    frac = 0.5;                      % a lone stimulus sits mid-window
else
    frac = (r - 1) / (n - 1);        % 0 .. 1
end

fitted = nan(size(values));
fitted(idx) = exp(log(lo) + frac * (log(hi) - log(lo)));

w.lo        = lo;
w.hi        = hi;
w.idx       = idx;
w.n         = n;
w.anchor    = anchor;
w.widenBy   = 1.0;                   % never widens: everything is inside
w.sufficient = n >= minN;
w.mode      = 'fit';

% priceMap is the only record of the real list prices; not optional.
w.fitted    = fitted(idx);
w.priceMap  = [values(idx), fitted(idx)];

if ~w.sufficient
    warning('hw:fitToWindow:thin', ...
        ['Only %d stimuli have a usable value (wanted %d). Fitting cannot ' ...
         'create variety that is not in the set.'], n, minN);
end

% Same rule as utils.sampleWindow: scale bounds come from the window, not the item.
w.scaleMin = 0;
w.scaleMax = hi * 1.25;

end
