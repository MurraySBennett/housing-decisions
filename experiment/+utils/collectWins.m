function wins = collectWins(dataMat)
%UTILS.COLLECTWINS  Every successful acquisition, for the incentive draw.
%
%   One entry per accepted bid; utils.incentives('compute') draws one at random.
%   Under BDM pricePaid is the threshold, not the bid.

wins = struct('domain', {}, 'trial', {}, 'competition', {}, ...
              'stimIdx', {}, 'bid', {}, 'pricePaid', {}, 'anchor', {}, ...
              'trueValue', {}, 'reservationWage', {}, 'wageObtained', {});

if ~isfield(dataMat, 'domains'), return; end

for d = 1:numel(dataMat.domains)
    dom = dataMat.domains{d};
    if ~isfield(dataMat, dom) || ~isfield(dataMat.(dom), 'trials'), continue; end
    T = dataMat.(dom).trials;

    for t = 1:numel(T)
        if isempty(T(t).bidAccepted) || ~T(t).bidAccepted, continue; end

        w = struct();
        w.domain      = dom;
        w.trial       = t;
        w.competition = T(t).competition;
        w.stimIdx     = T(t).bidStimIdx;
        w.bid         = T(t).bid;
        w.pricePaid   = T(t).pricePaid;
        % Surplus is only interpretable relative to the anchor -- see utils.incentives.
        w.anchor      = dataMat.(dom).anchor;

        if strcmpi(dom, 'houses')
            w.trueValue       = T(t).trueValue;
            w.reservationWage = NaN;
            w.wageObtained    = NaN;
        else
            w.trueValue       = NaN;
            w.reservationWage = dataMat.(dom).reservationWage;
            w.wageObtained    = T(t).pricePaid;
        end
        wins(end+1) = w; %#ok<AGROW>
    end
end

end
