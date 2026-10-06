classdef FakeGazeTracker < handle
    properties
        reads = 0
        stopped = false
    end
    methods
        function samples = get_gaze_data(obj)
            obj.stopped = false;
            obj.reads = obj.reads + 1;
            % A new subscription/drain gets no task samples. Each subsequent
            % poll gets different-sized chunks, to expose order/count loss.
            if obj.reads == 1 || obj.reads == 5
                samples = [];
            else
                samples = repmat(struct('SystemTimeStamp',uint64(0)),obj.reads,1);
                for k = 1:numel(samples)
                    samples(k).SystemTimeStamp = uint64(100*obj.reads+k);
                end
            end
        end
        function stop_gaze_data(obj)
            obj.stopped = true;
        end
    end
end
