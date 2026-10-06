function [x, y] = gazeToPixels(samples, window)
%UTILS.GAZETOPIXELS  Average the two eyes and convert to screen pixels.
%
%   Tobii reports gaze in normalised display-area coordinates (0-1). Where
%   only one eye is valid we use that eye rather than discarding the sample.

rect = Screen('Rect', window);
w = rect(3); h = rect(4);
n = numel(samples);
x = nan(n, 1); y = nan(n, 1);

for k = 1:n
    L = samples(k).LeftEye.GazePoint;
    R = samples(k).RightEye.GazePoint;
    lok = validityIsValid(L.Validity) && all(~isnan(L.OnDisplayArea));
    rok = validityIsValid(R.Validity) && all(~isnan(R.OnDisplayArea));

    if lok && rok
        p = (L.OnDisplayArea + R.OnDisplayArea) / 2;
    elseif lok
        p = L.OnDisplayArea;
    elseif rok
        p = R.OnDisplayArea;
    else
        continue
    end
    x(k) = p(1) * w;
    y(k) = p(2) * h;
end

end


function tf = validityIsValid(v)
%VALIDITYISVALID One accessor for both SDK spellings of Validity.
%
% The real SDK wraps validity in an object exposing .value. That is the
% spelling utils.gazeCodec's eyeArgs uses, and the actual-SDK roundtrip case
% in scripts/tests/test_gaze_codec.m passes on the rig, so it is confirmed
% against real SDK classes rather than assumed.
%
% This was a bare `v == 1`, which on that wrapper either errors outright --
% taking the session down at the first drift check -- or compares the wrong
% thing and reports every sample invalid for the whole session. Nothing
% caught it because FakeGazeTracker sets Validity to a plain numeric 1, so
% the fake and the rig disagreed about the type and only the fake was tested.
%
% Fails closed: an unreadable validity counts as invalid, which leaves the
% sample as NaN and trips driftCheck's "too few valid samples" warning,
% rather than throwing in the middle of a block.
if ~isnumeric(v) && ~islogical(v)
    try
        v = v.value;
    catch
        tf = false;
        return
    end
end
tf = isscalar(v) && (isnumeric(v) || islogical(v)) && double(v) == 1;
end
