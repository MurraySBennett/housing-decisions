function p = rigProfiles(name)
%UTILS.RIGPROFILES  Named hardware profiles for lab vs. dev/laptop testing.
%
%   'lab' is the source of truth for anything that ends up in a dataset;
%   'dev' relaxes AOI enforcement and eye tracking for off-rig layout work.

switch lower(char(name))

case 'lab'
    p.geomArgs = {'widthPx', 1920, 'heightPx', 1080, ...
                 'diagonalIn', 24, 'viewingDistCm', 60};
    p.etEnabledDefault  = true;
    p.aoiEnforcement    = 'strict';   % failures are warnings you should fix
    p.windowedDefault   = false;
    % Windows DWM routinely fails PTB's sync test with a hard OpenWindow
    % error; set false only if this machine is confirmed to pass it.
    p.skipSyncTests     = true;

case 'dev'
    % Generic 13-14 inch laptop; only needs to be roughly right.
    p.geomArgs = {'widthPx', 1440, 'heightPx', 900, ...
                 'diagonalIn', 13.3, 'viewingDistCm', 45};
    p.etEnabledDefault  = false;
    p.aoiEnforcement    = 'informational';
    p.windowedDefault   = true;
    p.skipSyncTests     = true;   % same rationale as 'lab'

otherwise
    error('hw:rigProfiles:unknown', ...
        'Unknown rig profile "%s". Use ''lab'' or ''dev''.', name);
end

p.name = lower(char(name));

end
