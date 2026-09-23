function g = geom(varargin)
%UTILS.GEOM  Screen geometry and visual-angle conversions.
%
%   g = utils.geom('diagonalIn', 27, 'viewingDistCm', 65)
%   Specify eye-tracking geometry in degrees and convert here only.

p = inputParser;
p.addParameter('widthPx',       1920);
p.addParameter('heightPx',      1080);
p.addParameter('diagonalIn',    24);     % <-- CONFIRM against the lab monitor
p.addParameter('viewingDistCm', 60);     % <-- CONFIRM against the chinrest
p.parse(varargin{:});
g = p.Results;

aspect      = g.widthPx / g.heightPx;
diagCm      = g.diagonalIn * 2.54;
g.widthCm   = diagCm * aspect / sqrt(1 + aspect^2);
g.heightCm  = g.widthCm / aspect;
g.pxPerCm   = g.widthPx / g.widthCm;

g.pxPerDeg  = 2 * g.viewingDistCm * tand(0.5) * g.pxPerCm;

g.deg2px    = @(d) d * g.pxPerDeg;
g.px2deg    = @(px) px / g.pxPerDeg;

% --- AOI policy -------------------------------------------------------
% In-session accuracy after drift is 1-1.5 deg; AOIs closer than minSepDeg cannot be separated.
g.minSepDeg     = 2.0;
g.targetSepDeg  = 3.0;
g.minSepPx      = round(g.deg2px(g.minSepDeg));
g.targetSepPx   = round(g.deg2px(g.targetSepDeg));

g.minAOIDeg     = 1.5;
g.minAOIPx      = round(g.deg2px(g.minAOIDeg));

end
