classdef Sensor_v0_bare

    properties
        Name      (1,1) string
        Type      (1,1) string
        Value     (1,1) double      = NaN
        Units     (1,1) string      = ""
        Timestamp (1,1) datetime    = NaT
        Offset    (1,1) double      = 0
    end

    methods
        function obj = Sensor(name, type, opts)
            arguments
                name  (1,1) string
                type  (1,1) string
                opts.Units (1,1) string = ""
            end
            obj.Name = name;
            obj.Type = type;
            obj.Units = opts.Units;
        end

        function obj = read(obj, value)
            arguments
                obj
                value (1,1) double
            end
            obj.Value = value + obj.Offset;
            obj.Timestamp = datetime("now");
        end

        function obj = calibrate(obj, knownValue)
            arguments
                obj
                knownValue (1,1) double
            end
            obj.Offset = knownValue - obj.Value;
        end

        function obj = reset(obj)
            obj.Value = NaN;
            obj.Timestamp = NaT;
            obj.Offset = 0;
        end
    end
end
