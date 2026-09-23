function out = eventLog(action, varargin)
%UTILS.EVENTLOG  Timestamped screen-change markers, synced to flip times.
%   log = utils.eventLog('init', capacity)
%   log = utils.eventLog('add', log, name, flipTime, info)
%   tbl = utils.eventLog('table', log)
%   Keyed to the value returned by Screen('Flip'), not GetSecs (up to a frame early).

switch lower(char(action))

case 'init'
    if isempty(varargin), cap = 5000; else, cap = varargin{1}; end
    out.name      = cell(cap, 1);
    out.flipTime  = nan(cap, 1);
    out.sysTime   = nan(cap, 1);
    out.info      = cell(cap, 1);
    out.n         = 0;
    out.capacity  = cap;

case 'add'
    out      = varargin{1};
    name     = varargin{2};
    flipTime = varargin{3};
    if numel(varargin) >= 4, info = varargin{4}; else, info = struct(); end

    if out.n >= out.capacity      % grow rather than lose events
        grow = out.capacity;
        out.name{end+grow}   = [];
        out.flipTime(end+grow) = NaN;
        out.sysTime(end+grow)  = NaN;
        out.info{end+grow}   = [];
        out.capacity = out.capacity + grow;
    end

    k = out.n + 1;
    out.name{k}     = name;
    out.flipTime(k) = flipTime;
    out.sysTime(k)  = GetSecs;
    out.info{k}     = info;
    out.n           = k;

case 'table'
    log = varargin{1};
    n = log.n;
    if n == 0
        out = table();
        return
    end

    T = table(log.name(1:n), log.flipTime(1:n), log.sysTime(1:n), ...
        'VariableNames', {'event', 'flipTime', 'sysTime'});

    allFields = {};
    for k = 1:n
        if isstruct(log.info{k})
            allFields = union(allFields, fieldnames(log.info{k}));
        end
    end
    for f = 1:numel(allFields)
        fn = allFields{f};
        col = cell(n, 1);
        isNum = true;
        for k = 1:n
            if isstruct(log.info{k}) && isfield(log.info{k}, fn)
                col{k} = log.info{k}.(fn);
                if ~isnumeric(col{k}) || ~isscalar(col{k}), isNum = false; end
            else
                col{k} = NaN;
            end
        end
        if isNum
            T.(fn) = cell2mat(col);
        else
            T.(fn) = col;
        end
    end
    out = T;

otherwise
    error('hw:eventLog:badAction', 'Unknown action "%s".', action);
end

end
