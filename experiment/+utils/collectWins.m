function wins = collectWins(dataMat)
%UTILS.COLLECTWINS  Every successful acquisition, for the incentive draw.
%
%   Walks the saved data and returns one entry per trial where the
%   participant's bid cleared the threshold. utils.incentives('compute') draws
%   one of these at random.
%
%   Under the BDM rule the participant acquires at the THRESHOLD price, not
%   at their bid, so surplus does not depend on how much they bid -- only on
%   whether they chose to transact. That is what makes truthful bidding
%   optimal, and it is why pricePaid below is the threshold.

wins = struct('domain', {}, 'trial', {}, 'competition', {}, ...
              'stimIdx', {}, 'bid', {}, 'pricePaid', {}, ...
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
