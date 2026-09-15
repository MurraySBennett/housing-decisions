function s = resolveFonts(window, s)
%UTILS.RESOLVEFONTS  Pick the first genuinely-installed family, by measurement.
%
%   s = utils.resolveFonts(window, cfg.style)
%
%   Replaces s.fontContent and s.fontChrome with the first family in
%   s.fontContentPref / s.fontChromePref that is actually installed, and
%   leaves them untouched if none is or if anything goes wrong.
%
%   WHY MEASUREMENT AND NOT A LOOKUP. Windows GDI substitutes silently for
%   a missing family, and Screen('TextFont', window) echoes back the name
%   you REQUESTED, not the one you got -- so it cannot detect substitution.
%   Screen('Fonts') is unreliable under the default GDI renderer. The
%   renderer-independent test is to measure: set a sentinel family that
%   certainly does not exist, measure a probe string, then measure each
%   candidate. Identical metrics mean the candidate resolved to the same
%   fallback, i.e. it is not installed.
%
%   This exists because the battery previously depended on 'Press Start
%   2P' being installed by hand on the lab machine, with no check anywhere
%   and a silent OS substitution if the step was forgotten.
%
%   HONEST LIMIT. The probe detects substitution only when the candidate's
%   metrics differ from the fallback's. Two near-identical grotesques might
%   not be distinguished. That is why s.fontContent and s.fontChrome still
%   hold a guaranteed-present family as their own default -- this function
%   can only ever upgrade that choice, never break it.
%
%   Everything here is best-effort. A font probe must never be the reason a
%   session does not run, so the whole body is wrapped and falls back to
%   whatever utils.style already chose.
%
%   See also UTILS.STYLE.

if ~isfield(s, 'fontContentPref'), return; end

try
    oldFont = Screen('TextFont', window);
    oldSize = Screen('TextSize', window);
    Screen('TextSize', window, 24);

    % Mixed ascenders, descenders, digits and a wide capital, so two
    % genuinely different faces are very unlikely to measure the same.
    probe = 'Wilmington 1290 gjqy';

    Screen('TextFont', window, '__hw_no_such_font__');
    base = Screen('TextBounds', window, probe);

    s.fontContent = firstReal(window, s.fontContentPref, probe, base, s.fontContent);
    s.fontChrome  = firstReal(window, s.fontChromePref,  probe, base, s.fontChrome);

    Screen('TextFont', window, oldFont);
    Screen('TextSize', window, oldSize);
catch err
    warning('hw:resolveFonts:failed', ...
        'Font probing failed (%s); keeping utils.style defaults.', err.message);
end

end


%% ======================================================================
function name = firstReal(window, candidates, probe, base, fallback)
%FIRSTREAL  First candidate whose metrics differ from the substitute's.

name = fallback;
for k = 1:numel(candidates)
    Screen('TextFont', window, candidates{k});
    b = Screen('TextBounds', window, probe);
    if ~isequal(b(3:4), base(3:4))
        name = candidates{k};
        return
    end
end

end
