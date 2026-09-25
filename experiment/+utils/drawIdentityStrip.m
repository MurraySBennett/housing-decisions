function contentRect = drawIdentityStrip(window, cfg, tex, sel, idx, rect)
%UTILS.DRAWIDENTITYSTRIP  Fixed 2x3 thumbnail grid for identity photos.
%
%   contentRect = utils.drawIdentityStrip(window, cfg, tex, sel, idx, rect)
%
%   Fixed pixel size from any caller; returns the remaining rect below the grid.
%   No image-kind identity (jobs): draws nothing, returns rect unchanged.

s = cfg.style;
rect = rect(:)';

isImg = false(1, numel(sel.identity));
for k = 1:numel(sel.identity)
    isImg(k) = strcmp(sel.identity(k).kind, 'image');
end
imgAttrs = sel.identity(isImg);

if isempty(imgAttrs)
    contentRect = rect;
    return
end

g = cfg.style.identityGrid;
gridW = g.nCols * g.cellW + (g.nCols - 1) * g.gap;
gridH = g.nRows * g.cellH + (g.nRows - 1) * g.gap;

availW = rect(3) - rect(1);
scale = min(g.maxScale, availW / gridW);
cellW = g.cellW * scale; cellH = g.cellH * scale; gap = g.gap * scale;
gridW = gridW * scale; gridH = gridH * scale;

ox = rect(1) + (availW - gridW) / 2;
oy = rect(2);

n = min(numel(imgAttrs), g.nCols * g.nRows);
for k = 1:n
    c = mod(k-1, g.nCols);
    r = floor((k-1) / g.nCols);
    x = ox + c * (cellW + gap);
    y = oy + r * (cellH + gap);
    imr = [x, y, x + cellW, y + cellH];

    v = imgAttrs(k).var;
    if isfield(tex, v) && idx <= numel(tex.(v)) && isfinite(tex.(v)(idx))
        Screen('DrawTexture', window, tex.(v)(idx), [], imr);
    else
        % Visible placeholder for a failed texture; square so it reads as a fault.
        Screen('FrameRect', window, s.rejected, imr, 1);
    end
end

contentRect = [rect(1), oy + gridH, rect(3), rect(4)];

end
