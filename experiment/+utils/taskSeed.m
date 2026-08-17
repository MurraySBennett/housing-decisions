function seed = taskSeed(participant, sessionNum, taskName)
%UTILS.TASKSEED  Deterministic 32-bit seed from participant/session/task.
%
%   Same inputs always give the same seed, so a session is replayable;
%   different inputs are extremely unlikely to collide.

key = sprintf('%d|%d|%s', participant, sessionNum, lower(char(taskName)));

% Simple FNV-1a hash -- no toolbox or Java dependency.
h = uint32(2166136261);
prime = uint32(16777619);
b = uint32(double(key));
for k = 1:numel(b)
    h = bitxor(h, b(k));
    h = uint32(mod(double(h) * double(prime), 2^32));
end

% MATLAB's Twister accepts 0..2^32-1.
seed = double(h);

end
