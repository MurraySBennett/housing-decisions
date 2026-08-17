function s = formatCurrency(val, style)
%UTILS.FORMATCURRENCY  Currency formatting that adapts to the domain.
%
%   utils.formatCurrency(425000)             -> '$425,000'
%   utils.formatCurrency(425000, 'compact')  -> '$425k'
%   utils.formatCurrency(23.5,   'hourly')   -> '$23.50/hr'
%
%   Replaces both formatCurrency() and the java.text.DecimalFormat-based
%   insertCommas(), which fails under -nojvm and on headless test runs.

if nargin < 2, style = 'total'; end
if isempty(val) || (isnumeric(val) && isnan(val)), s = '--'; return; end

switch lower(char(style))
    case 'hourly'
        s = sprintf('$%.2f/hr', val);

    case 'compact'
        % Ticks on the pricing scale: pick the unit from the magnitude
        % instead of hard-coding thousands. The current '$%.0fk' turns
        % every tick on the wage scale into '$0k'.
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
