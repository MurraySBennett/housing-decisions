function contentRect = reserveIdentityStrip(cfg, sel, rect)
%UTILS.RESERVEIDENTITYSTRIP  Rect left over below the identity photo grid.
%
%   The geometry half of utils.drawIdentityStrip: same arithmetic, no
%   drawing. Call it to find out where content starts without a window --
%   preflight.m has no PTB window and still has to know.
%
%   Returns rect unchanged for a domain whose identity has no images (jobs).

rect = rect(:)';
isImg = false(1, numel(sel.identity));
for k = 1:numel(sel.identity)
    isImg(k) = strcmp(sel.identity(k).kind, 'image');
end
if ~any(isImg)
    contentRect = rect;
    return
end

g = cfg.style.identityGrid;
gridW = g.nCols * g.cellW + (g.nCols - 1) * g.gap;
gridH = g.nRows * g.cellH + (g.nRows - 1) * g.gap;
scale = min(1, (rect(3) - rect(1)) / gridW);
contentRect = [rect(1), rect(2) + gridH * scale, rect(3), rect(4)];
end
