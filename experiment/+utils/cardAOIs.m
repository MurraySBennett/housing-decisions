function aoi = cardAOIs(cfg, rect, sel, prefix)
%UTILS.CARDAOIS  AOI rects for the attribute cells drawn on one option card.
%
%   Pure geometry, no window, no drawing -- so preflight.m can compute the
%   same rects the task will draw without PTB.
%
%   THIS IS THE ONE COPY. There used to be three: continuous_DC_task.m,
%   preflight.m, and (in spirit) auction_task.m's detail view. They drifted,
%   exactly as the comment in verify_static.sh predicted they would. Pilot
%   note 18 raised the identity header advance from 30 to 42 px and made it
%   the named constant s.identityTextHeightPx; the task was updated and
%   verify_static.sh was taught to guard it, but preflight's copy kept the
%   literal 30. So every AOI rect preflight checked for the contdc choice
%   and price screens sat 12 px above the cells actually drawn, and
%   pfAoi.allAoiOK -- the assertion verify_matlab.m runs FIRST at the rig --
%   was validating the wrong rectangles.
%
%   The fix is not a third guard. It is not having a second copy.

rect = rect(:)';
pad = 18;
innerRect = [rect(1)+pad, rect(2)+pad, rect(3)-pad, rect(4)-pad];
contentRect = utils.reserveIdentityStrip(cfg, sel, innerRect);
x0 = contentRect(1);
y0 = contentRect(2) + 8;
if utils.hasTextIdentity(sel)
    % Same constant the draw uses, by construction rather than by
    % agreement. utils.drawOptionCard advances by exactly this.
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
