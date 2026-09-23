function aoi = cardAOIs(cfg, rect, sel, prefix)
%UTILS.CARDAOIS  AOI rects for the attribute cells drawn on one option card.
%
%   Pure geometry, no PTB, so preflight.m computes the same rects the task draws.
%   Single copy -- never duplicate this geometry in a task or preflight.

rect = rect(:)';
pad = 18;
innerRect = [rect(1)+pad, rect(2)+pad, rect(3)-pad, rect(4)-pad];
contentRect = utils.reserveIdentityStrip(cfg, sel, innerRect);
x0 = contentRect(1);
y0 = contentRect(2) + 8;
if utils.hasTextIdentity(sel)
    % Same constant utils.drawOptionCard advances by.
    y0 = y0 + cfg.style.identityTextHeightPx;
end

slots = utils.attrSlotRects(cfg, x0, y0);
n = numel(sel.shown);
aoi.rects = slots(:, 1:n);
aoi.names = cell(1, n);
for k = 1:n
    aoi.names{k} = sprintf('%s_%s', prefix, sel.shown(k).var);
end
end
