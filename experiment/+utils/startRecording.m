function recording = startRecording(et)
%UTILS.STARTRECORDING One bounded gaze recording; gaps between blocks are explicit.
%
% Subscribes and drains pre-block samples -- no task stimulus has started yet
% -- and anchors the Tobii clock to PTB time. utils.drainRecording closes the
% recording and returns the samples.
%
% Guarded like clockSync.m:12 and gazeBuffer.m:22: a failed setupEyeTracker
% can leave et non-struct, and bare et.enabled then throws "Dot indexing is
% not supported" at the first block.
if isstruct(et) && et.enabled && ~isempty(et.obj), et.obj.get_gaze_data(); end
recording = struct('store', utils.gazeBuffer('init'), ...
    'clockSync', struct('start', utils.clockSync(et), 'end', []));
end
