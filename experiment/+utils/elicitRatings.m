function [ratings, rts, order, detail] = elicitRatings(window, cfg, items, prompt, anchors, rngStream)
%UTILS.ELICITRATINGS  Rate a set of items on one line, in whichever mode
%   cfg.elicit.ratingMode selects.
%
%   This is the only entry point task code should call. The two
%   implementations behind it are NOT interchangeable measurements even
%   though they share a signature:
%
%     'drag'        utils.elicitVASDrag -- the whole set is visible from the
%                   first frame and dragged onto the line in any order,
%                   adjustable until the participant clicks Done. Fixes the
%                   calibration problem in 'sequential' (the first item is
%                   placed before its comparators have been seen) at the
%                   cost of being closer to a ranking, and of per-item RT
%                   meaning "time to first placement" rather than "time to
%                   decide".
%
%     'sequential'  utils.elicitVAS -- one item at a time in random order,
%                   previous marks left visible. The original. Keep it
%                   reachable: it is the fallback if drag-and-drop turns
%                   out to be fiddly on the rig, and it is what any
%                   already-collected ratings were measured with.
%
%   Ratings are normalised 0-1 in the order of `items` either way.
%   `detail` is [] in sequential mode.

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
