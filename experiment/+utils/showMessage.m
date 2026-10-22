function onset = showMessage(window, cfg, msg, secs)
%UTILS.SHOWMESSAGE A centered message for a fixed number of seconds.
%
% Non-interactive: draws, flips, waits `secs`, returns the flip onset. The
% click-gated variants stay local to the tasks that use them (auction's
% showClickMessage, preference's showClickMessage with its timeout net) --
% they differ in real behaviour and must not be mistaken for each other.
s = cfg.style;
Screen('FillRect', window, s.bg);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeHeading);
DrawFormattedText(window, msg, 'center', 'center', s.text, 55, 0, 0, 1.6);
onset = Screen('Flip', window);
WaitSecs(secs);
end
