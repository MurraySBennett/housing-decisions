function association = alignBlockGaze(packed, events, clockSync)
%UTILS.ALIGNBLOCKGAZE Half-open event intervals with explicit unknown alignment.
n = packed.sampleCount;
association = table((1:n)', nan(n,1), nan(n,1), repmat("unknown", n,1), ...
    'VariableNames', {'sampleIndex','ptbTime','trial','phase'});
if n == 0, return; end
if ~isfield(clockSync, 'start') || ~isfield(clockSync, 'end') || ...
        ~clockSync.start.ok || ~clockSync.end.ok, return; end
start = clockSync.start; finish = clockSync.end;
ix = find(arrayfun(@(x) isequal(x.path, {'SystemTimeStamp'}), packed.leafSchema), 1);
if isempty(ix), return; end
t = packed.columns{ix};
if size(t,2) ~= 1 || ~isinteger(t) || ...
        ~isinteger(start.tobiiSystemTimeStamp) || ~isinteger(finish.tobiiSystemTimeStamp) || ...
        any(t < 0) || start.tobiiSystemTimeStamp < 0 || finish.tobiiSystemTimeStamp < 0, return; end
origin = uint64(start.tobiiSystemTimeStamp); last = uint64(finish.tobiiSystemTimeStamp);
if last <= origin || ~isfinite(start.ptbSecs) || ~isfinite(finish.ptbSecs) || ...
        finish.ptbSecs <= start.ptbSecs || any(t(2:end) < t(1:end-1)), return; end
% Subtract integer origins BEFORE converting intervals to double.
t = uint64(t); delta = zeros(n,1); after = t >= origin;
delta(after) = double(t(after) - origin);
delta(~after) = -double(origin - t(~after));
association.ptbTime = start.ptbSecs + delta .* ...
    ((finish.ptbSecs - start.ptbSecs) / double(last - origin));
association.trial(:) = 0; association.phase(:) = "outside";
if isempty(events) || ~all(ismember({'flipTime','trial','phase'}, events.Properties.VariableNames)), return; end
phase = string(events.phase); usable = isfinite(events.flipTime) & phase ~= "" & phase ~= "NaN";
events = events(usable,:); phase = phase(usable);
[~,order] = sort(events.flipTime); events = events(order,:); phase = phase(order);
for k = 1:height(events)
    lastTime = Inf;
    if k < height(events), lastTime = events.flipTime(k+1); end
    take = association.ptbTime >= events.flipTime(k) & association.ptbTime < lastTime;
    association.trial(take) = events.trial(k);
    association.phase(take) = phase(k);
end
end
