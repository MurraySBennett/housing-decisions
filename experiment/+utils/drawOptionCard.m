function aoi = drawOptionCard(window, cfg, rect, stimTbl, tex, sel, idx)
%UTILS.DRAWOPTIONCARD  One option: fixed identity photo grid, fixed slots.
%
%   Drawing half of utils.cardAOIs -- the two must stay in step. Returns the
%   rects actually drawn so callers can assert against the AOI prediction.

s = cfg.style;
rect = rect(:)';
utils.roundRect(window, rect, s.radiusPanel, s.bgPanel, ...
    s.interactive, s.borderWidthPx);

pad = 18;
innerRect = [rect(1)+pad, rect(2)+pad, rect(3)-pad, rect(4)-pad];

% Identity images drawn first in their fixed grid, at every attribute level.
contentRect = utils.drawIdentityStrip(window, cfg, tex, sel, idx, innerRect);
x0 = contentRect(1);
y0 = contentRect(2) + 8;

% Identity text header (jobs); empty for houses, whose images live in the grid.
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeContent);
idText = utils.identityString(stimTbl, sel, idx);
if ~isempty(idText)
    bnd = Screen('TextBounds', window, idText);
    idX = rect(1) + ((rect(3) - rect(1)) - bnd(3)) / 2;
    DrawFormattedText(window, idText, idX, y0 + 20, s.text);
    y0 = y0 + s.identityTextHeightPx;
end

% Fixed slot positions: slot 1 is the same screen position at every attribute level.
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
    label = char(string(attr.label));
    bnd = Screen('TextBounds', window, label);
    labelX = cx0 + max(6, (cellW - bnd(3)) / 2);
    DrawFormattedText(window, label, labelX, cy0 + 20, s.textDim, ...
        floor(cellW/8), 0, 0, 1.1);

    % Fixed offset keeps the label-value gap constant across attribute counts.
    valueY = cy0 + 46;

    if strcmp(attr.kind, 'image')
        if isfield(tex, attr.var) && idx <= numel(tex.(attr.var)) && isfinite(tex.(attr.var)(idx))
            Screen('DrawTexture', window, tex.(attr.var)(idx), [], ...
                [cx0+6, valueY, cellRect(3)-10, cellRect(4)-8]);
        end
    else
        Screen('TextSize', window, s.sizeContent);
        % Core value not emphasised; s.money is reserved for numbers being set.
        valueText = utils.valueString(stimTbl, attr, idx);
        bnd = Screen('TextBounds', window, valueText);
        valueX = cx0 + max(6, (cellW - bnd(3)) / 2);
        DrawFormattedText(window, valueText, valueX, valueY, s.text);
    end
end
end
