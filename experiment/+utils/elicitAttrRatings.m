function R = elicitAttrRatings(window, cfg, A, rngStream)
%UTILS.ELICITATTRRATINGS  Rate every attribute of one domain for importance.
%
%   R = utils.elicitAttrRatings(window, cfg, A, rngStream)
%
%   A is the struct from utils.attributes. The VALUE attribute -- listed
%   price for houses, offered wage for jobs -- is rated on the SAME line as
%   the pool attributes and in the same randomised order, but its rating is
%   deliberately NOT used to decide what gets shown. It cannot be: the value
%   attribute is in A.core, so it appears on every card at every attribute
%   level no matter what the participant said about it. Rating it anyway is
%   the only way to get a stated weight for price on the same scale as
%   everything else, which is what you need to compare stated against
%   revealed weight for the single attribute the pricing model turns on.
%
%   Returns
%     R.labels   1 x (nCore+nPool) attribute labels, core first
%     R.all      ratings 0-1 in that order
%     R.allRTs   response times in that order
%     R.core     1 x nCore  ratings for the always-shown value attribute(s)
%     R.coreRTs
%     R.pool     1 x nPool  the ratings that drive utils.selectAttributes
%     R.poolRTs
%     R.order    presentation order actually used
%
%   ANALYSIS CAUTION. Adding price to the line changes the pool ratings
%   themselves: most participants put price at or near the "extremely
%   important" end, which compresses everything else into the rest of the
%   scale. Pool ratings collected this way are therefore NOT on the same
%   scale as pool ratings collected before this change -- they are still
%   fine for the rank-based selection in utils.selectAttributes, which only
%   reads their order, but do not pool the raw values across that boundary.
%
%   A.late is NOT rated. Late attributes are shown only at the top
%   attribute level and are chosen by the design, not by the participant's
%   ratings, so rating them would collect a number nothing reads. If you
%   want stated weights for them too, append {A.late.label} below and split
%   the result the same way.

if nargin < 4, rngStream = []; end

labels = [{A.core.label}, {A.pool.label}];

[ratings, rts, order, detail] = utils.elicitRatings(window, cfg, labels, ...
    'How important is each of these to you?', ...
    {'Entirely unimportant', 'Extremely important'}, rngStream);

nC = A.nCore;

R.labels  = labels;
R.all     = ratings;
R.allRTs  = rts;
R.core    = ratings(1:nC);
R.coreRTs = rts(1:nC);
R.pool    = ratings(nC+1:end);
R.poolRTs = rts(nC+1:end);
R.order   = order;
R.detail  = detail;    % [] in sequential mode; drag diagnostics otherwise

end
