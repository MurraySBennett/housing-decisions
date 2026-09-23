function [threshold, trueValue] = marketThreshold(itemValue, competition, domain, cfg, rngStream)
%UTILS.MARKETTHRESHOLD  The price/wage the market will bear for one item.
%
%   [threshold, trueValue] = utils.marketThreshold(itemValue, competition, domain, cfg, rngStream)
%   Stochastic so competition changes the odds, not the guaranteed outcome.

if nargin < 5, rngStream = RandStream.getGlobalStream; end

trueValue = itemValue;
isHouse = strcmpi(domain, 'houses');

switch lower(competition)
    case 'high'
        % Jobs invert: the participant is selling, so more competition means employers offer less.
        mult = utils.ternary(isHouse, cfg.auction.compHigh, 1/cfg.auction.compHigh);
    case 'low'
        mult = utils.ternary(isHouse, cfg.auction.compLow, 1/cfg.auction.compLow);
    otherwise
        error('hw:marketThreshold:badLevel', 'Unknown competition level "%s".', competition);
end

noise = 1 + randn(rngStream) * cfg.auction.thresholdNoise;
noise = min(max(noise, 1 - 3*cfg.auction.thresholdNoise), ...
                    1 + 3*cfg.auction.thresholdNoise);

threshold = itemValue * mult * noise;

end
