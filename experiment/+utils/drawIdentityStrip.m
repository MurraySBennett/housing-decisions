function contentRect = drawIdentityStrip(window, cfg, tex, sel, idx, rect)
%UTILS.DRAWIDENTITYSTRIP  Fixed 2x3 thumbnail grid for identity photos.
%
%   contentRect = utils.drawIdentityStrip(window, cfg, tex, sel, idx, rect)
%
%   Identity attributes are always shown regardless of the attribute-count
%   level -- for houses that's all six photos. Drawn as a FIXED-SIZE 2-row
%   x 3-column grid (cfg.style.identityGrid), the same pixel dimensions
%   wherever this is called from -- previously the grid stretched or
%   compressed to whatever fraction of the caller's rect it happened to be
%   given, so photos came out a different size in the auction task than in
%   contdc, and a different size again depending on how much room was left
%   over after the attribute grid. Centered horizontally in `rect`; returns
%   the remaining rect below the grid for the caller to lay out into.
%
%   If sel.identity has no image-kind entries (jobs: industry/title are
%   text), this draws nothing and returns `rect` unchanged -- the caller's
%   existing text-only identity header still applies on top of that.

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

% Fixed size is the point, but don't run off the edge of a caller that's
% genuinely too narrow -- scale down uniformly as a last resort rather than
% overlapping neighbouring content, and only then.
availW = rect(3) - rect(1);
scale = min(1, availW / gridW);
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
        % Texture failed to load (missing file, bad path, etc.) -- a
        % visible placeholder is more useful for catching that than blank
        % space that looks like "nothing selected here."
        Screen('FrameRect', window, s.border, imr, 1);
    end
end

contentRect = [rect(1), oy + gridH, rect(3), rect(4)];

end
