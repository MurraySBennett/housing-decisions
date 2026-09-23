function s = resolveFonts(window, s)
%UTILS.RESOLVEFONTS  Pick the first genuinely-installed family, by measurement.
%
%   s = utils.resolveFonts(window, cfg.style)
%   Windows GDI substitutes silently and Screen('TextFont') echoes the requested name, so metrics identical to a sentinel fallback mean not installed.

if ~isfield(s, 'fontContentPref'), return; end

% Best-effort: a font probe must never be the reason a session does not run.
try
    oldFont = Screen('TextFont', window);
    oldSize = Screen('TextSize', window);
    Screen('TextSize', window, 24);

    % Mixed ascenders, descenders, digits and a wide capital so different faces measure differently.
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
