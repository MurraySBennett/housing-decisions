function g = geom(varargin)
%UTILS.GEOM  Screen geometry and visual-angle conversions.
%
%   g = utils.geom()                       defaults: 1920x1080, 24", 60 cm
%   g = utils.geom('diagonalIn', 27, 'viewingDistCm', 65)
%
%   Everything eye-tracking-related should be specified in DEGREES and
%   converted here, so that changing monitor or chair position doesn't
%   silently invalidate your AOI spacing.

p = inputParser;
p.addParameter('widthPx',       1920);
p.addParameter('heightPx',      1080);
p.addParameter('diagonalIn',    24);     % <-- CONFIRM against the lab monitor
p.addParameter('viewingDistCm', 60);     % <-- CONFIRM against the chinrest
p.parse(varargin{:});
g = p.Results;

% Physical width from diagonal + aspect ratio
aspect      = g.widthPx / g.heightPx;
diagCm      = g.diagonalIn * 2.54;
g.widthCm   = diagCm * aspect / sqrt(1 + aspect^2);
g.heightCm  = g.widthCm / aspect;
g.pxPerCm   = g.widthPx / g.widthCm;

% Pixels per degree of visual angle at the centre of the screen
g.pxPerDeg  = 2 * g.viewingDistCm * tand(0.5) * g.pxPerCm;

% Handy conversions
g.deg2px    = @(d) d * g.pxPerDeg;
g.px2deg    = @(px) px / g.pxPerDeg;

% --- AOI policy -------------------------------------------------------
% Tobii spec accuracy is ~0.5 deg; realistic in-session accuracy after
% drift is 1-1.5 deg. Anything closer together than minSepDeg cannot be
% reliably separated and should be merged into a single AOI.
g.minSepDeg     = 2.0;
g.targetSepDeg  = 3.0;
g.minSepPx      = round(g.deg2px(g.minSepDeg));
g.targetSepPx   = round(g.deg2px(g.targetSepDeg));

% Minimum sensible AOI size -- smaller than this and a single fixation
% blankets the whole region anyway.
g.minAOIDeg     = 1.5;
g.minAOIPx      = round(g.deg2px(g.minAOIDeg));

end
