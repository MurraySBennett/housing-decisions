function tl = timeline(action, tl, label)
%UTILS.TIMELINE  Flat wall-clock section log for one run.
%
%   Actions: 'start' / 'section' / 'stop' / 'table'. Times are GetSecs.
%   Sections tile the run: every boundary closes the previous section.

switch lower(char(action))
    case 'start'
        tl = struct('labels', {{'setup'}}, 'starts', GetSecs, 'ends', NaN);

    case 'section'
        t = GetSecs;
        tl.ends(end) = t;
        tl.labels{end+1} = char(label);
        tl.starts(end+1) = t;
        tl.ends(end+1) = NaN;

    case 'stop'
        if isnan(tl.ends(end)), tl.ends(end) = GetSecs; end

    case 'table'
        if isnan(tl.ends(end)), tl.ends(end) = GetSecs; end
        secs = tl.ends - tl.starts;
        tl = table(string(tl.labels(:)), tl.starts(:), tl.ends(:), secs(:), ...
            'VariableNames', {'section','tStart','tEnd','seconds'});

    otherwise
        error('hw:timeline:badAction', 'Unknown action "%s".', action);
end

end
