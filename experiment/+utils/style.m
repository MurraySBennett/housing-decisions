function s = style(themeName)
%UTILS.STYLE  Visual theme, constrained by eye-tracking needs.
%
%   s = utils.style()            % theme from $HW_THEME, else the default
%   s = utils.style('arcade')    % explicit

if nargin < 1 || isempty(themeName)
    themeName = getenv('HW_THEME');
end
if isempty(themeName)
    themeName = 'warm';
end
s.themeName = lower(char(themeName));

% Colors are normalized 0.0-1.0, NOT 0-255: PsychDefaultSetup(2) makes any
% 0-255 color clamp to solid white.
c255 = @(r,g,b) [r g b] / 255;

switch s.themeName

case 'warm'
    % --- Palette ------------------------------------------------------
    % The ground stays dark: a light ground floors the pupil and forfeits
    % pupillometry. Text colors clear WCAG 4.5:1 against s.bg; stroke and
    % marker colors clear 3:1.
    s.bg          = c255( 46,  42,  46);   % #2E2A2E  warm charcoal-plum
    s.bgPanel     = c255( 58,  53,  64);   % #3A3540  soft raised mauve-grey

    s.text        = c255(240, 234, 230);   % #F0EAE6  warm off-white  12.4:1
    s.textDim     = c255(180, 168, 164);   % #B4A8A4  warm grey        6.1:1

    s.interactive = c255(217, 137, 155);   % #D9899B  dusty rose       6.2:1
    s.money       = c255(227, 181, 140);   % #E3B58C  soft apricot     8.3:1
    s.accepted    = c255(143, 201, 160);   % #8FC9A0  soft sage        9.4:1
    s.rejected    = c255(224, 138, 138);   % #E08A8A  soft rose-red    6.6:1

    % Functional strokes the participant must read use s.track; the softer
    % weights are decorative chrome only.
    s.border       = c255( 74,  66,  76);  % #4A424C  1.4:1  panel edges
    s.borderStrong = c255(107,  98, 112);  % #6B6270  2.4:1  progress bar, hit ring
    s.track        = c255(138, 128, 144);  % #8A8090  4.1:1  price arc, VAS line

    % Calibration target takes maximum contrast, not the accent color.
    s.target       = s.text;               % 12.4:1

    % Marker must stay distinct from response (money) and control (interactive).
    s.marker       = c255(126, 186, 181);  % #7EBAB5  muted teal   7.2:1

    % --- Typography ---------------------------------------------------
    s.fontChrome    = 'Segoe UI';   % chrome now differs by size, not family
    s.fontChromeAlt = 'Verdana';
    s.fontContent   = 'Segoe UI';

    % Probed by utils.resolveFonts; upgraded to the first installed family.
    s.fontContentPref = {'Corbel', 'Segoe UI', 'Verdana', 'Arial'};
    s.fontChromePref  = {'Segoe UI Semibold', 'Segoe UI', 'Verdana', 'Arial'};

    % --- Shape --------------------------------------------------------
    s.borderWidthPx = 2;
    s.hairlinePx    = 1;

    % Radius tokens for utils.roundRect; setting all three to 0 restores
    % square corners exactly.
    s.radiusPanel = 18;     % cards, option tiles, buttons, HUD, input box
    s.radiusCell  = 10;     % attribute cells
    s.radiusPill  = 9999;   % progress bar; clamped to half-height = a pill

    s.hudUppercase = false;

case 'arcade'
    % The original theme, verbatim; the rollback target. Do not modify.
    % Mid-grey rather than black to preserve pupillometry.
    s.bg          = c255( 42,  46,  54);
    s.bgPanel     = c255( 28,  31,  38);
    s.text        = c255(232, 234, 240);
    s.textDim     = c255(150, 156, 170);

    s.interactive = c255( 92, 214, 232);   % cyan  -- anything clickable
    s.money       = c255(246, 190,  84);   % amber -- prices, wages, value
    s.accepted    = c255(126, 217, 130);   % green
    s.rejected    = c255(232, 106, 106);   % red
    s.border      = c255( 78,  86, 104);

    % Aliases predate the three-weight split; shared call sites keep working.
    s.borderStrong = s.border;
    s.track        = s.border;
    s.target       = s.interactive;
    s.marker       = c255(126, 217, 130);  % green, distinct from cyan/amber

    % Pixel font for chrome only; reading time is a dependent variable.
    s.fontChrome    = 'Press Start 2P';
    s.fontChromeAlt = 'Courier New';    % fallback if not installed
    s.fontContent   = 'Helvetica';

    s.fontContentPref = {'Helvetica', 'Arial'};
    s.fontChromePref  = {'Press Start 2P', 'Courier New', 'Courier'};

    s.borderWidthPx = 4;
    s.hairlinePx    = 2;

    s.radiusPanel = 0;
    s.radiusCell  = 0;
    s.radiusPill  = 0;

    s.hudUppercase = true;

otherwise
    error('hw:style:unknownTheme', ...
        ['Unknown HW_THEME "%s". Valid themes are ''warm'' and ''arcade''. ' ...
         'Clear it with setenv(''HW_THEME'','''').'], s.themeName);
end


%% ======================================================================
%  Shared by every theme -- deliberately outside the switch.
%  ======================================================================
%  Nothing below may differ between themes: these values feed AOI rects,
%  and preflight.m re-implements them by hand.

% Legacy name; kept so old callers do not error.
s.cornerRadius = s.radiusPanel;

% Color is never the only carrier of state; every color-coded state also
% gets a text label or an icon.
s.colourIsRedundant = true;

% --- Type sizes (geometric: cells are sized around these) --------------
s.sizeTitle     = 34;
s.sizeHeading   = 24;
s.sizeContent   = 26;
s.sizeLabel     = 20;
s.sizeMicro     = 14;   % elicitVAS placed-item labels

% Pricing scale, in pixels.
s.priceScale.minorTickPx   = 8;
s.priceScale.majorTickPx   = 32;
s.priceScale.labelSizePx   = 24;
s.priceScale.readoutLiftPx = 84;

% --- Trial-screen chrome ----------------------------------------------
% The HUD must be static during a trial: a ticking timer or live counter
% pulls gaze off the options. heightPx is read by every layout function
% and by preflight.m; changing it moves every AOI in the battery.
s.hud.enabled      = true;
s.hud.heightPx     = 64;
s.hud.position     = 'top';
s.hud.staticDuringTrial = true;
s.hud.showBlock    = true;
s.hud.showEarnings = false;   % between blocks only
s.hud.showTimer    = false;   % never during a search trial

% --- Motion -----------------------------------------------------------
% Declared but implemented nowhere; not a live knob.
s.motion.enabled    = true;
s.motion.fadeInMs   = 220;
s.motion.fadeOutMs  = 220;
s.motion.constantDuration = true;   % must not vary with competition level

% --- Audio ------------------------------------------------------------
% Declared but implemented nowhere; the .wav files do not exist.
s.audio.enabled    = true;
s.audio.clickFile  = 'blip_click.wav';
s.audio.acceptFile = 'blip_accept.wav';
s.audio.rejectFile = 'blip_reject.wav';
s.audio.volume     = 0.5;

% --- Explicitly disabled ----------------------------------------------
% Overlays add high-frequency structure over the AOIs: instruction screens
% only, never over stimuli. Not implemented either way.
s.crtOverlay.onStimuli      = false;
s.crtOverlay.onInstructions = true;

% --- Fixed-geometry grids ----------------------------------------------
% Identity-image grid: fixed pixel size shared by both tasks.
s.identityGrid.nCols = 3;
s.identityGrid.nRows = 2;
s.identityGrid.cellW = 180;
s.identityGrid.cellH = 135;   % 4:3, close to a real-estate photo's shape
s.identityGrid.gap   = 10;

% Card identity-header advance; read by drawCard and cardAOIs, and a
% disagreement misplaces the recorded attribute AOIs.
s.identityTextHeightPx = 42;
% Detail view's own header advance; shared by its three readers.
s.detailTextHeightPx = 34;

% Attribute-slot grid: 8 slots, 2 columns; max shown is 6. Attribute k
% always lands in slot k regardless of how many this trial shows, so
% layout never carries the attribute-count condition.
s.attrGrid.nCols = 2;
s.attrGrid.nRows = 4;    % 8 slots; max shown is 6, so two spare
s.attrGrid.cellW = 260;
s.attrGrid.cellH = 76;
s.attrGrid.gap   = 80;

end
