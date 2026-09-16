function v = snapValue(v, priceStyle)
%UTILS.SNAPVALUE  Round a response to the resolution it is displayed at.
%
%   v = utils.snapValue(v, A.priceStyle)
%
%   Both price styles render whole dollars -- 'hourly' as '$24/hr' and
%   'total' as '$425,000' -- so a response carrying cents is precision the
%   participant never saw and could not have intended. Snapping here means
%   the number in the data file is exactly the number that was on screen
%   when they clicked.
%
%   This matters beyond tidiness: without it, a participant who reads
%   "$24/hr" on the arc has $23.63 recorded, and any analysis of rounding,
%   of clustering on salient values, or of the gap between a bid and a
%   threshold inherits an error nobody can see in the display.
%
%   Deliberately NOT applied to thresholds, true values or stimulus
%   attributes -- those are properties of the design, not responses, and
%   rounding them would distort the very quantities a bid is compared
%   against.
%
%   See also UTILS.FORMATCURRENCY.

if isempty(v) || ~isnumeric(v) || ~isfinite(v)
    return
end

switch lower(char(priceStyle))
    case 'hourly'
        v = round(v);

    case 'total'
        % House prices snap to the nearest THOUSAND, not the nearest
        % dollar. Nobody offers $347,213 for a house, the scale cannot
        % resolve a dollar anyway (the arc spans hundreds of thousands
        % across ~900 px), and a bid carrying three junk digits invites
        % analyses of clustering and rounding that are reading pixel noise.
        % Same argument as dropping cents from wages. 2026-09-16 pilot.
        v = round(v / 1000) * 1000;

    otherwise
        % Unknown style: leave it alone rather than guess a resolution.
end

end
