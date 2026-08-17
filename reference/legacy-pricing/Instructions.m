classdef Instructions
    properties
        window
        fg
        bg
        wrap_at
        flipH
        flipV
        vSpace
        font_size
        line_pos
        continue_pos
    end

    methods
        function inst = Instructions(window, fg, bg)
            inst.window = window;
            inst.fg = fg;
            inst.bg = bg;
            [screenX, screenY] = Screen('WindowSize', window);
            inst.wrap_at= (screenX * 0.12);
            inst.flipH  = [];
            inst.flipV  = [];
            inst.vSpace = 1.1; 
            inst.font_size = round(screenY * 0.03);
            inst.line_pos = screenY * 0.1;
            inst.continue_pos = screenY * 0.9;
        end

        function clear_screen(inst)
            Screen('FillRect', inst.window, inst.bg);
            Screen('Flip', inst.window);
        end

        function continue_msg(inst)
            msg = 'Click the left mouse button to continue.';
            Screen('TextSize', inst.window, inst.font_size);
            DrawFormattedText(...
                inst.window, msg, 'center', inst.continue_pos, inst.fg, inst.wrap_at,...
                inst.flipH, inst.flipV, inst.vSpace...
            );
            Screen('Flip', inst.window);
            inst.click_continue();
        end

        function click_continue(inst)
            response = 0;
            while response == 0
                [~, ~, buttons] = GetMouse;
                if buttons(1)
                    response = 1;
                end
            end
            WaitSecs(0.3);
        end

        function welcome(inst, min_wait_time)
            inst.clear_screen();
            greet   = 'Welcome!\n\n';
            ic      = 'Please complete the informed consent statement';
            progress= ', then click the left mouse button to begin the experiment.';
            msg     = [greet ic progress];

            Screen('TextSize', inst.window, inst.font_size);
            DrawFormattedText(...
                inst.window, msg, 'center', inst.line_pos, inst.fg, inst.wrap_at,...
                inst.flipH, inst.flipV, inst.vSpace...
            );
            % Flip screen, but 1 = 'DontClear' the screen for the 'continue message'
            Screen('Flip', inst.window, 0, 1);
            WaitSecs(min_wait_time);
            inst.continue_msg();
        end

        function task_description(inst, product, min_wait_time)
            inst.clear_screen();
            valid_products = {'house', 'job'};
            product = validatestring(product, valid_products);
            unit = 'price ($K)';
            framing = 'believe is a fair offer';
            if strcmpi(product, 'job')
                unit = 'wage ($/hr)';
                framing = 'would be willing to accept';
            end
            task_overview = sprintf([...
                'Imagine that you are on the hunt for a new %s!\n',...
                'You have narrowed down your search and are in the final stages of evaluating your options.\n',...
                'During this task, you will be shown sets of features for potential %ss.\n\n',...
                'The task is split into two parts where you will either:\n', ...
                '1) select between two options or,\n',...
                '2) provide a %s that you %s for that %s.'], ...
                product, product, unit, framing, product);

            Screen('TextSize', inst.window, inst.font_size);
            DrawFormattedText(...
                inst.window, task_overview, 'center', inst.line_pos, inst.fg, inst.wrap_at,...
                inst.flipH, inst.flipV, inst.vSpace...
            );
            Screen('Flip', inst.window, 0, 1);

            WaitSecs(min_wait_time);
            inst.continue_msg();
        end

        function practiceScaleResponse(inst, maxRange)
            findNum = round(rand*maxRange, 2);
            msg = sprintf('Enter $%d using the scale.\n(You do not need to be exact, just get close!)', findNum);
            screenRect = Screen('Rect', inst.window);
            Screen('TextSize', inst.window, inst.font_size);
            DrawFormattedText(inst.window, msg, 'center', screenRect(4) * 0.8, inst.fg, inst.wrap_at, ...
                inst.flipH, inst.flipV, inst.vSpace);
        end

        function block_break(inst, min_wait_time)
            inst.clear_screen();
            msg = 'End of Block.\n\nPlease take a short break before continuing.';
            Screen('TextSize', inst.window, inst.font_size);
            DrawFormattedText(...
                inst.window, msg, 'center', inst.line_pos, inst.fg, inst.wrap_at,...
                inst.flipH, inst.flipV, inst.vSpace);
            Screen('Flip', inst.window, 0, 1);
            WaitSecs(min_wait_time);
            inst.continue_msg();
        end



        function set_condition(inst, item_type, condition_type, min_wait_time)
            inst.clear_screen();
            % item_type will really only ever be: job or house
            plural = [item_type, 's'];
            if strcmp(item_type, 'job')
                unit = 'wage ($/hr)';
                framing = 'would be willing to accept';               
            elseif strcmp(item_type, 'house')
                unit = 'price ($K)';
                framing = 'believe is a fair offer';
            else
                disp('ERROR. See "Instructions.set_condition" and input either "job" or "house".')
            end

            if strcmp(condition_type, 'DC')
                condition_msg = [
                    'During this part of the experiment, you will see pairs of ', plural, ' that you are considering.\n',...
                    'Select the ', item_type, ' you would prefer by clicking the appropriate column of features.'];
            elseif strcmp(condition_type, 'CR')
                condition_msg = [...
                    'During this part of the experiment, you will see a single set of attributes for a potential ', item_type, '.\n', ...
                    'Your task is to indicate what ', unit, ' you ', framing, ' for a ', item_type, ' with those attributes.\n'...
                    'You will see a scale at the top of your screen, just like the one shown below.\n',...
                    'Click ON the scale to provide your answer.'
                    ];
                min_price = 20;
                max_price = 60;
                n_ticks = 10;
                scaled_size = 0.5;
                demo_scale = PricingScale(inst.window, min_price, max_price, n_ticks, inst.continue_pos, scaled_size, inst.fg, inst.bg);
                demo_scale.draw();
            end          
            
            practice_msg = ['We will now complete a few brief practice trials to help familiarise yourself with the trial format for this part of the experiment.'];
            
            txt = strjoin({condition_msg, practice_msg}, '\n\n');

            Screen('TextSize', inst.window, inst.font_size);
            DrawFormattedText(...
                inst.window, txt, 'center', inst.line_pos, inst.fg, inst.wrap_at,...
                inst.flipH, inst.flipV, inst.vSpace);
            Screen('Flip', inst.window, 0, 1);
            
            WaitSecs(min_wait_time);
            inst.continue_msg();
        end

        function end_practice(inst, min_wait_time)
            inst.clear_screen();
            msg = 'Great job!\n\nThis ends the practice trials.\nThe remaining trials may have different numbers of features, but you will respond in the same way.';
            Screen('TextSize', inst.window, inst.font_size);
            DrawFormattedText(...
                inst.window, msg, 'center', inst.line_pos, inst.fg, inst.wrap_at,...
                inst.flipH, inst.flipV, inst.vSpace);
            Screen('Flip', inst.window, 0, 1);
            WaitSecs(min_wait_time);
            inst.continue_msg();
        end

        function experiment_end(inst)
            inst.clear_screen();
            msg = 'End of the experiment.\n\nThank you for participating!\n\nPlease see the experimenter.\n\n(you can also press "Enter" to exit)';
            Screen('TextSize', inst.window, inst.font_size);
            DrawFormattedText(...
                inst.window, msg, 'center', inst.line_pos, inst.fg, inst.wrap_at,...
                inst.flipH, inst.flipV, inst.vSpace);
            Screen('Flip', inst.window);
            close_screen = 0;
            while close_screen == 0
                [~, ~, keyCode] = KbCheck;
                if keyCode(KbName('return'))
                    close_screen = 1;
                end
            end
        end
    end
end