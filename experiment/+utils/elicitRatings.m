function [ratings, rts, order, detail] = elicitRatings(window, cfg, items, prompt, anchors, rngStream)
%UTILS.ELICITRATINGS  Rate a set of items on one line, in whichever mode
%   cfg.elicit.ratingMode selects.
%
%   Only entry point task code should call; the two modes are not
%   interchangeable measurements (drag RT = time to first placement).
%   Ratings normalised 0-1 in item order; detail is [] in sequential mode.

if nargin < 6, rngStream = []; end

mode = 'drag';
if isfield(cfg, 'elicit') && isfield(cfg.elicit, 'ratingMode')
    mode = lower(char(cfg.elicit.ratingMode));
end

switch mode
    case 'drag'
        [ratings, rts, order, detail] = ...
            utils.elicitVASDrag(window, cfg, items, prompt, anchors, rngStream);

    case 'sequential'
        [ratings, rts, order] = ...
            utils.elicitVAS(window, cfg, items, prompt, anchors, rngStream);
        detail = [];

    otherwise
        error('hw:elicitRatings:badMode', ...
            ['Unknown cfg.elicit.ratingMode "%s". Expected ''drag'' or ' ...
             '''sequential''.'], mode);
end

end
