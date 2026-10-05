function out = gazeBuffer(action, et, store, run)
%UTILS.GAZEBUFFER  Accumulate Tobii samples without losing them.
%
%   store = utils.gazeBuffer('init' | 'poll' | 'flush', et, store)
%   Tobii get_gaze_data() drains its buffer on every call, so all polls
%   must go through this accumulator or samples are silently lost.

if nargin < 4, run = []; end

switch lower(action)
    case 'init'
        out = struct('samples', {{}}, 'latest', [], 'n', 0);

    case 'poll'
        out = store;
        if ~isstruct(et) || ~et.enabled || isempty(et.obj), return; end
        try
            s = et.obj.get_gaze_data();
        catch ME
            flushLog(run, ['GAZE POLL ERROR (ignored): ' ME.message]);
            return
        end
        if isempty(s), return; end
        out.samples{end+1} = s;
        out.n = out.n + numel(s);
        out.latest = s(end);

    case 'flush'
        flushLog(run, 'BEGIN final gaze poll');
        out = utils.gazeBuffer('poll', et, store, run);
        flushLog(run, 'END final gaze poll');
        if isstruct(et) && et.enabled && ~isempty(et.obj)
            flushLog(run, 'BEGIN tracker stop');
            try
                et.obj.stop_gaze_data();
                flushLog(run, 'END tracker stop');
            catch ME
                flushLog(run, ['TRACKER STOP ERROR (ignored): ' ME.message]);
            end
        end
        flushLog(run, 'BEGIN gaze concatenation');
        if isempty(out.samples)
            out = [];
        else
            out = vertcat(out.samples{:});
        end
        flushLog(run, 'END gaze concatenation');

    otherwise
        error('hw:gazeBuffer:badAction', 'Unknown action "%s".', action);
end

function flushLog(run, message)
if ~isempty(run), utils.progressLog(run, '%s', message); end
end

end
