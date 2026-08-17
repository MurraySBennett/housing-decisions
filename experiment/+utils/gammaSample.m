function x = gammaSample(shape, scale, n, stream)
%UTILS.GAMMASAMPLE  Gamma draws without the Statistics Toolbox.
%
%   gamrnd lives in the Statistics and Machine Learning Toolbox and does not
%   accept a RandStream, so it is both a licence dependency and a
%   reproducibility hole. Marsaglia-Tsang needs neither.

if nargin < 3 || isempty(n), n = 1; end
if nargin < 4 || isempty(stream), stream = RandStream.getGlobalStream; end
if n == 0, x = zeros(1,0); return; end

boost = 1;
if shape < 1
    boost = rand(stream, 1, n) .^ (1/shape);
    shape = shape + 1;
end

d = shape - 1/3;
c = 1 / sqrt(9*d);
x = zeros(1, n);

for k = 1:n
    while true
        z = randn(stream);
        v = (1 + c*z)^3;
        if v <= 0, continue; end
        u = rand(stream);
        if log(u) < 0.5*z^2 + d - d*v + d*log(v)
            x(k) = d * v;
            break
        end
    end
end

x = x .* scale .* boost;

end
