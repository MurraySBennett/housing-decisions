function s = style()
%UTILS.STYLE  Retro-arcade visual theme, constrained by eye-tracking needs.
%
%   The governing rule: NOTHING on a trial screen may be off-task, moving,
%   or high-salience unless it is part of the manipulation. Everything
%   decorative lives on instruction, break and feedback screens.
%
%   Second rule: nothing aesthetic varies with condition. If high-competition
%   blocks also LOOK more frantic, the manipulation is confounded.

% --- Palette (fixed, semantic, luminance-matched across conditions) ---
% Mid-grey background rather than black: black dilates the pupil and costs
% tracking accuracy, and rules out pupillometry later.
%
% Colors are normalized to 0.0-1.0, NOT 0-255. PsychDefaultSetup(2) (called
% at the top of both task files) switches the window's color interpretation
% to normalized floats -- every color anywhere in this codebase has to be
% in that range or it clamps to 1.0 on every channel, i.e. white. That is
% exactly what "screen goes white almost immediately, can't see the mouse
% indicator" was: every FillRect/DrawLine/DrawDots using an 0-255 style
% color rendered as solid white (and white text/lines on a white
% background are invisible, which is also why the cursor indicator
% vanished). Normalizing once here, at the source, means nothing else in
% the codebase has to remember to divide by 255 -- including the one place
% that already did, at the OpenWindow calls, which no longer needs to.
c255 = @(r,g,b) [r g b] / 255;

s.bg          = c255( 42,  46,  54);
s.bgPanel     = c255( 28,  31,  38);
s.text        = c255(232, 234, 240);
s.textDim     = c255(150, 156, 170);

s.interactive = c255( 92, 214, 232);   % cyan  -- anything clickable
s.money       = c255(246, 190,  84);   % amber -- prices, wages, value
s.accepted    = c255(126, 217, 130);   % green
s.rejected    = c255(232, 106, 106);   % red
s.border      = c255( 78,  86, 104);

% Never let colour be the only carrier of information -- every colour-coded
% state also gets a text label or an icon.
s.colourIsRedundant = true;

% --- Typography -------------------------------------------------------
% Pixel font for chrome only. Pixel fonts wreck reading times at small
% sizes, and reading time is a dependent variable here.
s.fontChrome    = 'Press Start 2P';
s.fontChromeAlt = 'Courier New';    % fallback if not installed
s.fontContent   = 'Helvetica';
s.sizeTitle     = 34;
s.sizeHeading   = 24;
s.sizeContent   = 26;
s.sizeLabel     = 20;

% --- Trial-screen chrome ----------------------------------------------
% The HUD is the highest-value retro element because it is genuinely
% informative and lives outside the stimulus AOIs. But it must be STATIC
% during a trial -- a ticking timer or a live earnings counter is an
% attention magnet that will pull gaze off the options.
s.hud.enabled      = true;
s.hud.heightPx     = 64;
s.hud.position     = 'top';
s.hud.staticDuringTrial = true;
s.hud.showBlock    = true;
s.hud.showEarnings = false;   % between blocks only
s.hud.showTimer    = false;   % never during a search trial

% --- Motion -----------------------------------------------------------
% Short, constant-duration transitions help participants notice options
% appearing and disappearing. Keep them brief and log the actual times.
s.motion.enabled    = true;
s.motion.fadeInMs   = 220;
s.motion.fadeOutMs  = 220;
s.motion.constantDuration = true;   % must not vary with competition level

% --- Audio ------------------------------------------------------------
% Large engagement return, near-zero cost to rigour if consistent.
% Pre-load buffers so PsychPortAudio never blocks the display loop.
s.audio.enabled    = true;
s.audio.clickFile  = 'blip_click.wav';
s.audio.acceptFile = 'blip_accept.wav';
s.audio.rejectFile = 'blip_reject.wav';
s.audio.volume     = 0.5;

% --- Explicitly disabled ----------------------------------------------
% Scanline / CRT overlays add high-spatial-frequency structure across the
% AOIs and interfere with gaze plausibility checks. Fine on instruction
% screens, never over stimuli.
s.crtOverlay.onStimuli     = false;
s.crtOverlay.onInstructions = true;

% Chunky borders are a free win: they read as arcade AND they sharpen AOI
% boundaries, which helps both the participant and the analysis.
s.borderWidthPx = 4;
s.cornerRadius  = 0;   % square corners; rounded reads as modern, not retro

end
