function out = ternary(cond, a, b)
%UTILS.TERNARY  Inline conditional, for readability in format strings.
if cond, out = a; else, out = b; end
end
