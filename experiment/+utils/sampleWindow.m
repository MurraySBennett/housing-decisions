function w = sampleWindow(values, anchor, spread, minN, hardBounds)
%UTILS.SAMPLEWINDOW  Budget-centred stimulus window with a minimum-n guarantee.
%
%   w = utils.sampleWindow(stimuli.listPrice, budget, [0.6 1.6], 12)
%   Widens around the anchor until at least minN stimuli fall inside.

if nargin < 3 || isempty(spread),     spread = [0.6 1.6]; end
if nargin < 4 || isempty(minN),       minN = 12;          end
if nargin < 5, hardBounds = [-Inf Inf];                   end

values = values(:);
valid = ~isnan(values);
usable = values(valid);

widen = 1.0;
maxWiden = 6.0;
while true
    lo = anchor * (1 - (1 - spread(1)) * widen);
    hi = anchor * (1 + (spread(2) - 1) * widen);
    lo = max(lo, hardBounds(1));
    hi = min(hi, hardBounds(2));

    inWindow = usable >= lo & usable <= hi;
    if sum(inWindow) >= minN || widen >= maxWiden
        break
    end
    widen = widen * 1.25;
end

w.lo        = lo;
w.hi        = hi;
w.idx       = find(valid & values >= lo & values <= hi);
w.n         = numel(w.idx);
w.anchor    = anchor;
w.widenBy   = widen;
w.sufficient = w.n >= minN;

if ~w.sufficient
    warning('hw:sampleWindow:thin', ...
        ['Only %d stimuli within [%.0f, %.0f] after widening %.2fx ' ...
         '(anchor %.0f, wanted %d). Block will be short.'], ...
        w.n, lo, hi, widen, anchor, minN);
end

% Pricing-scale bounds come from the window, not the individual item.
w.scaleMin = 0;
w.scaleMax = hi * 1.25;

end
