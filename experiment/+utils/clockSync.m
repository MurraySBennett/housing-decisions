function sync = clockSync(et)
%UTILS.CLOCKSYNC  Capture a Tobii timestamp next to PTB GetSecs.
%
%   Two pairs, one near run start and one near run end, are enough to estimate
%   offset and drift between Tobii system timestamps and PTB event times.

sync = struct('ptbSecs', NaN, 'tobiiSystemTimeStamp', NaN, ...
    'ok', false, 'uncertaintySecs', NaN, 'error', '');

try, sync.ptbSecs = GetSecs; catch, end

if ~isstruct(et) || ~et.enabled || isempty(et.obj)
    return
end

try
    before = GetSecs;
    sync.tobiiSystemTimeStamp = et.operations.get_system_time_stamp();
    after = GetSecs;
    sync.ptbSecs = (before + after) / 2;
    sync.uncertaintySecs = (after - before) / 2;
    sync.ok = isinteger(sync.tobiiSystemTimeStamp) && isscalar(sync.tobiiSystemTimeStamp);
catch ME
    sync.error = ME.message;
end

end
