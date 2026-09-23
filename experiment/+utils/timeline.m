function tl = timeline(action, tl, label)
%UTILS.TIMELINE  Flat wall-clock section log for one run.
%
%   tl = utils.timeline('start');                 % opens section 'setup'
%   tl = utils.timeline('section', tl, 'name');   % closes current, opens name
%   tl = utils.timeline('stop', tl);              % closes the open section
%   T  = utils.timeline('table', tl);             % section/tStart/tEnd/seconds
%
%   Times are GetSecs. Sections are contiguous by construction: every
%   boundary closes the previous section, so the rows tile the run and
%   their seconds sum to the run's wall clock. Store the 'table' result as
%   dataMat.timing; run_battery collects it into the session timing CSV.

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
