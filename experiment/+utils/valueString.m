function str = valueString(stimTbl, attr, idx)
%UTILS.VALUESTRING  One attribute's value, formatted for display.

v = stimTbl.(attr.var)(idx);
if iscell(v), v = v{1}; end
switch attr.kind
    case {'currency', 'total'}
        str = utils.formatCurrency(v, 'total');
    case 'hourly'
        str = utils.formatCurrency(v, 'hourly');
    case 'rating'
        str = sprintf('%.1f / 5', v);
    case 'count'
        str = sprintf('%g', v);
    case 'year'
        str = sprintf('%d', round(v));
    case 'number'
        str = sprintf('%.4g', v);
    case 'category'
        str = char(string(v));
    otherwise
        str = char(string(v));
end
end
