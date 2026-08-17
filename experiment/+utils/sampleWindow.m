function w = sampleWindow(values, anchor, spread, minN, hardBounds)
%UTILS.SAMPLEWINDOW  Budget-centred stimulus window with a minimum-n guarantee.
%
%   w = utils.sampleWindow(stimuli.listPrice, budget, [0.6 1.6], 12)
%
%   Replaces the hard-coded price bands. Those bands held 11-16 houses each,
%   which is not enough to fill a block AND filter to a participant's budget
%   -- and filtering hard to budget destroys the variance in list price that
%   the anchor manipulation depends on.
%
%   So: centre on the anchor, keep deliberate spread either side, and widen
%   automatically until at least minN stimuli are inside. Returns the window
%   plus a flag saying how much widening was needed, which is worth logging
%   -- a participant whose window had to triple is not comparable to one
%   whose window didn't move.

if nargin < 3 || isempty(spread),     spread = [0.6 1.6]; end
if nargin < 4 || isempty(minN),       minN = 12;          end
if nargin < 5, hardBounds = [-Inf Inf];                   end

values = values(:);
values = values(~isnan(values));

widen = 1.0;
maxWiden = 6.0;
while true
    lo = anchor * (1 - (1 - spread(1)) * widen);
    hi = anchor * (1 + (spread(2) - 1) * widen);
    lo = max(lo, hardBounds(1));
    hi = min(hi, hardBounds(2));

    inWindow = values >= lo & values <= hi;
    if sum(inWindow) >= minN || widen >= maxWiden
        break
    end
    widen = widen * 1.25;
end

w.lo        = lo;
w.hi        = hi;
w.idx       = find(values >= lo & values <= hi);
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

% Scale bounds for the pricing response come from the WINDOW, not from the
% individual item. The old code used item.listPrice as the scale maximum,
% which meant a participant could never bid above list -- and with a
% $9.98M outlier in the set, an item-derived scale puts every realistic
% bid in the leftmost few percent of the arc.
w.scaleMin = 0;
w.scaleMax = hi * 1.25;

end
