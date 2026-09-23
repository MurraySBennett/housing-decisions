function R = elicitAttrRatings(window, cfg, A, rngStream)
%UTILS.ELICITATTRRATINGS  Rate every attribute of one domain for importance.
%
%   R = utils.elicitAttrRatings(window, cfg, A, rngStream)
%
%   Value attribute is rated on the same line but never drives selection.
% R.pool drives utils.selectAttributes (rank only); R.core is the value
% attribute's stated weight. Pool ratings collected with price on the line
% are compressed -- rank-valid, not comparable to pre-change raw values.
% A.late is not rated: late attributes are design-chosen.

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
