function s = style(themeName)
%UTILS.STYLE  Visual theme, constrained by eye-tracking needs.
%
%   s = utils.style()            % theme from $HW_THEME, else the default
%   s = utils.style('arcade')    % explicit
%
%   The governing rule: NOTHING on a trial screen may be off-task, moving,
%   or high-salience unless it is part of the manipulation. Everything
%   decorative lives on instruction, break and feedback screens.
%
%   Second rule: nothing aesthetic varies with condition. If high-competition
%   blocks also LOOK more frantic, the manipulation is confounded.
%
%   Third rule, new: nothing GEOMETRIC varies with theme. Every value that
%   feeds an AOI rect -- the text sizes, the HUD height, the identity and
%   attribute grids -- is set once below the switch, outside either theme.
%   That makes "the themes are geometrically identical" true by
%   construction rather than by discipline. It used to matter because
%   preflight.m re-implemented the AOI geometry by hand; as of 2026-09-16
%   the card geometry lives in utils.cardAOIs / utils.drawOptionCard /
%   utils.layoutCardAndArc and every caller shares it, so a theme cannot
%   move a rect in one copy and not another. The grid layouts are still
%   duplicated in preflight.
%
%   THEMES
%     'warm'   -- warm charcoal-plum ground, dusty rose accent, rounded
%                 corners, thin strokes, humanist type.
%     'arcade' -- the original dark slate / cyan / amber square-cornered
%                 theme. Kept verbatim as the rollback target.
%
%   ROLLBACK, mid-session, no code edit:
%       setenv('HW_THEME','arcade'); run_battery
%   utils.style is called from utils.config, which every entry point hits
%   at startup, so the next run comes up in the old theme.
%
%   The theme in force is recorded as dataMat.theme on every saved run.
%
%   See also UTILS.ROUNDRECT, UTILS.RESOLVEFONTS, UTILS.CONFIG.

if nargin < 1 || isempty(themeName)
    themeName = getenv('HW_THEME');
end
if isempty(themeName)
    themeName = 'warm';
end
s.themeName = lower(char(themeName));

% Colors are normalized to 0.0-1.0, NOT 0-255. PsychDefaultSetup(2) (called
% at the top of both task files) switches the window's color interpretation
% to normalized floats -- every color anywhere in this codebase has to be
% in that range or it clamps to 1.0 on every channel, i.e. white. That is
% exactly what "screen goes white almost immediately, can't see the mouse
% indicator" was: every FillRect/DrawLine/DrawDots using an 0-255 style
% color rendered as solid white (and white text/lines on a white
% background are invisible, which is also why the cursor indicator
% vanished). Normalizing once here, at the source, means nothing else in
% the codebase has to remember to divide by 255.
c255 = @(r,g,b) [r g b] / 255;

switch s.themeName

case 'warm'
    % --- Palette ------------------------------------------------------
    % Warm charcoal-plum ground with panels RAISED above it rather than
    % inset below it, which is the softer of the two readings.
    %
    % The ground stays dark on purpose. Black dilates the pupil and costs
    % tracking accuracy; a light ground does the opposite and floors it,
    % which would forfeit pupillometry entirely. This ground sits at
    % relative luminance ~0.03, essentially unchanged from the slate
    % theme, so the restyle is a hue-and-shape change and NOT a
    % physiological one.
    %
    % Ratios below are WCAG contrast against s.bg. Everything used for
    % TEXT clears 4.5:1; everything used only for strokes and markers
    % clears 3:1.
    s.bg          = c255( 46,  42,  46);   % #2E2A2E  warm charcoal-plum
    s.bgPanel     = c255( 58,  53,  64);   % #3A3540  soft raised mauve-grey

    s.text        = c255(240, 234, 230);   % #F0EAE6  warm off-white  12.4:1
    s.textDim     = c255(180, 168, 164);   % #B4A8A4  warm grey        6.1:1

    s.interactive = c255(217, 137, 155);   % #D9899B  dusty rose       6.2:1
    s.money       = c255(227, 181, 140);   % #E3B58C  soft apricot     8.3:1
    s.accepted    = c255(143, 201, 160);   % #8FC9A0  soft sage        9.4:1
    s.rejected    = c255(224, 138, 138);   % #E08A8A  soft rose-red    6.6:1

    % Three border weights, not one. A soft low-contrast edge is the whole
    % point of the theme on DECORATIVE chrome -- and is actively harmful
    % on a FUNCTIONAL stroke, i.e. a scale the participant has to read.
    % Those get s.track. See the arc and VAS call sites.
    s.border       = c255( 74,  66,  76);  % #4A424C  1.4:1  panel edges
    s.borderStrong = c255(107,  98, 112);  % #6B6270  2.4:1  progress bar, hit ring
    s.track        = c255(138, 128, 144);  % #8A8090  4.1:1  price arc, VAS line

    % Calibration quality depends on the participant actually fixating the
    % dot, so the target takes maximum contrast rather than borrowing the
    % accent colour.
    s.target       = s.text;               % 12.4:1

    % The advertised-value marker on the pricing scale. Needs its own
    % colour: it is neither the participant's response (s.money, the live
    % readout) nor a control (s.interactive, the knob), and reusing either
    % would make the scale ambiguous at exactly the moment it must not be.
    s.marker       = c255(126, 186, 181);  % #7EBAB5  muted teal   7.2:1

    % --- Typography ---------------------------------------------------
    % The pixel font is gone. It was used at three sites, was never
    % checked for availability, and made the build depend on a manual
    % install on the lab machine -- if that step was missed, Windows
    % substituted silently and those screens rendered in an unpredictable
    % face. Segoe UI ships with every Windows since Vista.
    s.fontChrome    = 'Segoe UI';   % chrome now differs by size, not family
    s.fontChromeAlt = 'Verdana';
    s.fontContent   = 'Segoe UI';

    % Probed at runtime by utils.resolveFonts, which upgrades these to the
    % first family that is genuinely installed. Corbel is a humanist face
    % with soft, slightly rounded terminals and ships with the Windows
    % ClearType collection -- warmer than Segoe UI, but only PROBABLY
    % present, which is why it is a preference and not the default.
    s.fontContentPref = {'Corbel', 'Segoe UI', 'Verdana', 'Arial'};
    s.fontChromePref  = {'Segoe UI Semibold', 'Segoe UI', 'Verdana', 'Arial'};

    % --- Shape --------------------------------------------------------
    % borderWidthPx 4 -> 2. The chunky border was justified as sharpening
    % AOI boundaries, but the AOIs are the image and text sub-rects INSIDE
    % a tile, not the tile outline, so it was never marking an AOI edge.
    s.borderWidthPx = 2;
    s.hairlinePx    = 1;

    % Radius tokens, consumed by utils.roundRect. Setting all three to 0
    % restores square corners exactly -- roundRect falls through to
    % Screen('FillRect') below radius 1. That is the shape-only rollback.
    s.radiusPanel = 18;     % cards, option tiles, buttons, HUD, input box
    s.radiusCell  = 10;     % attribute cells
    s.radiusPill  = 9999;   % progress bar; clamped to half-height = a pill

    s.hudUppercase = false; % the arcade font is gone; SHOUTING with it

case 'arcade'
    % The original theme, verbatim. This branch exists to be rolled back
    % to; do not "improve" it.
    %
    % Mid-grey background rather than black: black dilates the pupil and
    % costs tracking accuracy, and rules out pupillometry later.
    s.bg          = c255( 42,  46,  54);
    s.bgPanel     = c255( 28,  31,  38);
    s.text        = c255(232, 234, 240);
    s.textDim     = c255(150, 156, 170);

    s.interactive = c255( 92, 214, 232);   % cyan  -- anything clickable
    s.money       = c255(246, 190,  84);   % amber -- prices, wages, value
    s.accepted    = c255(126, 217, 130);   % green
    s.rejected    = c255(232, 106, 106);   % red
    s.border      = c255( 78,  86, 104);

    % The theme predates the three-weight split; both aliases resolve to
    % the single border colour so shared call sites keep working.
    s.borderStrong = s.border;
    s.track        = s.border;
    s.target       = s.interactive;
    s.marker       = c255(126, 217, 130);  % green, distinct from cyan/amber

    % Pixel font for chrome only. Pixel fonts wreck reading times at small
    % sizes, and reading time is a dependent variable here.
    s.fontChrome    = 'Press Start 2P';
    s.fontChromeAlt = 'Courier New';    % fallback if not installed
    s.fontContent   = 'Helvetica';

    % Preference lists reproduce the theme's own choices, so wiring
    % utils.resolveFonts changes nothing under 'arcade'.
    s.fontContentPref = {'Helvetica', 'Arial'};
    s.fontChromePref  = {'Press Start 2P', 'Courier New', 'Courier'};

    % Chunky borders are a free win: they read as arcade AND they sharpen
    % AOI boundaries, which helps both the participant and the analysis.
    s.borderWidthPx = 4;
    s.hairlinePx    = 2;

    % Square corners; rounded reads as modern, not retro. utils.roundRect
    % delegates to Screen('FillRect') at radius 0, so the migrated call
    % sites produce byte-identical output under this theme.
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
%  Nothing below may differ between themes. These are the values that feed
%  AOI rects, directly or via utils.attrSlotRects, and they are also
%  re-implemented by hand inside preflight.m. If a theme could change them,
%  flipping the theme mid-session would silently invalidate every saved AOI.

% Legacy name, still read nowhere. Kept so old callers do not error.
s.cornerRadius = s.radiusPanel;

% Never let colour be the only carrier of information -- every colour-coded
% state also gets a text label or an icon.
s.colourIsRedundant = true;

% --- Type sizes (geometric: cells are sized around these) --------------
s.sizeTitle     = 34;
s.sizeHeading   = 24;
s.sizeContent   = 26;
s.sizeLabel     = 20;
s.sizeMicro     = 14;   % elicitVAS placed-item labels; was a literal

% --- Trial-screen chrome ----------------------------------------------
% The HUD is genuinely informative and lives outside the stimulus AOIs.
% But it must be STATIC during a trial -- a ticking timer or a live
% earnings counter is an attention magnet that will pull gaze off the
% options.
%
% heightPx is read by every layout function in both tasks AND by
% preflight.m. Changing it moves every AOI in the battery.
s.hud.enabled      = true;
s.hud.heightPx     = 64;
s.hud.position     = 'top';
s.hud.staticDuringTrial = true;
s.hud.showBlock    = true;
s.hud.showEarnings = false;   % between blocks only
s.hud.showTimer    = false;   % never during a search trial

% --- Motion -----------------------------------------------------------
% Declared but implemented nowhere -- there is no fade code in the
% codebase. Left in place as a statement of intent, not a live knob.
s.motion.enabled    = true;
s.motion.fadeInMs   = 220;
s.motion.fadeOutMs  = 220;
s.motion.constantDuration = true;   % must not vary with competition level

% --- Audio ------------------------------------------------------------
% Also declared but implemented nowhere: nothing calls PsychPortAudio and
% the .wav files do not exist.
s.audio.enabled    = true;
s.audio.clickFile  = 'blip_click.wav';
s.audio.acceptFile = 'blip_accept.wav';
s.audio.rejectFile = 'blip_reject.wav';
s.audio.volume     = 0.5;

% --- Explicitly disabled ----------------------------------------------
% Scanline / CRT overlays add high-spatial-frequency structure across the
% AOIs and interfere with gaze plausibility checks. Fine on instruction
% screens, never over stimuli. Not implemented either way.
s.crtOverlay.onStimuli      = false;
s.crtOverlay.onInstructions = true;

% --- Fixed-geometry grids ----------------------------------------------
% Identity-image grid: 2 rows x 3 cols, same PIXEL size wherever it's
% drawn -- both tasks share these constants so a house's photos never
% appear a different size in the auction's detail view than in contdc's
% card. Previously the grid stretched or compressed to whatever fraction
% of the caller's rect it was given, which is why sizes drifted between
% screens.
s.identityGrid.nCols = 3;
s.identityGrid.nRows = 2;
s.identityGrid.cellW = 180;
s.identityGrid.cellH = 135;   % 4:3, close to a real-estate photo's shape
s.identityGrid.gap   = 10;

% Vertical room reserved for the TEXT identity header (jobs: industry) on
% a card that has one. This is a single constant because two places read
% it -- the draw in continuous_DC_task/drawCard and the AOI mirror in
% cardAOIs -- and if they disagree the recorded attribute AOIs sit
% somewhere other than the drawn cells, which is invisible until the gaze
% analysis. Raised from a literal 30 on 2026-09-16: the industry is the
% fastest read of what a job IS, and at s.sizeLabel in s.textDim it was
% losing to the attribute values below it.
s.identityTextHeightPx = 42;
% The detail view's own header advance. Separate constant from the card's
% because the two screens set that header at different sizes -- but a
% NAMED one, for the same reason: it was a literal 34 in three places
% (auction_task's draw, its AOI layout, and preflight's copy of that), and
% the card's equivalent drifted from 30 to 42 in two of its three copies.
s.detailTextHeightPx = 34;

% Attribute-SLOT grid: enough slots for the max ever shown, 2 columns. As
% of 2026-09-15 the late tier is reserved INSIDE nAttrs rather than added
% on top of it (see utils.selectAttributes), so the maximum is 6, not 7,
% and every attribute level fills whole rows -- no cell is ever left alone
% on a final row. The grid keeps 8 slots: slots 1-6 compute to identical
% coordinates either way, and shrinking it would disturb geometry that
% preflight.m mirrors by hand.
%
% Attribute #1 always lands in slot 1, #2 in slot 2, etc, regardless of how
% many attributes THIS trial shows -- a 2-attribute trial does not restretch
% into the space a 6-attribute trial uses; it just leaves the remaining
% slots empty. Fixed position is the whole point: visual layout should not
% itself carry information about the attribute-count condition.
s.attrGrid.nCols = 2;
s.attrGrid.nRows = 4;    % 8 slots; max shown is 6, so two spare
s.attrGrid.cellW = 260;
s.attrGrid.cellH = 76;
s.attrGrid.gap   = 80;

end
