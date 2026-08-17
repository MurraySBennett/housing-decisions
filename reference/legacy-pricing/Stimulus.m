classdef Stimulus
    properties
        window
        attributes
        shiftY
        startY
        endY
        locY
        fg
        bg
        size
        attributeTableBuffer
        leftColRect
        rightColRect
    end

    methods
        function s = Stimulus(window, attributes, shiftY, fg, bg)
            s.window        = window;
            s.attributes    = attributes;
            s.shiftY        = shiftY;
            [~, s.startY]   = RectCenter(Screen('Rect', window));
            s.endY          = s.startY * 2 * 0.9;
            s.startY        = s.startY + shiftY;
            s.locY          = round(linspace(s.startY, s.endY, size(attributes, 2) / 2));
            s.fg            = fg;
            s.bg            = bg;

            windowRect = Screen('Rect', window);
            s.attributeTableBuffer = Screen('OpenOffscreenWindow', window, [0 0 0 0], windowRect);
            Screen('BlendFunction', s.attributeTableBuffer, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
            [screenX, ~] = Screen('WindowSize', s.window);
            colClickWidth = round(screenX * 0.25);
            s.leftColRect = [...
                (screenX * 0.33) - (colClickWidth / 2), s.startY + s.shiftY, ...
                (screenX * 0.33) + (colClickWidth / 2), s.endY - s.shiftY];
            s.rightColRect = [...
                (screenX * 0.67) - (colClickWidth / 2), s.startY + shiftY, ...
                (screenX * 0.67) + (colClickWidth / 2), s.endY / 0.9];
             % border to demonstrate response area
            % Screen('FrameRect', s.attributeTableBuffer, [255 0 0 100], s.leftColRect, 2);
            % Screen('FrameRect', s.attributeTableBuffer, [0 0 255 100], s.rightColRect, 2);
        end

        function [is_left_col, is_right_col] = checkColumnClick(s, x, y)
            is_left_col = IsInRect(x, y, s.leftColRect);
            is_right_col = IsInRect(x, y, s.rightColRect);
        end

        function drawToBuffer(s, n_items, n_attrs, labels, trial_idx)
            Screen('FillRect', s.attributeTableBuffer, [0, 0, 0, 255]);
            Screen('TextSize', s.attributeTableBuffer, round(s.startY * 0.08));
           
            [screenX, ~] = Screen('WindowSize', s.window);
            centerX = round(screenX * 0.5);
            
            trial_attributes = s.attributes(trial_idx, :);
            
            if n_items == 1
                id_single = 1:n_attrs;
                for i = 1:n_attrs
                    attr_single = trial_attributes(id_single(i));
                    if rem(attr_single, 1) == 0
                        DrawFormattedText(s.attributeTableBuffer, sprintf('%s\n%.0f', labels(i), attr_single), 'center', s.locY(i), s.fg, [], [], [], [], [], [centerX, s.locY(i), centerX, s.locY(i)]);
                    else
                        DrawFormattedText(s.attributeTableBuffer, sprintf('%s\n%.1f', labels(i), attr_single), 'center', s.locY(i), s.fg, [], [], [], [], [], [centerX, s.locY(i), centerX, s.locY(i)]);
                    end
                end
            else
                id_left  = 1:2:n_attrs;
                id_right = 2:2:n_attrs;
                leftX = round(screenX * 0.33);
                rightX= round(screenX * 0.67);
                for i = 1:n_attrs / 2
                    attr_left = trial_attributes(id_left(i));
                    attr_right= trial_attributes(id_right(i));
                    % attribute labels
                    DrawFormattedText(s.attributeTableBuffer, sprintf('%s', labels(i)), 'center', s.locY(i), s.fg, [], [], [], [], [], [centerX, s.locY(i), centerX, s.locY(i)]);
                    
                    % attribute values
                    if rem(attr_left, 1) == 0 && rem(attr_right, 1) == 0
                        DrawFormattedText(s.attributeTableBuffer, sprintf('\n%.0f', attr_left), 'left', s.locY(i), s.fg, [], [], [], [], [], [leftX, s.locY(i), leftX, s.locY(i)]);
                        DrawFormattedText(s.attributeTableBuffer, sprintf('\n%.0f', attr_right), 'right',s.locY(i), s.fg, [], [], [], [], [], [rightX, s.locY(i), rightX, s.locY(i)]);
                    else
                        DrawFormattedText(s.attributeTableBuffer, sprintf('\n%.1f', attr_left), 'left', s.locY(i), s.fg, [], [], [], [], [], [leftX, s.locY(i), leftX, s.locY(i)]);
                        DrawFormattedText(s.attributeTableBuffer, sprintf('\n%.1f', attr_right), 'right',s.locY(i), s.fg, [], [], [], [], [], [rightX, s.locY(i), rightX, s.locY(i)]);
                    end

                end
            end
        end


        function draw(s)
            Screen('DrawTexture', s.window, s.attributeTableBuffer, [], Screen('Rect', s.window));
        end


        function [clicked, duration] = proceed(s, t0, timeout)
            clicked = 0;
            duration = -999;
            while clicked == 0
                [~, ~, buttons] = GetMouse;
                timer = GetSecs - t0;
                if buttons(1)
                    duration = timer;
                    clicked = 1;
                end
                if timer > timeout
                    clicked = -1;
                    duration = timer; 
                end
            end
        end
    end
end