function sample = diagnoseTrackBox(cfg)
%UTILS.DIAGNOSETRACKBOX  Print Tobii gaze sample fields for positionGuide.
%   sample = utils.diagnoseTrackBox()

if nargin < 1 || isempty(cfg)
    cfg = utils.config('rig', 'lab');
end

sample = [];

if ~cfg.et.enabled
    fprintf('Eye tracking is disabled in cfg.et.enabled.\n');
    return
end

try
    Tobii = EyeTrackingOperations();
    trackers = Tobii.find_all_eyetrackers();
    if isempty(trackers)
        fprintf('No eye tracker found.\n');
        return
    end

    et = trackers(1);
    fprintf('Connected: %s (%s)\n', et.Name, et.SerialNumber);

    try
        fprintf('Sample rate: %.1f Hz\n', et.get_gaze_output_frequency());
    catch ME
        fprintf('Sample rate unavailable: %s\n', ME.message);
    end

    try, et.get_gaze_data(); catch, end
    t0 = tic;
    samples = [];
    while toc(t0) < 3 && isempty(samples)
        pause(0.10);
        try
            samples = et.get_gaze_data();
        catch ME
            fprintf('get_gaze_data failed: %s\n', ME.message);
            return
        end
    end

    if isempty(samples)
        fprintf('No gaze samples received in 3 seconds.\n');
        return
    end

    sample = samples(end);
    fprintf('Received %d sample(s). Latest sample fields:\n', numel(samples));
    printFields(sample, 'sample');

    printCandidate(sample, {'LeftEye', 'left_eye'});
    printCandidate(sample, {'RightEye', 'right_eye'});
catch ME
    fprintf('Track-box diagnostic failed: %s\n', ME.message);
end

end


%% ======================================================================
function printFields(x, name)
f = {};
try
    f = fieldnames(x);
catch
    try
        f = properties(x);
    catch
    end
end
if isempty(f)
    fprintf('  %s: %s\n', name, class(x));
    return
end

fprintf('  %s: %s\n', name, strjoin(f(:)', ', '));
for k = 1:numel(f)
    child = f{k};
    try
        y = x.(child);
    catch
        continue
    end
    yf = {};
    try
        yf = fieldnames(y);
    catch
        try
            yf = properties(y);
        catch
        end
    end
    if isempty(yf), continue; end
    fprintf('  %s.%s: %s\n', name, child, strjoin(yf(:)', ', '));
end

end


%% ======================================================================
function printCandidate(sample, sideNames)
%PRINTCANDIDATE  Dump one eye's gaze-origin fields across SDK spellings.
%
% This took only snake_case (sample.left_eye.gaze_origin), which a real sample
% never has, so the lookup fell into its catch and the function returned having
% printed nothing -- it reported no track-box field under precisely the
% condition it exists to diagnose. PascalCase is the real SDK's spelling and is
% tried first.

[eyeData, sideUsed] = firstReadable(sample, sideNames);
if isempty(sideUsed), return; end

[origin, originUsed] = firstReadable(eyeData, {'GazeOrigin', 'gaze_origin'});
if isempty(originUsed)
    fprintf('\n%s has no gaze-origin field. Fields present:\n', sideUsed);
    printFields(eyeData, sideUsed);
    return
end

label = [sideUsed '.' originUsed];
fprintf('\nCandidate fields for %s:\n', label);
printFields(origin, label);
for name = {'InTrackBoxCoordinateSystem', 'in_track_box_coordinate_system', ...
            'position_in_track_box_coordinate_system', ...
            'InUserCoordinateSystem', 'in_user_coordinate_system', ...
            'Validity', 'validity'}
    try
        val = origin.(name{1});
        if isnumeric(val) || islogical(val)
            fprintf('  %s = %s\n', name{1}, mat2str(double(val(:)')));
        else
            fprintf('  %s = <%s>', name{1}, class(val));
            try
                fprintf(' .value = %s', mat2str(double(val.value)));
            catch
            end
            fprintf('\n');
        end
    catch
    end
end

end


%% ======================================================================
function [v, used] = firstReadable(s, names)
%FIRSTREADABLE  First readable field/property, with the name that worked.

v = []; used = '';
for k = 1:numel(names)
    try
        v = s.(names{k});
        used = names{k};
        return
    catch
    end
end

end
