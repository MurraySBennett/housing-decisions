function checkForQuit()
%UTILS.CHECKFORQUIT  Experimenter abort (q). Restores the keyboard first.

[keyIsDown, ~, keyCode] = KbCheck;
if keyIsDown && keyCode(KbName('q'))
    ListenChar(0);
    ShowCursor;
    sca;
    error('hw:userQuit', 'Experiment terminated by experimenter (q).');
end

end
