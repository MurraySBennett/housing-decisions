function s = formatCurrency(val, style)
%UTILS.FORMATCURRENCY  Currency formatting that adapts to the domain.
%
%   utils.formatCurrency(425000, 'compact')  -> '$425k'; styles: total, compact, hourly.
%   No Java: must work under -nojvm and on headless test runs.

if nargin < 2, style = 'total'; end
if isempty(val) || (isnumeric(val) && isnan(val)), s = '--'; return; end

switch lower(char(style))
    case 'hourly'
        % Cents, not whole dollars; utils.snapValue rounds the response to match,
        % so recorded == displayed.
        %
        % This was '$%.0f/hr'. Whole dollars were fine while jobs selected real
        % in-window wages off a 12-level grid, but cfg.sampling.fitToWindow.jobs
        % now rank-fits all 64 post-industry stimuli onto the participant's
        % window, which at a low anchor places them ~1.6% apart. At a $11.60
        % anchor that collapsed 34 distinct wages onto 13 displayed values, with
        % ten different jobs all reading "$8/hr" -- and buildPairs selects pairs
        % on the underlying continuous contrast, so it would pick a pair it
        % scores as a large money gap while the participant saw the same number
        % on both cards. In a study about attention to the monetary versus the
        % qualitative dimensions, that deletes the manipulation on exactly the
        % trials it matters most. Two decimals restore all 34 at every anchor.
        s = sprintf('$%.2f/hr', val);

    case 'compact'
        % Scale ticks: unit chosen from magnitude, not hard-coded thousands.
        a = abs(val);
        if a >= 1e6
            s = sprintf('$%.1fM', val/1e6);
            s = strrep(s, '.0M', 'M');
        elseif a >= 1e3
            s = sprintf('$%.0fk', val/1e3);
        elseif a >= 10 || val == 0
            s = sprintf('$%.0f', val);
        else
            s = sprintf('$%.1f', val);
        end

    otherwise % 'total'
        s = ['$' regexprep(sprintf('%.0f', val), '(\d)(?=(\d{3})+(?!\d))', '$1,')];
end

end
