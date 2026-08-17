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
    lok = L.Validity == 1 && all(~isnan(L.OnDisplayArea));
    rok = R.Validity == 1 && all(~isnan(R.OnDisplayArea));

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
