function t = GetSecs
persistent now
if isempty(now), now = 100; end
now = now + .1; t = now;
end
