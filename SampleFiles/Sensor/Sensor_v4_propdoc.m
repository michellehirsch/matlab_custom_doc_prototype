classdef Sensor
% Sensor  Represent a sensor with a name, type, and current reading.
%
% A `Sensor` object stores metadata about a physical sensor and its
% most recent reading. Use the `read` method to update the stored
% value and the `calibrate` method to apply a zero-offset correction.
%
% ## Examples
%
% ```matlab
% s = Sensor("Thermocouple-01", "temperature", Units="C");
% s = s.read(23.5);
% disp(s.Value)
% ```
%
% See also datetime, timetable

    properties
        % Display name of the sensor, such as `"Thermocouple-01"`.
        % Used as a label in plots and log output.
        Name      (1,1) string                  % Sensor display name

        % Sensor category. Specify as a string such as
        % `"temperature"`, `"pressure"`, or `"humidity"`. The type is
        % informational and does not affect computation.
        Type      (1,1) string                  % Sensor category

        % Most recent reading, stored as a scalar double. The value
        % reflects the raw reading adjusted by the calibration `Offset`.
        % Initialized to `NaN` before the first reading.
        Value     (1,1) double      = NaN       % Most recent reading

        % Measurement unit string, such as `"C"`, `"Pa"`, or `"%RH"`.
        % Used for display and labeling only.
        Units     (1,1) string      = ""        % Measurement units

        % Time of the most recent reading, stored as a `datetime`.
        % Initialized to `NaT` before the first reading.
        Timestamp (1,1) datetime    = NaT       % Time of last reading

        % Calibration offset applied to raw readings. Set by the
        % `calibrate` method.
        Offset    (1,1) double      = 0         % Calibration offset
    end

    methods
        function obj = Sensor(name, type, opts)
        % Sensor  Create a `Sensor` object.
        %
        % `s = Sensor(name, type)` creates a sensor with the given name
        % and type.
        %
        % `s = Sensor(name, type, Units=u)` also specifies the
        % measurement units.
            arguments
                % Display name for the sensor. Specify as a string or
                % character vector.
                name  (1,1) string               % Sensor name

                % Sensor category. Specify as a string such as
                % `"temperature"`, `"pressure"`, or `"humidity"`.
                type  (1,1) string               % Sensor type

                % Measurement unit label. Specify as a string such as
                % `"C"`, `"Pa"`, or `"%RH"`.
                opts.Units (1,1) string = ""     % Measurement units
            end
            obj.Name = name;
            obj.Type = type;
            obj.Units = opts.Units;
        end

        function obj = read(obj, value)
        % read  Record a new sensor reading.
        %
        % `s = read(s, value)` stores `value` as the current reading
        % and records the timestamp. The stored value is adjusted by
        % the calibration `Offset`.
            arguments
                obj
                % Raw sensor reading. Specify as a scalar double. The
                % calibration offset is added before storing.
                value (1,1) double               % Raw sensor reading
            end
            obj.Value = value + obj.Offset;
            obj.Timestamp = datetime("now");
        end

        function obj = calibrate(obj, knownValue)
        % calibrate  Calibrate the sensor against a known reference.
        %
        % `s = calibrate(s, knownValue)` computes a zero-offset
        % correction so that future readings align with the known
        % reference value.
            arguments
                obj
                % Reference value from a calibration standard. Specify
                % as a scalar double.
                knownValue (1,1) double          % Known reference value
            end
            obj.Offset = knownValue - obj.Value;
        end

        function obj = reset(obj)
        % reset  Clear the current reading and calibration offset.
        %
        % `s = reset(s)` sets `Value` to `NaN`, `Timestamp` to `NaT`,
        % and `Offset` to `0`.
            obj.Value = NaN;
            obj.Timestamp = NaT;
            obj.Offset = 0;
        end
    end
end
