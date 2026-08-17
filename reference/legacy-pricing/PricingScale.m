classdef PricingScale
    properties
        window
        minRange
        maxRange
        nMajor
        xPos
        yPos
        tickStart
        tickStop
        textLoc
        size_scale
        fg
        bg
        staticScaleBuffer
    end

    methods
        function scale = PricingScale(window, minRange, maxRange, nMajor, yPos, size_scale, fg, bg)
            scale.window= window;
            scale.fg = fg;
            scale.bg = bg;
            scale.minRange = minRange;
            scale.maxRange = maxRange;
            scale.nMajor = nMajor;
            scale.yPos = yPos;
            [scale.xPos, ~] = RectCenter(Screen('Rect', window));
            scale.size_scale = size_scale;
            scale.tickStart = 0.8 * size_scale;
            scale.tickStop  = 0.85 * size_scale;
            scale.textLoc   = 0.95 * size_scale;

            windowRect = Screen('Rect', window);
            scale.staticScaleBuffer = Screen('OpenOffscreenWindow', window, [0,0,0,0], windowRect);
            Screen('BlendFunction', scale.staticScaleBuffer, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
            scale.drawStaticElements();
        end

        function drawStaticElements(scale)
            Screen('FillRect', scale.staticScaleBuffer, [0,0,0,0]);

            [minRadials, majRadials, tickLabels, tickLocations] = scale.setTicks();
            inner = round(scale.tickStart * scale.yPos);
            rect = [...
                scale.xPos - inner, scale.yPos - inner, ...
                scale.xPos + inner, scale.yPos + inner  ...
                ];
            startAngle  = 270;
            arcAngle    = 180;
            penWidth    = 5;
            penHeight   = 5;

            Screen('TextSize', scale.staticScaleBuffer, round(scale.xPos / 20));
            Screen('DrawLines', scale.staticScaleBuffer, majRadials, 3, scale.fg);
            Screen('DrawLines', scale.staticScaleBuffer, minRadials, 2, scale.fg);
            for t = 1:length(tickLabels)
                Screen('DrawText', scale.staticScaleBuffer, tickLabels{t}, tickLocations(1, t), tickLocations(2, t), scale.fg, [], []);
            end

            Screen('FrameArc', scale.staticScaleBuffer, scale.fg, rect, startAngle, arcAngle, penWidth, penHeight);
        end


        function draw(scale)
            Screen('DrawTexture', scale.window, scale.staticScaleBuffer, [], Screen('Rect', scale.window));
        end

        function [majRadials, minRadials, tickLabels, labelLocation] = setTicks(scale)
            nMinor      = scale.nMajor * 2;
            rawTickValues = round(linspace(scale.minRange, scale.maxRange, scale.nMajor + 1));
            tickLabels = cell(1, length(rawTickValues));
            isTickLabel = true;
            for i = 1:length(rawTickValues)
                tickLabels{i} = scale.formatCurrencyString(rawTickValues(i), isTickLabel);
            end

            majRadials  = zeros(2, scale.nMajor*2);
            minRadials  = zeros(2, nMinor*2);
            labelLocation= zeros(2, scale.nMajor*2);
            innerRadius = round(scale.tickStart * scale.yPos);
            outerRadius = round(scale.tickStop  * scale.yPos);
            minorRadius = round(innerRadius * 1.02);
            textRadius  = scale.size_scale;%0.9 * scale.size_scale; % Original textRadius calculation

            tickAngles = linspace(pi, 2*pi, scale.nMajor + 1);
            for i = 1:scale.nMajor + 1
                majRadials(1, (i*2-1)) = round(innerRadius .* cos(tickAngles(i)) + scale.xPos);
                majRadials(2, (i*2-1)) = round(innerRadius .* sin(tickAngles(i)) + scale.yPos);
                majRadials(1, (i*2))   = round(outerRadius .* cos(tickAngles(i)) + scale.xPos);
                majRadials(2, (i*2))   = round(outerRadius .* sin(tickAngles(i)) + scale.yPos);

                % labelLocation(1, i) = round(textRadius * scale.yPos * cos(tickAngles(i)) + scale.xPos) - scale.xPos / 30;
                % labelLocation(2, i) = round(textRadius * .95 * scale.yPos * sin(tickAngles(i)) + scale.yPos);

                labelLocation(1, i) = round(textRadius * scale.yPos * cos(tickAngles(i)) + (0.95*scale.xPos));
                labelLocation(2, i) = round(textRadius * .95 * scale.yPos * sin(tickAngles(i)) + (scale.yPos*0.975));

            end

            tickAngles = linspace(pi, 2*pi, nMinor + 1);
            for i = 1:nMinor
                minRadials(1, (i*2-1)) = round(innerRadius .* cos(tickAngles(i)) + scale.xPos);
                minRadials(2, (i*2-1)) = round(innerRadius .* sin(tickAngles(i)) + scale.yPos);
                minRadials(1, (i*2))   = round(minorRadius .* cos(tickAngles(i)) + scale.xPos);
                minRadials(2, (i*2))   = round(minorRadius .* sin(tickAngles(i)) + scale.yPos);
            end
        end


        function [response_val, is_at_scale] = calculateMouseResponse(scale, xMouse, yMouse)
            response_val = -1;

            [centerX, centerY] = RectCenter(Screen('Rect', scale.window));
            innerRadius = round(scale.tickStart * scale.yPos);
            outerRadius = round(scale.tickStop * scale.yPos);

            xDist = xMouse - centerX;
            yDist = centerY - yMouse;
            rMouse = sqrt(xDist^2 + yDist^2);
            thMouse = atan2(abs(yDist), xDist);
            is_at_scale = ...
                rMouse >= innerRadius && ...
                rMouse <= outerRadius * 1.1 && ...
                yMouse <= centerY * 1.02;

            if is_at_scale
                rangeDiff = scale.maxRange - scale.minRange;
                response_val = (rangeDiff - rangeDiff * thMouse / pi) + scale.minRange;
            end
        end

        function drawDynamicText(scale, response_val)
            isTickLabel = false;
            if response_val >= 0
                txt = scale.formatCurrencyString(response_val, isTickLabel);
                currentTextSize = round(scale.xPos / 20);
                Screen('TextSize', scale.window, currentTextSize);
                DrawFormattedText(scale.window, txt, 'center', scale.yPos * 0.6, scale.fg);
            end
        end

        function textRect = getDynamicTextRect(scale)
            dynamicTextSize = round(scale.xPos / 20);
            originalTextSize= Screen('TextSize', scale.window);
            Screen('TextSize', scale.window, dynamicTextSize);
            if scale.maxRange >= 10000
                longestString = scale.formatCurrencyString(scale.maxRange, false);
                if scale.maxRange >= 1e6
                    testString = '$999.9M';
                elseif scale.maxRange >= 1e3
                    testString = '$999.9K';
                else
                    testString = '$999.99';
                end
            else
                testString = '$999.99';
            end
            [normBoundsRect] = Screen('TextBounds', scale.window, testString);
            textWidth = normBoundsRect(3);
            textHeight = normBoundsRect(4);
            drawX = scale.xPos;
            drawY = scale.yPos * 0.6;
            textLeft = drawX - textWidth / 2;
            textTop = drawY - textHeight / 2;
            textRect = [textLeft, textTop, textLeft + textWidth, textTop + textHeight];
            Screen('TextSize', scale.window, originalTextSize);
        end

    end

    methods (Access = private)
        function formattedStr = formatCurrencyString(scale, value, isTickLabel)
            formatThreshold = 100; % if greater than 10K, let's start using symbols.
            if scale.maxRange >= formatThreshold
                if abs(value) >= 1e6
                    formattedStr = sprintf('$%.1fM', value / 1e6);
                elseif abs(value) >= 1e4
                    formattedStr = sprintf('$%.0fK', value / 1e3);
                elseif abs(value) >= 1e3
                    formattedStr = sprintf('$%.1fK', value / 1e3);
                    if isTickLabel
                        formattedStr = sprintf('$%.0fK', value / 1e3);
                    end
                else
                    formattedStr = sprintf('$%.0f', value);
                end
            else
                if isTickLabel
                    formattedStr = sprintf('$%.0f', value);
                else
                    formattedStr = sprintf('$%.2f', value);
                end
            end
            formattedStr = regexprep(formattedStr, '\.0([KM]$)', '$1');
        end
    end
end
