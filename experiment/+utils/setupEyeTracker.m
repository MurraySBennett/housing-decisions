function et = setupEyeTracker(cfg, window, doCalibrate)
%UTILS.SETUPEYETRACKER  Connect, calibrate, and start a Tobii recording.
%
%   Consolidated from the two copies that had drifted apart between the
%   auction and continuous-DC scripts.

if nargin < 3, doCalibrate = true; end

et.enabled     = cfg.et.enabled;
et.obj         = [];
et.mediaMode   = cfg.et.mediaMode;
et.showGaze    = cfg.et.mediaMode && cfg.et.showGaze;
et.calibrated  = false;
et.analyzable  = true;
et.requestedSampleRateHz = cfg.et.sampleRateHz;
et.actualSampleRateHz = NaN;

if ~et.enabled
    fprintf('Eye tracking disabled.\n');
    et.analyzable = false;
    return
end

% Media mode guard: showGaze is ignored unless mediaMode is explicitly set,
% and any run with the dot visible is flagged non-analyzable. A visible
% gaze dot creates a feedback loop -- participants chase it -- so this must
% never quietly end up in a real dataset.
if cfg.et.showGaze && ~cfg.et.mediaMode
    warning('hw:setupEyeTracker:gazeIgnored', ...
        'cfg.et.showGaze is set but cfg.et.mediaMode is false -- gaze dot NOT shown.');
    et.showGaze = false;
end
if et.showGaze
    et.analyzable = false;
    fprintf(2, '\n*** MEDIA MODE: gaze dot visible. This run is NOT analyzable. ***\n\n');
end

try
    Tobii = EyeTrackingOperations();
    trackers = Tobii.find_all_eyetrackers();
    if isempty(trackers)
        error('hw:setupEyeTracker:noTracker', 'No eye tracker found.');
    end
    et.obj = trackers(1);
    fprintf('Connected: %s (%s)\n', et.obj.Name, et.obj.SerialNumber);

    try
        et.actualSampleRateHz = et.obj.get_gaze_output_frequency();
    catch
    end

    if doCalibrate
        et.calibrated = utils.calibrate(et, window, cfg);
    end

    et.obj.get_gaze_data();     % clear any stale buffer before we start
catch ME
    warning('hw:setupEyeTracker:failed', ...
        'Eye tracker setup failed (%s). Continuing without tracking.', ME.message);
    et.enabled    = false;
    et.obj        = [];
    et.analyzable = false;
end

end
