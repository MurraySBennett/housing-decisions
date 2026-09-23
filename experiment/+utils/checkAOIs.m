function [ok, report] = checkAOIs(rects, names, g, verbose)
%UTILS.CHECKAOIS  Validate that AOIs are far enough apart to be separable.
%   [ok, report] = utils.checkAOIs(rects, names, utils.geom())
%   rects: 4 x nAOI PTB rects [left top right bottom]; names: cellstr.

if nargin < 4, verbose = true; end
n = size(rects, 2);
ok = true;
report = struct('a', {}, 'b', {}, 'gapPx', {}, 'gapDeg', {}, 'verdict', {});

% --- Size check -------------------------------------------------------
for i = 1:n
    w = rects(3,i) - rects(1,i);
    h = rects(4,i) - rects(2,i);
    if min(w,h) < g.minAOIPx
        ok = false;
        if verbose
            fprintf(2, '  AOI "%s" is %.1f x %.1f deg -- below the %.1f deg minimum.\n', ...
                names{i}, g.px2deg(w), g.px2deg(h), g.minAOIDeg);
        end
    end
end

% --- Pairwise separation (edge-to-edge; zero if overlapping) ----------
for i = 1:n-1
    for j = i+1:n
        dx = max([rects(1,j) - rects(3,i), rects(1,i) - rects(3,j), 0]);
        dy = max([rects(2,j) - rects(4,i), rects(2,i) - rects(4,j), 0]);
        gapPx = hypot(dx, dy);
        gapDeg = g.px2deg(gapPx);

        if gapDeg >= g.targetSepDeg
            verdict = 'ok';
        elseif gapDeg >= g.minSepDeg
            verdict = 'marginal';
        else
            verdict = 'TOO CLOSE -- merge or move';
            ok = false;
        end

        report(end+1) = struct('a', names{i}, 'b', names{j}, ...
            'gapPx', gapPx, 'gapDeg', gapDeg, 'verdict', verdict); %#ok<AGROW>
    end
end

if verbose
    bad = report(~strcmp({report.verdict}, 'ok'));
    if isempty(bad)
        fprintf('  All %d AOI pairs separated by >= %.1f deg.\n', numel(report), g.targetSepDeg);
    else
        fprintf('  %d AOI pair(s) below target separation:\n', numel(bad));
        for k = 1:numel(bad)
            fprintf('    %-14s <-> %-14s  %5.1f px (%.2f deg)  %s\n', ...
                bad(k).a, bad(k).b, bad(k).gapPx, bad(k).gapDeg, bad(k).verdict);
        end
    end
end

end
