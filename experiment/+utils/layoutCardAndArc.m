function L = layoutCardAndArc(winRect, cfg, geom, nAttrs)
%UTILS.LAYOUTCARDANDARC  Option card on the left, pricing arc on the right.
%
%   The layout for every screen where a participant sets a price while
%   looking at the option they are pricing: contdc's price trial, and --
%   since 2026-09-16 -- the auction's bid screen.
%
%   Side by side rather than stacked. Stacking put the scale's tick labels
%   directly beneath the attribute card with no reliable gap between them,
%   and the fixed-size photo/attribute grids need more vertical room than a
%   stacked layout could spare once the arc claimed the bottom of the
%   screen. Side by side gives both components their own clear zone, which
%   is also what makes the gaze record interpretable: a fixation is either
%   on an attribute cell or on the scale, never ambiguously on both.

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
