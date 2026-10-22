classdef ValidityFake
    %VALIDITYFAKE The real SDK's Validity shape: an object exposing .value.
    % Mirrors the probe output in rig-checks: properties Invalid, Valid, value.
    properties
        Invalid = 0
        Valid = 1
        value
    end
    methods
        function obj = ValidityFake(v)
            obj.value = v;
        end
    end
end
