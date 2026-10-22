function v = gazeValidity(x)
%UTILS.GAZEVALIDITY The value behind any spelling of Tobii's Validity.
%
% The real SDK wraps validity in an object exposing .value (rig probe, item
% 4); FakeGazeTracker and old recordings store a plain numeric; gazeCodec's
% unpack reconstructs the wrapper as a struct with a value field. Only the
% unwrapping lives here. POLICY STAYS WITH THE CALLER: an unreadable validity
% comes back unchanged, and the caller decides whether that fails closed
% (gazeToPixels), asserts (positionGuide), or is passed through (gazeCodec).
% This function never throws.
%
% scripts/export_gaze_csv.m's validityColumn is deliberately NOT a caller: it
% reads packed leaf columns, not live samples, and owns its own path rule.
if isnumeric(x) || islogical(x)
    v = x;
    return
end
try
    v = x.value;
catch
    v = x;
end
end
