function [inWindow, w] = applyWindow(stimuli, A, anchor, cfg)
%UTILS.APPLYWINDOW  Resolve the stimulus set a participant will see.
%
%   [inWindow, w] = utils.applyWindow(stimuli, A, anchor, cfg)
%
%   The single entry point for both strategies, because the two are not
%   interchangeable at the call site: utils.sampleWindow SELECTS rows and
%   leaves their values alone, while utils.fitToWindow keeps every row and
%   REWRITES the anchored value. Getting the second one right means
%   overwriting the value column in the returned table, and doing that by
%   hand in auction_task and continuous_DC_task is how the two drift apart.
%
%   Which strategy per domain is cfg.sampling.fitToWindow.(domain).

domain = lower(A.domain);
useFit = false;
if isfield(cfg.sampling, 'fitToWindow') && isfield(cfg.sampling.fitToWindow, domain)
    useFit = cfg.sampling.fitToWindow.(domain);
end

vals = stimuli.(A.valueVar);

if useFit
    w = utils.fitToWindow(vals, anchor, cfg.sampling.spread, cfg.sampling.minN);
    inWindow = stimuli(w.idx, :);
    % The rewrite. Everything downstream -- the cards, the pricing scale,
    % utils.marketThreshold, utils.buildPairs -- reads the value column, so
    % the fitted price has to BE the value column, not sit beside it.
    inWindow.(A.valueVar) = w.fitted;
else
    w = utils.sampleWindow(vals, anchor, cfg.sampling.spread, cfg.sampling.minN);
    w.mode = 'window';
    w.fitted = vals(w.idx);
    w.priceMap = [vals(w.idx), vals(w.idx)];
    inWindow = stimuli(w.idx, :);
end

end
