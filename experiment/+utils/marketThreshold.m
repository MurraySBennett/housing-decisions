function [threshold, trueValue] = marketThreshold(itemValue, competition, domain, cfg, rngStream)
%UTILS.MARKETTHRESHOLD  The price/wage the market will bear for one item.
%
%   Two changes from the old rule, both of which matter.
%
%   1. STOCHASTIC. The old rule was deterministic: threshold = value * 1.1
%      under high competition and value * 0.9 under low. With surplus
%      measured against value, that made surplus ALWAYS negative under high
%      competition -- participants could never earn a bonus in half the
%      blocks, would work that out quickly, and disengage. Competition
%      would have become an earnings manipulation. Adding noise means a
%      favourable draw can still pay off, so competition changes the odds
%      rather than guaranteeing the outcome.
%
%   2. DIRECTION. The old code applied the buyer rule to both domains. For
%      jobs the participant is selling their labour, so a HIGHER ask is
%      harder to get accepted, and more competition means the employer
%      offers LESS. The multiplier has to invert.

if nargin < 5, rngStream = RandStream.getGlobalStream; end

trueValue = itemValue;
isHouse = strcmpi(domain, 'houses');

switch lower(competition)
    case 'high'
        % Houses: more rival buyers, sellers hold out for more.
        % Jobs: more rival applicants, employers offer less.
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
