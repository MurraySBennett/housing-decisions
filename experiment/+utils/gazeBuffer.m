function out = gazeBuffer(action, et, store)
%UTILS.GAZEBUFFER  Accumulate Tobii samples without losing them.
%
%   store = utils.gazeBuffer('init' | 'poll' | 'flush', et, store)
%   Tobii get_gaze_data() drains its buffer on every call, so all polls
%   must go through this accumulator or samples are silently lost.

switch lower(action)
    case 'init'
        out = struct('samples', {{}}, 'latest', [], 'n', 0);

    case 'poll'
        out = store;
        if ~isstruct(et) || ~et.enabled || isempty(et.obj), return; end
        try
            s = et.obj.get_gaze_data();
        catch
            return
        end
        if isempty(s), return; end
        out.samples{end+1} = s;
        out.n = out.n + numel(s);
        out.latest = s(end);

    case 'flush'
        out = utils.gazeBuffer('poll', et, store);
        if isstruct(et) && et.enabled && ~isempty(et.obj)
            try, et.obj.stop_gaze_data(); catch, end
        end
        if isempty(out.samples)
            out = [];
        else
            out = vertcat(out.samples{:});
        end

    otherwise
        error('hw:gazeBuffer:badAction', 'Unknown action "%s".', action);
end

end
