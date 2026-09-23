function s = formatCurrency(val, style)
%UTILS.FORMATCURRENCY  Currency formatting that adapts to the domain.
%
%   utils.formatCurrency(425000, 'compact')  -> '$425k'; styles: total, compact, hourly.
%   No Java: must work under -nojvm and on headless test runs.

if nargin < 2, style = 'total'; end
if isempty(val) || (isnumeric(val) && isnan(val)), s = '--'; return; end

switch lower(char(style))
    case 'hourly'
        % Whole dollars; utils.snapValue rounds the response to match, so recorded == displayed.
        s = sprintf('$%.0f/hr', val);

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
