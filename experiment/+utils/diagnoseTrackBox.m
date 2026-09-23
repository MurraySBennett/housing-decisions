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

    printCandidate(sample, 'left_eye');
    printCandidate(sample, 'right_eye');
catch ME
    fprintf('Track-box diagnostic failed: %s\n', ME.message);
end

end


%% ======================================================================
function printFields(x, name)
try
    f = fieldnames(x);
catch
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
    try
        yf = fieldnames(y);
    catch
        continue
    end
    fprintf('  %s.%s: %s\n', name, child, strjoin(yf(:)', ', '));
end

end


%% ======================================================================
function printCandidate(sample, side)
try
    eye = sample.(side);
    origin = eye.gaze_origin;
catch
    return
end

fprintf('\nCandidate fields for %s.gaze_origin:\n', side);
printFields(origin, [side '.gaze_origin']);
for name = {'in_track_box_coordinate_system', ...
            'position_in_track_box_coordinate_system', ...
            'in_user_coordinate_system'}
    try
        val = origin.(name{1});
        fprintf('  %s = %s\n', name{1}, mat2str(double(val(:)')));
    catch
    end
end

end
