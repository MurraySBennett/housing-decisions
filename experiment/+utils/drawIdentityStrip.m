function contentRect = drawIdentityStrip(window, cfg, tex, sel, idx, rect)
%UTILS.DRAWIDENTITYSTRIP  Thumbnail row for image-kind identity attributes.
%
%   contentRect = utils.drawIdentityStrip(window, cfg, tex, sel, idx, rect)
%
%   Identity attributes are always shown regardless of the attribute-count
%   level -- for houses that's all six photos. This draws them as an even
%   row of thumbnails across the top of `rect`, and returns the remaining
%   rect below the strip for the caller to lay out attribute content into.
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

n = numel(imgAttrs);
totalH = rect(4) - rect(2);
stripH = min(totalH * 0.5, max(100, totalH * 0.32));
pad = 6;
cellW = floor((rect(3) - rect(1) - (n+1)*pad) / n);

x = rect(1) + pad;
for k = 1:n
    imr = [x, rect(2)+pad, x+cellW, rect(2)+stripH-pad];
    v = imgAttrs(k).var;
    if isfield(tex, v) && idx <= numel(tex.(v)) && isfinite(tex.(v)(idx))
        Screen('DrawTexture', window, tex.(v)(idx), [], imr);
    else
        % Texture failed to load (missing file, bad path, etc.) -- a
        % visible placeholder is more useful for catching that than blank
        % space that looks like "nothing selected here."
        Screen('FrameRect', window, s.border, imr, 1);
    end
    x = x + cellW + pad;
end

contentRect = [rect(1), rect(2)+stripH, rect(3), rect(4)];

end
