function [ratings, rts, order, detail] = elicitVASDrag(window, cfg, items, prompt, anchors, rngStream)
%UTILS.ELICITVASDRAG  Rate a set of items by dragging them onto one line.
%
%   [ratings, rts, order, detail] = utils.elicitVASDrag(window, cfg, items, ...
%                                       prompt, anchors, rngStream)
%
%   Same contract as utils.elicitVAS: ratings normalised 0-1 in item order.
%   rts is time to FIRST placement; check detail.nMoves before pooling with
%   sequential data.

s = cfg.style;
scr = Screen('Rect', window);
W = scr(3); H = scr(4);

n = numel(items);
ratings = nan(1, n);
rts     = nan(1, n);
if nargin < 6 || isempty(rngStream)
    rngStream = RandStream.getGlobalStream;
end

% Bank order randomised: a fixed order is itself an anchor.
bankOrder = randperm(rngStream, n);

lineY     = round(H * 0.68);
lineLeft  = W * 0.12;
lineRight = W * 0.88;
lineLen   = lineRight - lineLeft;

% Drops count anywhere in this band; the band keeps it a judgement, not a motor task.
dropBand = max(90, cfg.geom.deg2px(2.5));

% --- Chip geometry ----------------------------------------------------
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeLabel);
chipW = zeros(1, n);
for k = 1:n
    b = Screen('TextBounds', window, items{k});
    chipW(k) = b(3) + 36;
end
chipH = 44;
chipGap = 14;

% Bank rows, wrapped to the available width.
bankTop = round(H * 0.20);
bankMaxW = W * 0.84;
bankPos = zeros(2, n);      % [x; y] top-left of each chip's HOME slot
rowW = 0; rowIdx = 0; rowStart = 1;
for r = 1:n
    k = bankOrder(r);
    if rowW + chipW(k) > bankMaxW && r > rowStart
        bankPos(:, bankOrder(rowStart:r-1)) = layoutRow( ...
            bankPos(:, bankOrder(rowStart:r-1)), chipW(bankOrder(rowStart:r-1)), ...
            rowW, chipGap, W, bankTop + rowIdx * (chipH + chipGap));
        rowIdx = rowIdx + 1; rowStart = r; rowW = 0;
    end
    rowW = rowW + chipW(k) + chipGap;
end
bankPos(:, bankOrder(rowStart:n)) = layoutRow( ...
    bankPos(:, bankOrder(rowStart:n)), chipW(bankOrder(rowStart:n)), ...
    rowW, chipGap, W, bankTop + rowIdx * (chipH + chipGap));

% --- State ------------------------------------------------------------
placedX   = nan(1, n);      % x on the line once placed, NaN while in the bank
nMoves    = zeros(1, n);
firstAt   = nan(1, n);
lastAt    = nan(1, n);
dragIdx   = 0;
grabDX    = 0; grabDY = 0;
dragPos   = [0; 0];
placeSeq  = [];             % order of first placements

doneW = 200; doneH = 56;
doneRect = [W/2 - doneW/2, H - 110, W/2 + doneW/2, H - 110 + doneH];

t0 = GetSecs;
ShowCursor('Arrow', window);
KbReleaseWait;
prevButtons = false(1, 3);

while true
    [mx, my, buttons] = utils.getMouse(window);
    down    =  buttons(1) && ~prevButtons(1);
    up      = ~buttons(1) &&  prevButtons(1);
    prevButtons = buttons;

    allPlaced = ~any(isnan(placedX));

    % ---- input -------------------------------------------------------
    if down
        if allPlaced && inRect(doneRect, mx, my)
            break
        end
        hit = chipAtPoint(mx, my, placedX, bankPos, chipW, chipH, lineY);
        if hit > 0
            dragIdx = hit;
            [hx, hy] = chipHome(hit, placedX, bankPos, chipW, chipH, lineY);
            grabDX = mx - hx; grabDY = my - hy;
            dragPos = [hx; hy];
        end
    end

    if dragIdx > 0
        dragPos = [mx - grabDX; my - grabDY];
    end

    if up && dragIdx > 0
        cy = dragPos(2) + chipH/2;
        if abs(cy - lineY) <= dropBand
            xNew = min(max(dragPos(1) + chipW(dragIdx)/2, lineLeft), lineRight);
            if isnan(placedX(dragIdx))
                firstAt(dragIdx) = GetSecs - t0;
                placeSeq(end+1) = dragIdx; %#ok<AGROW>
            end
            placedX(dragIdx) = xNew;
            lastAt(dragIdx)  = GetSecs - t0;
            nMoves(dragIdx)  = nMoves(dragIdx) + 1;
        else
            % Dropped off the line: back to the bank -- placement must stay reversible.
            placedX(dragIdx) = NaN;
        end
        dragIdx = 0;
    end

    % ---- draw --------------------------------------------------------
    Screen('FillRect', window, s.bg);

    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeHeading);
    DrawFormattedText(window, prompt, 'center', H * 0.08, s.textDim, 70, 0, 0, 1.5);

    Screen('TextSize', window, s.sizeLabel);
    if allPlaced
        sub = 'Adjust any of them, then click Done.';
    else
        sub = 'Drag each one onto the line. Drag it back off to undo.';
    end
    DrawFormattedText(window, sub, 'center', H * 0.145, s.textDim);

    Screen('DrawLine', window, s.track, lineLeft, lineY, lineRight, lineY, 3);
    Screen('DrawLine', window, s.track, lineLeft, lineY-16, lineLeft, lineY+16, 3);
    Screen('DrawLine', window, s.track, lineRight, lineY-16, lineRight, lineY+16, 3);

    Screen('TextSize', window, s.sizeLabel);
    DrawFormattedText(window, anchors{1}, lineLeft - 40, lineY + 70, s.textDim);
    b = Screen('TextBounds', window, anchors{2});
    DrawFormattedText(window, anchors{2}, lineRight - b(3) + 40, lineY + 70, s.textDim);

    % Chips. Placed ones first so a chip being dragged draws over them.
    for k = 1:n
        if k == dragIdx, continue; end
        [hx, hy] = chipHome(k, placedX, bankPos, chipW, chipH, lineY);
        drawChip(window, cfg, items{k}, hx, hy, chipW(k), chipH, ...
            ~isnan(placedX(k)), false);
        if ~isnan(placedX(k))
            Screen('DrawLine', window, s.interactive, ...
                placedX(k), lineY-14, placedX(k), lineY+14, 3);
        end
    end
    if dragIdx > 0
        drawChip(window, cfg, items{dragIdx}, dragPos(1), dragPos(2), ...
            chipW(dragIdx), chipH, false, true);
        if abs(dragPos(2) + chipH/2 - lineY) <= dropBand
            gx = min(max(dragPos(1) + chipW(dragIdx)/2, lineLeft), lineRight);
            Screen('DrawLine', window, s.marker, gx, lineY-22, gx, lineY+22, 3);
        end
    end

    utils.roundRect(window, doneRect, s.radiusPanel, s.bgPanel, ...
        utils.ternary(allPlaced, s.interactive, s.border), s.borderWidthPx);
    Screen('TextSize', window, s.sizeContent);
    DrawFormattedText(window, utils.ternary(allPlaced, 'Done', ...
        sprintf('%d to place', sum(isnan(placedX)))), ...
        'center', doneRect(2) + 38, ...
        utils.ternary(allPlaced, s.text, s.textDim), [], [], [], [], [], doneRect);

    Screen('Flip', window);
    utils.checkForQuit;
end

ratings = (placedX - lineLeft) / lineLen;
rts     = firstAt;
order   = placeSeq;

detail = struct('nMoves', nMoves, 'firstPlaceAt', firstAt, ...
                'lastMoveAt', lastAt, 'totalSec', GetSecs - t0, 'mode', 'drag');

end


%% ======================================================================
function pos = layoutRow(pos, widths, rowW, gap, W, y)
%LAYOUTROW  Centre one wrapped row of bank chips.
x = (W - (rowW - gap)) / 2;
for k = 1:numel(widths)
    pos(:, k) = [x; y];
    x = x + widths(k) + gap;
end
end


%% ======================================================================
function [x, y] = chipHome(k, placedX, bankPos, chipW, chipH, lineY)
%CHIPHOME  Top-left of chip k wherever it currently lives.
if isnan(placedX(k))
    x = bankPos(1, k); y = bankPos(2, k);
else
    x = placedX(k) - chipW(k)/2;
    y = lineY - chipH - 26;
end
end


%% ======================================================================
function idx = chipAtPoint(mx, my, placedX, bankPos, chipW, chipH, lineY)
%CHIPATPOINT  Topmost chip under the cursor, placed chips taking priority.
idx = 0;
for k = numel(chipW):-1:1
    [x, y] = chipHome(k, placedX, bankPos, chipW, chipH, lineY);
    if mx >= x && mx <= x + chipW(k) && my >= y && my <= y + chipH
        idx = k;
        if ~isnan(placedX(k)), return; end   % placed chips win ties
    end
end
end


%% ======================================================================
function drawChip(window, cfg, label, x, y, w, h, placed, dragging)
s = cfg.style;
r = [x, y, x + w, y + h];
if dragging
    edge = s.marker;
elseif placed
    edge = s.interactive;
else
    edge = s.border;
end
utils.roundRect(window, r, s.radiusPanel, s.bgPanel, edge, s.borderWidthPx);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeLabel);
DrawFormattedText(window, label, 'center', y + 29, ...
    utils.ternary(placed || dragging, s.text, s.textDim), ...
    [], [], [], [], [], r);
end


%% ======================================================================
function tf = inRect(r, x, y)
tf = x >= r(1) && x <= r(3) && y >= r(2) && y <= r(4);
end
