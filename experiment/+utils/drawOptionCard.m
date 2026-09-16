function aoi = drawOptionCard(window, cfg, rect, stimTbl, tex, sel, idx)
%UTILS.DRAWOPTIONCARD  One option: fixed identity photo grid, fixed slots.
%
%   The drawing half of utils.cardAOIs, and the two must stay in step: this
%   returns the rects it actually drew into, so a caller can assert against
%   what the AOI function predicted rather than trusting that they match.
%
%   A house's photos and attribute layout look identical regardless of
%   which task or screen they appear on -- the search detail view, the
%   contdc choice pair, the contdc price card, the auction bid screen.
%   That was stated as the intent in three separate places and implemented
%   separately in each of them.

s = cfg.style;
rect = rect(:)';
utils.roundRect(window, rect, s.radiusPanel, s.bgPanel, ...
    s.interactive, s.borderWidthPx);

pad = 18;
innerRect = [rect(1)+pad, rect(2)+pad, rect(3)-pad, rect(4)-pad];

% Identity images (houses: all six photos) are drawn first, in their own
% FIXED-SIZE grid, ALWAYS -- regardless of the attribute-count level for
% this trial. Falls through unchanged if this domain's identity has no
% images (jobs).
contentRect = utils.drawIdentityStrip(window, cfg, tex, sel, idx, innerRect);
x0 = contentRect(1);
y0 = contentRect(2) + 8;

% Identity text header (jobs: industry/title; empty for houses now that
% their images live in the grid above instead of here). Centred and set in
% body size rather than label size: left-aligned dim small text was reading
% as a caption on the attribute grid instead of as the card's heading.
% Pilot note 18, 2026-09-16.
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeContent);
idText = utils.identityString(stimTbl, sel, idx);
if ~isempty(idText)
    bnd = Screen('TextBounds', window, idText);
    idX = rect(1) + ((rect(3) - rect(1)) - bnd(3)) / 2;
    DrawFormattedText(window, idText, idX, y0 + 20, s.text);
    y0 = y0 + s.identityTextHeightPx;
end

% Attribute cells: FIXED slot positions from cfg.style.attrGrid, not
% recomputed from how many attributes this trial happens to show. A
% 2-attribute trial occupies slots 1-2 and leaves the rest blank; a
% 6-attribute trial occupies slots 1-6. Slot 1 is always the same screen
% position either way.
slots = utils.attrSlotRects(cfg, x0, y0);
n = numel(sel.shown);
aoi = zeros(4, n);

for k = 1:n
    cellRect = slots(:, k)';
    aoi(:, k) = cellRect';
    cx0 = cellRect(1); cy0 = cellRect(2);
    cellW = cellRect(3) - cellRect(1);

    attr = sel.shown(k);
    Screen('TextSize', window, s.sizeLabel);
    DrawFormattedText(window, attr.label, cx0 + 6, cy0 + 20, s.textDim, ...
        floor(cellW/8), 0, 0, 1.1);

    % Value follows the label closely (fixed offset, not bottom-anchored to
    % a variable-height cell) so the gap between title and value stays the
    % same regardless of how many attributes are on screen.
    valueY = cy0 + 46;

    if strcmp(attr.kind, 'image')
        if isfield(tex, attr.var) && idx <= numel(tex.(attr.var)) && isfinite(tex.(attr.var)(idx))
            Screen('DrawTexture', window, tex.(attr.var)(idx), [], ...
                [cx0+6, valueY, cellRect(3)-10, cellRect(4)-8]);
        end
    else
        Screen('TextSize', window, s.sizeContent);
        % The value attribute is NOT emphasised inside the grid. It is
        % already guaranteed present on every trial as the core tier, so
        % colouring it differently was an emphasis the design does not
        % intend. s.money is kept for numbers the participant is actively
        % SETTING (the price/bid arcs, the anchor box) -- an affordance,
        % not an emphasis.
        DrawFormattedText(window, utils.valueString(stimTbl, attr, idx), ...
            cx0 + 6, valueY, s.text);
    end
end
end
