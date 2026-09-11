function slotRects = attrSlotRects(cfg, ox, oy)
%UTILS.ATTRSLOTRECTS  Fixed attribute-cell positions, independent of count.
%
%   slotRects = utils.attrSlotRects(cfg, ox, oy)
%
%   Returns a [4 x nSlots] matrix of [left top right bottom] rects, one per
%   slot in cfg.style.attrGrid, anchored with its top-left corner at
%   (ox, oy). Slot 1 is always top-left, slot 2 top-right (2 columns),
%   slot 3 second row left, and so on -- the caller indexes slotRects(:,k)
%   for the k-th attribute actually shown THIS trial and simply doesn't use
%   the remaining columns when there are fewer than the full 7.
%
%   Using a fixed grid regardless of how many attributes are shown is what
%   keeps attribute #1 in the same screen position whether this is a
%   2-attribute or 6-attribute trial -- the previous approach recomputed
%   rows/cols from the current count, so position (and cell size) changed
%   with the attribute-count condition, which is exactly the visual
%   confound this fixes.

g = cfg.style.attrGrid;
nSlots = g.nCols * g.nRows;
slotRects = zeros(4, nSlots);

for k = 1:nSlots
    c = mod(k-1, g.nCols);
    r = floor((k-1) / g.nCols);
    left = ox + c * (g.cellW + g.gap);
    top  = oy + r * (g.cellH + g.gap);
    slotRects(:, k) = [left; top; left + g.cellW; top + g.cellH];
end

end
