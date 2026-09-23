function [inWindow, w] = applyWindow(stimuli, A, anchor, cfg)
%UTILS.APPLYWINDOW  Resolve the stimulus set a participant will see.
%
%   [inWindow, w] = utils.applyWindow(stimuli, A, anchor, cfg)
%
%   Strategy per domain is cfg.sampling.fitToWindow.(domain).

domain = lower(A.domain);
useFit = false;
if isfield(cfg.sampling, 'fitToWindow') && isfield(cfg.sampling.fitToWindow, domain)
    useFit = cfg.sampling.fitToWindow.(domain);
end

vals = stimuli.(A.valueVar);

if useFit
    w = utils.fitToWindow(vals, anchor, cfg.sampling.spread, cfg.sampling.minN);
    inWindow = stimuli(w.idx, :);
    % Fitted price must BE the value column; everything downstream reads it.
    inWindow.(A.valueVar) = w.fitted;
else
    w = utils.sampleWindow(vals, anchor, cfg.sampling.spread, cfg.sampling.minN);
    w.mode = 'window';
    w.fitted = vals(w.idx);
    w.priceMap = [vals(w.idx), vals(w.idx)];
    inWindow = stimuli(w.idx, :);
end

end
