function slotRects = attrSlotRects(cfg, ox, oy)
%UTILS.ATTRSLOTRECTS  Fixed attribute-cell positions, independent of count.
%
%   slotRects = utils.attrSlotRects(cfg, ox, oy)
%
%   [4 x nSlots] rects [l t r b]; fixed grid keeps positions constant across
%   attribute-count conditions.

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
