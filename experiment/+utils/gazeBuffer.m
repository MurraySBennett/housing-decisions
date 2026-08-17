function out = gazeBuffer(action, et, store)
%UTILS.GAZEBUFFER  Accumulate Tobii samples without losing them.
%
%   Tobii's get_gaze_data() returns everything buffered *since the last
%   call* and then clears the buffer. The current code calls it once per
%   redraw to draw the gaze dot, which silently throws away every sample
%   between the second-to-last and last call -- so with show_eye_pos on,
%   the saved gaze data is only the final few milliseconds of a block.
%
%   Use this instead:
%       store = utils.gazeBuffer('init');
%       ...
%       [samples, store] = deal(...);              % see 'poll' below
%       store = utils.gazeBuffer('poll', et, store);  % drains AND keeps
%       latest = store.latest;                     % for the gaze dot
%       ...
%       all = utils.gazeBuffer('flush', et, store);   % everything, for saving

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
