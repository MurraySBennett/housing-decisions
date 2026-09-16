function w = fitToWindow(values, anchor, spread, minN)
%UTILS.FITTOWINDOW  Map EVERY stimulus onto the anchor-centred window.
%
%   w = utils.fitToWindow(stimuli.listPrice, budget, [0.6 1.6], 12)
%
%   The alternative to utils.sampleWindow, and the right one when the
%   stimulus set is too small or too skewed to fill a window by selection.
%
%   Houses are both. There are 80 of them and their list prices span 126:1
%   ($79k to $9.975M), while the window is a 2.67:1 ratio band -- so a
%   participant with a $150k budget had only 7-14 houses to work with. Over
%   24 auction trials that is the same house roughly 21 times, about 5 per
%   block, which is what the pilot noticed. It is also why contdc reused
%   stimuli inside a block: it needs nLevels x nPairs x 2 = 36 distinct
%   houses and the window held 7-23, so utils.buildPairs ran short.
%
%   Widening the window does not fix it. You need [0.30 4.00] -- a 13:1
%   band -- before every anchor clears 36 houses, at which point it is not
%   an anchor-centred window any more and the anchor manipulation is gone.
%
%   So instead of selecting stimuli to fit the window, fit the PRICES to
%   the window: rank the set and lay it out geometrically across [lo, hi].
%   Every participant sees all 80 houses, spread evenly over their own
%   budget range.
%
%   What this preserves, and what it costs.
%
%   PRESERVED. Rank order, exactly -- so price still covaries with the
%   attributes at the same Spearman correlation it always did (+0.749 with
%   square footage), which is what utils.buildPairs needs to oppose money
%   against quality. buildPairs z-scores the money dimension, so a change
%   of scale costs it nothing. Ties are preserved too: two houses listed at
%   the same price still cost the same.
%
%   COST. The displayed price is no longer the real list price, and the
%   price/quality RATIO is compressed -- a house with twice the floor area
%   no longer costs twice as much. w.priceMap keeps the original alongside
%   the fitted value so analysis can recover the real prices.
%
%   Geometric, not linear, and by RANK rather than by value. Both matter:
%   the window is a ratio band, so equal ratio steps use it evenly; and a
%   value-based map lets the skew through, which for houses means a single
%   $9.975M listing stretches the top of the window and leaves 48 of 80
%   houses bunched in one quarter of it. By rank the occupancy is 20/20/20/20.

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

% Rank, averaging over ties so equal prices stay equal. Not tiedrank():
% that lives in the Statistics Toolbox and this must run without it.
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

% The fitted values, and the mapping back. priceMap is the only record of
% what each house actually listed for, so it is not optional.
w.fitted    = fitted(idx);
w.priceMap  = [values(idx), fitted(idx)];

if ~w.sufficient
    warning('hw:fitToWindow:thin', ...
        ['Only %d stimuli have a usable value (wanted %d). Fitting cannot ' ...
         'create variety that is not in the set.'], n, minN);
end

% Same rule as utils.sampleWindow: scale bounds come from the window, not
% from the individual item, so a participant can bid above the top of it.
w.scaleMin = 0;
w.scaleMax = hi * 1.25;

end
