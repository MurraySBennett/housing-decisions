function val = promptNumeric(msg, lo, hi)
%UTILS.PROMPTNUMERIC  input() that re-asks instead of erroring on bad entry.
%
%   Stops a mistyped participant number from taking down the whole session
%   with the participant already sitting at the machine.

if nargin < 2, lo = -Inf; end
if nargin < 3, hi =  Inf; end

while true
    raw = input(msg, 's');
    val = str2double(strtrim(raw));
    if ~isnan(val) && isreal(val) && val >= lo && val <= hi
        return
    end
    fprintf('  Please enter a number between %g and %g.\n', lo, hi);
end

end
