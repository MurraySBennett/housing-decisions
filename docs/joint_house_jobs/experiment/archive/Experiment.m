
classdef Experiment
    properties
        Participant
        AttributesList
        EyeTracker
        window
        screenNumber
        white
        black
    end

    methods 
        function exp = Experiment(ParticipantNo, AttributesList, EyeTrackerStatus)
            exp.Participant     = ParticipantNo;
            exp.AttributesList  = AttributesList;
            exp.EyeTracker      = EyeTrackerStatus;

            PsychDefaultSetup(2);
            Screen('Preference', 'SkipSyncTests', 1);
            exp.screenNumber= max(Screen('Screens'));
            [exp.window, ~] = PsychImaging('OpenWindow', exp.screenNumber, 0);
            exp.white       = WhiteIndex(exp.screenNumber);
            exp.black       = BlackIndex(exp.screenNumber);
            exp.gray        = exp.white / 2;

        end

        function run(exp)
            Screen('TextSize', exp.window, 28);
            DrawFormattedText(exp.window, "Welcome! Press any key to start", "center", "center", exp.white);
            Screen('Flip', exp.window);
            KbStrokeWait;

            numTrials   = 2;
            numBlocks   = 2;
            nAttrs      = [4, 10, 20];

            for block = 1:numBlocks
                for trial = 1:numTrials
                    numAttrs = nAttrs(randi(length(nAttrs)));
                    stimulus = Stimulus(exp.window, exp.white, exp.gray, numAttrs);
                    priceScale = PricingScale(exp.window, exp.white);

                    WaitSecs(1); 

                    priceScale.draw();
                    stimulus.draw();
                    Screen('Flip', exp.window);

                    response = Response();
                    response.collect();

                end
                WaitSecs(2)
            end

            exp.endExperiment();
        end

        function endExperiment()
            sca;
        end
    end
end





