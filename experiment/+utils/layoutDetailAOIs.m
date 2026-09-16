function aoi = layoutDetailAOIs(winRect, cfg, sel)
%UTILS.LAYOUTDETAILAOIS  Auction detail-view geometry: identity strip + cells.
%
%   Full-width, unlike the card layouts -- the detail view is the whole
%   screen and has no arc competing for space. Pure geometry, so preflight.m
%   computes the same rects auction_task draws without a PTB window.

s = cfg.style;
W = winRect(3); H = winRect(4);
hudH = s.hud.enabled * s.hud.heightPx;
marg = 60;

aoi.idRect = [marg, hudH + 70, W - marg, H - 40];
contentRect = utils.reserveIdentityStrip(cfg, sel, aoi.idRect);
textTop = contentRect(2) + 8;
if utils.hasTextIdentity(sel)
    textTop = textTop + s.detailTextHeightPx;
end

g = s.attrGrid;
attrGridW = g.nCols*g.cellW + (g.nCols-1)*g.gap;
attrOx = (W - attrGridW) / 2;
slots = utils.attrSlotRects(cfg, attrOx, textTop + 10);

n = numel(sel.shown);
aoi.rects = slots(:, 1:n);
aoi.names = cell(1, n);
for k = 1:n
    aoi.names{k} = sprintf('detail_%s', sel.shown(k).var);
end
end
