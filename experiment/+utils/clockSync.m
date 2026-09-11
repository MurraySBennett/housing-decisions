function sync = clockSync(et)
%UTILS.CLOCKSYNC  Capture a Tobii timestamp next to PTB GetSecs.
%
%   Two pairs, one near run start and one near run end, are enough to estimate
%   offset and drift between Tobii system timestamps and PTB event times.

sync = struct('ptbSecs', GetSecs, 'tobiiSystemTimeStamp', NaN, 'ok', false);

if ~isstruct(et) || ~et.enabled || isempty(et.obj)
    return
end

try
    sync.tobiiSystemTimeStamp = et.obj.get_system_time_stamp();
    sync.ok = true;
catch
end

end
