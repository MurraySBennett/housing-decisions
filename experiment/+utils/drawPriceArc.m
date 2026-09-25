function drawPriceArc(window, cx, cy, scaleR, colour, widthPx)
%UTILS.DRAWPRICEARC  Continuous semicircular pricing scale.

a = linspace(pi, 2*pi, 720);
xy = [cx + scaleR * cos(a); cy + scaleR * sin(a)];
Screen('DrawLines', window, xy, widthPx, colour);
end
