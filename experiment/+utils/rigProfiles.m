function p = rigProfiles(name)
%UTILS.RIGPROFILES  Named hardware profiles for lab vs. dev/laptop testing.
%
%   p = utils.rigProfiles('lab')
%   p = utils.rigProfiles('dev')
%
%   The AOI thresholds in utils.geom are defined in DEGREES, not pixels, so
%   switching profiles automatically rescales what counts as "too close"
%   for whatever screen you're actually on -- you don't need a second set
%   of spacing rules, just accurate physical numbers for the rig in use.
%
%   'lab' is the source of truth for anything that ends up in a dataset.
%   'dev' is for working on layout and logic away from the lab machine: eye
%   tracking off by default, AOI failures downgraded to informational, and
%   a generic laptop geometry so numbers are still sane rather than
%   nonsensical.

switch lower(char(name))

case 'lab'
    p.geomArgs = {'widthPx', 1920, 'heightPx', 1080, ...
                 'diagonalIn', 24, 'viewingDistCm', 60};
    p.etEnabledDefault  = true;
    p.aoiEnforcement    = 'strict';   % failures are warnings you should fix
    p.windowedDefault   = false;
    % Windows 10/11 + DWM compositor routinely fails PTB's sync test
    % outright (a hard OpenWindow error, not a warning) regardless of
    % whether real data is being collected. This is a documented PTB/OS
    % limitation, not something wrong with this rig specifically -- set to
    % false only if this exact machine has been independently confirmed
    % to pass Screen('Preference','SkipSyncTests', 0).
    p.skipSyncTests     = true;

case 'dev'
    % A generic 13-14" laptop at typical desk distance. Update if your
    % laptop differs -- it only needs to be roughly right, since it's never
    % the rig that produces analyzable data.
    p.geomArgs = {'widthPx', 1440, 'heightPx', 900, ...
                 'diagonalIn', 13.3, 'viewingDistCm', 45};
    p.etEnabledDefault  = false;
    p.aoiEnforcement    = 'informational';
    p.windowedDefault   = true;
    p.skipSyncTests     = true;   % same rationale as 'lab' -- laptops are worse, not better

otherwise
    error('hw:rigProfiles:unknown', ...
        'Unknown rig profile "%s". Use ''lab'' or ''dev''.', name);
end

p.name = lower(char(name));

end
