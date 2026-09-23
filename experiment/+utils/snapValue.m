function v = snapValue(v, priceStyle)
%UTILS.SNAPVALUE  Round a response to the resolution it is displayed at.
%
%   v = utils.snapValue(v, A.priceStyle)
%   Responses only -- never thresholds, true values or stimulus attributes.

if isempty(v) || ~isnumeric(v) || ~isfinite(v)
    return
end

switch lower(char(priceStyle))
    case 'hourly'
        v = round(v);

    case 'total'
        % Nearest thousand: the arc spans hundreds of thousands over ~900 px and cannot resolve a dollar.
        v = round(v / 1000) * 1000;

    otherwise
        % Unknown style: leave it alone rather than guess a resolution.
end

end
