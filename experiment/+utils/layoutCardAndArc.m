function L = layoutCardAndArc(winRect, cfg, geom, nAttrs)
%UTILS.LAYOUTCARDANDARC  Option card on the left, pricing arc on the right.
%
%   Layout for every screen where a price is set while viewing the option.
%   Side by side so a fixation is on an attribute cell or the scale, never both.

s = cfg.style;
W = winRect(3); H = winRect(4);
hudH = s.hud.enabled * s.hud.heightPx;

L.promptY = hudH + 40;

marg = 50;
top  = hudH + 90;
bot  = H - 40;

cardW = min(650, round(W * 0.40));
L.cardRect = [marg; top; marg+cardW; bot];

gap = max(60, geom.targetSepPx);
L.arcLeft  = marg + cardW + gap;
L.arcRight = W - marg;
L.arcTop   = top;
L.arcBot   = bot;

L.nCols = 2;
L.nAttrs = nAttrs;
end
