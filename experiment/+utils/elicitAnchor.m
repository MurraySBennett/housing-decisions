function [val, rt] = elicitAnchor(window, cfg, domain)
%UTILS.ELICITANCHOR  Collect the participant's budget or reservation wage.
%
%   This is the single biggest thing that was missing. Model addition #2 is
%   multiple anchors, and the participant's own budget (houses) or
%   reservation wage (jobs) IS the primary personal anchor. It also
%   determines which stimuli they see, via utils.sampleWindow -- without it,
%   the price ranges shown may be entirely irrelevant to them.

s = cfg.style;
isHouse = strcmpi(domain, 'houses');

if isHouse
    prompt = ['Before we begin.\n\n' ...
              'Imagine you are looking to buy a house.\n\n' ...
              'What is the most you could realistically spend?'];
    % No note about the comma grouping: the field does it live as they
    % type, which makes the explanation redundant the moment they press a
    % key. Pilot note, 2026-09-16.
    hint   = 'Type the digits and press ENTER.';
    lo = 50000; hi = 5000000;
else
    prompt = ['Before we begin.\n\n' ...
              'Imagine you are looking for a job.\n\n' ...
              'What is the lowest hourly wage you would accept?'];
    hint   = 'Type an amount and press ENTER.   e.g. 24';
    lo = 7; hi = 200;
end

str = '';
t0 = GetSecs;
ListenChar(2);
KbReleaseWait;

while true
    Screen('FillRect', window, s.bg);
    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeContent);
    scr = Screen('Rect', window);
    cx = scr(3)/2; cy = scr(4)/2;

    DrawFormattedText(window, prompt, 'center', cy - 200, s.text, 60, 0, 0, 1.6);

    box = [cx - 220, cy + 60, cx + 220, cy + 140];
    utils.roundRect(window, box, s.radiusPanel, s.bgPanel, ...
        s.interactive, s.borderWidthPx);

    % Grouped as they type. A bare "350000" is genuinely hard to read at
    % a glance, and this is the one field in the study where being an
    % order of magnitude out silently rescales every stimulus the
    % participant then sees, via utils.sampleWindow. Commas make a
    % mistyped zero visible at the moment it is typed.
    Screen('TextSize', window, s.sizeTitle);
    shown = ['$' groupDigits(str) '_'];
    b = Screen('TextBounds', window, shown);
    DrawFormattedText(window, shown, cx - b(3)/2, cy + 100 + b(4)/4, s.money);

    Screen('TextSize', window, s.sizeLabel);
    DrawFormattedText(window, hint, 'center', cy + 200, s.textDim);

    Screen('Flip', window);

    [~, keyCode] = KbStrokeWait;
    key = KbName(find(keyCode, 1));
    if iscell(key), key = key{1}; end

    if strcmp(key, 'q')
        ListenChar(0); sca;
        error('hw:userQuit', 'Experiment terminated by experimenter (q).');
    elseif any(strcmp(key, {'Return', 'Enter'}))
        val = str2double(str);
        if ~isnan(val) && val >= lo && val <= hi
            break
        end
        str = '';
        Screen('FillRect', window, s.bg);
        DrawFormattedText(window, sprintf('Please enter a value between %s and %s.', ...
            utils.formatCurrency(lo, 'compact'), utils.formatCurrency(hi, 'compact')), ...
            'center', 'center', s.rejected, 60, 0, 0, 1.5);
        Screen('Flip', window);
        WaitSecs(1.6);
    elseif any(strcmp(key, {'BackSpace', 'DELETE'}))
        if ~isempty(str), str(end) = []; end
    elseif numel(key) == 1 && any(key == '0123456789')
        if numel(str) < 9, str(end+1) = key; end %#ok<AGROW>
    elseif strncmp(key, '1!', 1) || ~isempty(regexp(key, '^\d', 'once'))
        d = regexp(key, '\d', 'match', 'once');
        if ~isempty(d) && numel(str) < 9, str(end+1) = d; end %#ok<AGROW>
    end
end

ListenChar(0);
rt = GetSecs - t0;

end


%% ======================================================================
function out = groupDigits(str)
%GROUPDIGITS  Thousands separators for a raw digit string.
%
%   '350000'  -> '350,000'
%   '1234567' -> '1,234,567'
%   '24'      -> '24'        (a no-op below four digits, so the same path
%                             serves hourly wages without special-casing)
%
%   Leading zeros are stripped first, so a stray keypress shows as
%   '350,000' rather than '0,350,000'.

out = regexprep(str, '^0+(?=\d)', '');
if isempty(out)
    out = str;
    return
end
out = regexprep(out, '(\d)(?=(\d{3})+$)', '$1,');

end
