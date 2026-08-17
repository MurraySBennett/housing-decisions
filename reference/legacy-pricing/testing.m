

close all;
clear;
PsychDefaultSetup(2);
screens = Screen('Screens');
screenNumber = max(screens);
Screen('Preference', 'TextAntiAliasing', 2); 

colours.white = WhiteIndex(screenNumber);
colours.black = BlackIndex(screenNumber);
colours.grey  = colours.white / 2;
colours.fg    = colours.white;
colours.bg    = colours.black;

startXpix = 100;
startYpix = 100;
dimX = 600;
dimY = 400;

run_fullscreen = false;


if run_fullscreen
    [window, windowRect] = PsychImaging('OpenWindow', screenNumber, colours.bg);
else
    [window, windowRect] = PsychImaging('OpenWindow', screenNumber, colours.bg, [startXpix, startYpix, startXpix+dimX, startYpix+dimY], [], [], [], [], [], kPsychGUIWindow);
end

Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');


ifi = Screen('GetFlipInterval', window);
topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);
vbl = Screen('Flip', window);

% test content
minPrice = 20;
maxPrice = 80;
nMajorTicks = 10;
[centerX, centerY] = RectCenter(windowRect);

instructions = Instructions(window, colours.fg, colours.bg);

yShift = -(centerY * 0.2);
instruction_wait_time = 0.5;
condition_change_break_time = 0.5;

interactive_cue = false;
trial_timeout = 5;
cue_duration = 0.5;
isi_duration = 0.5;
clear_isi_screen = true;



response_conditions = {'DC'};%, 'CR'};
n_conditions = length(response_conditions);


% between subjects? Surely.
item_conditions = {'job', 'house'};
item_condition = item_conditions{randi(2)};
item_condition = 'job';


if strcmp(item_condition, "job")
    stimuli_file_name = ['stimuli', filesep, 'job_stimuli.csv'];
    stimuli_csv = readtable(stimuli_file_name);

    stimuli_csv = stimuli_csv(strcmpi(stimuli_csv.industry, "agriculture"), :);
    attribute_columns = ["workLife", "culture", "compensationBenefits", "jobSecurityAdvancement", "management"];
    attribute_labels = ["Work-Life Balance", "Culture", "Compensation & Benefits", "Job Security & Advancement", "Management"];
    
    cr_stimuli = stimuli_csv(:, attribute_columns);

    jobs1 = stimuli_csv(stimuli_csv.company==1, attribute_columns);
    jobs2 = stimuli_csv(stimuli_csv.company==2, attribute_columns);
    jobs1.Properties.VariableNames = attribute_columns+"1";
    jobs2.Properties.VariableNames = attribute_columns+"2";

    dc_stimuli = [jobs1, jobs2];

else
    stimuli_file_name = ['stimuli', filesep, 'house_stimuli.csv'];
    stimuli_csv = readtable(stimuli_file_name);

    % attribute_columns = [""];
    % attribute_lables = [""];
    % experiment_stimuli = 
end

attribute_levels = round(linspace(2, length(attribute_labels), 2)) * 2; %[2, 4, 8] * 2; % per item ( so *2 for 2 items...)
n_blocks = length(attribute_levels);
trials_per_block = 1;
n_practice_trials = 1;


all_trial_attributes = randi(...
    100, ...
    trials_per_block * n_blocks,...
    max(attribute_levels) ...
);
practice_trial_attributes = randi(100, n_practice_trials, min(attribute_levels));

% shuffle
% all_trial_attributes = T(randperm(size(all_trial_attributes_raw,1)), :)

trial   = Trial(window, yShift, colours.fg, colours.bg);

global_trial_idx = 0;


instructions.welcome(instruction_wait_time);
instructions.task_description(item_condition, instruction_wait_time / 2);


for condition_no = 1:length(response_conditions)
    response_mode   = response_conditions{condition_no};
    if strcmpi(response_mode, "DC")
        n_items = 2; %columns of data to show
        n_practice_attrs = length(practice_trial_attributes);
        % init with full attribute list to 'hack' the practice presentation spacing.
        stimuli = Stimulus(window, dc_stimuli{:,:}, yShift, colours.fg, colours.bg);
        practiceStimuli = Stimulus(window, dc_stimuli{:,:}, yShift, colours.fg, colours.bg);
        % practiceStimuli.attributes = practice_trial_attributes;

    else
        n_items = 1;
        n_practice_attrs = length(practice_trial_attributes) / 2;
        stimuli = Stimulus(window, cr_stimuli{:,:}, yShift, colours.fg, colours.bg);
        practiceStimuli = Stimulus(window, cr_stimuli{:,:}, yShift, colours.fg, colours.bg);

    end
    instructions.set_condition(item_condition, response_conditions{condition_no}, condition_change_break_time);
    

    % practice trials
    if strcmpi(item_conditions, "job")
        minScalePrice = 0;
        maxScalePrice = 1e3;
    else
        minScalePrice = 0;
        maxScalePrice = 1e6;
    end

    
    for trial_no = 1:n_practice_trials

        practiceStimuli.drawToBuffer(n_items, n_practice_attrs, attribute_labels, trial_no);
        dynamicTextRect = []; 
        if strcmpi(response_mode, 'CR')
            scale   = PricingScale(window, minScalePrice, randi(maxScalePrice), nMajorTicks, centerY, 1, colours.fg, colours.bg);
            dynamicTextRect = scale.getDynamicTextRect();
        end

        trial.cue(interactive_cue, cue_duration);
        trial.isi(isi_duration, clear_isi_screen);
       
        clicked = 0;
        response_start_time = GetSecs;
        response_value = -1;

        while clicked == 0
            [keyDown, ~, keyCode] = KbCheck;
            if keyDown && keyCode(KbName('q'))
                break;
            end
            Screen('FillRect', window, colours.bg);
            practiceStimuli.draw();

            [xMouse, yMouse, buttons] = GetMouse(window);            
            if strcmpi(response_mode, 'CR')
                scale.draw()
                Screen('FillRect', window, colours.bg, dynamicTextRect);
                [current_response_value, is_at_scale] = scale.calculateMouseResponse(xMouse, yMouse);
                if is_at_scale
                    response_value = current_response_value;
                    if any(buttons) && buttons(1) == 1
                        duration = GetSecs - response_start_time;
                        clicked = 1;
                    end
                else 
                    response_value = -1;
                end
                scale.drawDynamicText(response_value);


            elseif strcmpi(response_mode, 'DC')
                [is_left_col, is_right_col] = stimuli.checkColumnClick(xMouse, yMouse);
                if is_left_col
                    Screen('FrameRect', window, [40 40 40], stimuli.leftColRect, 3);
                elseif is_right_col
                    Screen('FrameRect', window, [40 40 40], stimuli.rightColRect, 3);
                end
                if any(buttons) && buttons(1) == 1
                    if is_left_col
                        response_value = 0;
                        duration = GetSecs - response_start_time;
                        clicked=1;
                    elseif is_right_col
                        response_value = 1;
                        duration = GetSecs - response_start_time;
                        clicked = 1;
                    end
                end
            end
            if GetSecs - response_start_time > trial_timeout
                clicked=-1;
                duration = GetSecs - response_start_time;
            end
            Screen('Flip', window);
        end
    end
    instructions.end_practice(instruction_wait_time / 2);



    for block_no = 1:n_blocks
        % number of attributes to be shown
        n_attributes = attribute_levels(block_no);
        if n_items == 1
            n_attributes = n_attributes / 2;
        end

        block_trial_idx = 0;
        for trial_no = 1:trials_per_block     
            block_trial_idx = block_trial_idx + 1;
            trial.cue(interactive_cue, cue_duration);
            trial.isi(isi_duration, clear_isi_screen);
            
            stimuli.drawToBuffer(n_items, n_attributes, attribute_labels, block_trial_idx); % change to trial_no??
            if strcmpi(response_mode, 'CR')
                minScalePrice = 0;
                maxScalePrice = randi(100);
                scale   = PricingScale(window, minScalePrice, maxScalePrice, nMajorTicks, centerY, 1, colours.fg, colours.bg);
            end

            clicked = 0;
            response_start_time = GetSecs;
            response_value = -1;
            
            while clicked == 0
                [keyDown, ~, keyCode] = KbCheck;
                if keyDown && keyCode('q')
                    break;
                end
                Screen('FillRect', window, colours.bg);
                stimuli.draw();

                [xMouse, yMouse, buttons] = GetMouse(window);
                if strcmpi(response_mode, 'CR')
                    scale.draw();
                    [current_response_value, is_at_scale] = scale.calculateMouseResponse(xMouse, yMouse);
                    if is_at_scale
                        response_value = current_response_value;
                        if any(buttons) && buttons(1) == 1
                            duration = GetSecs - response_start_time;
                            clicked = 1;
                        end
                    else 
                        response_value = -1;
                    end
                    scale.drawDynamicText(response_value);

                elseif strcmpi(response_mode, 'DC')
                    [is_left_col, is_right_col] = stimuli.checkColumnClick(xMouse, yMouse);
                    if is_left_col
                        Screen('FrameRect', window, [40 40 40], stimuli.leftColRect, 3);
                    elseif is_right_col
                        Screen('FrameRect', window, [40 40 40], stimuli.rightColRect, 3);
                    end
                    if any(buttons) && buttons(1) == 1
                        if is_left_col
                            response_value = 0;
                            duration = GetSecs - response_start_time;
                            clicked=1;
                        elseif is_right_col
                            response_value = 1;
                            duration = GetSecs - response_start_time;
                            clicked = 1;
                        end
                    end
                end
                Screen('Flip', window);
                if GetSecs - response_start_time > trial_timeout
                    clicked=-1;
                    duration = GetSecs - response_start_time;
                end
            end
            
            fprintf('Block %d: , Trial %d: Response: %.2f, Duration: %.3f seconds\n', block_no, trial_no, response_value, duration);
            if trial_no == trials_per_block
                if block_no == n_blocks
                    if condition_no == n_conditions
                        instructions.experiment_end();
                    end
                else
                    instructions.block_break(instruction_wait_time);
                end
            else
                trial.isi(0.5, clear_isi_screen);
            end

        end

    end

end


Priority(0);

sca;

%% functions
