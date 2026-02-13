classdef Sensor_v1_args

    properties
        Name      (1,1) string                  % Sensor display name
        Type      (1,1) string                  % Sensor category
        Value     (1,1) double      = NaN       % Most recent reading
        Units     (1,1) string      = ""        % Measurement units
        Timestamp (1,1) datetime    = NaT       % Time of last reading
        Offset    (1,1) double      = 0         % Calibration offset
    end

    methods
        function obj = Sensor(name, type, opts)
            arguments
                name  (1,1) string               % Sensor name
                type  (1,1) string               % Sensor type
                opts.Units (1,1) string = ""     % Measurement units
            end
            obj.Name = name;
            obj.Type = type;
            obj.Units = opts.Units;
        end

        function obj = read(obj, value)
            arguments
                obj
                value (1,1) double               % Raw sensor reading
            end
            obj.Value = value + obj.Offset;
            obj.Timestamp = datetime("now");
        end

        function obj = calibrate(obj, knownValue)
            arguments
                obj
                knownValue (1,1) double          % Known reference value
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
