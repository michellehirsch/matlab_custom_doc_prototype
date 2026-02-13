classdef Sensor
% Sensor  Represent a sensor with a name, type, and current reading.
%
% A Sensor object stores metadata about a physical sensor and its most
% recent reading.  Use the read method to update the stored value and
% the calibrate method to apply a zero-offset correction.
%
% ## Examples
%   s = Sensor("Thermocouple", "temperature");
%   s = s.read(23.5);
%   disp(s.Value)
%
% See also datetime, timetable

    properties % Sensor information
        % Display name of the sensor, such as `"Thermocouple-01"`.
        % Used as a label in plots and log output. Must be a nonempty string.
        Name       % Sensor display name

        % Sensor category. Specify as a string such as
        % `"temperature"`, `"pressure"`, or `"humidity"`. The type is
        % informational and does not affect computation.
        Type        % Sensor category
    end

    properties % Sensor readings
        % Most recent reading, stored as a scalar double. The
        % value reflects the raw reading adjusted by the calibration `Offset`.
        % Initialized to `NaN` before the first reading.
        Value       % Most recent reading

        % Measurement unit string, such as `"C"`, `"Pa"`, or
        % `"%RH"`. Used for display and labeling only. Default is `""`.
        Units       % Measurement units

        % Time of the most recent reading, stored as a
        % `datetime`. Initialized to `NaT` before the first reading.
        Timestamp   % Time of last reading

        % Calibration offset applied to raw readings. Set by
        % the `calibrate` method. Default is `0`.
        Offset      % Calibration offset
    end

    methods
        function obj = Sensor(name, type, units)
        % Sensor  Create a Sensor object.
        %
        % S = Sensor(NAME, TYPE) creates a sensor with the given name
        % and type.
        %
        % S = Sensor(NAME, TYPE, UNITS) also specifies the measurement
        % units.  Default is "" (empty).
            arguments
                name                            % Display name for the sensor
                type                            % Category such as "temperature", "pressure", or "humidity"
                units = ""                      % Unit label such as "C", "Pa", or "%RH"
            end
            obj.Name = name;
            obj.Type = type;
            obj.Units = units;
            obj.Value = NaN;
            obj.Timestamp = NaT;
            obj.Offset = 0;
        end

        function obj = read(obj, value)
        % read  Record a new sensor reading.
        %
        % S = read(S, VALUE) stores VALUE as the current reading and
        % sets the timestamp to now.  The stored value is adjusted by
        % the calibration offset.
            arguments
                obj
                value                           % Raw sensor reading (scalar double)
            end
            obj.Value = value + obj.Offset;
            obj.Timestamp = datetime("now");
        end

        function obj = calibrate(obj, knownValue)
        % calibrate  Calibrate the sensor against a known reference.
        %
        % S = calibrate(S, KNOWNVALUE) calculates a zero-offset
        % correction so that future readings are adjusted to match
        % the known reference value.
            arguments
                obj
                knownValue                      % Reference value from a calibration standard
            end
            obj.Offset = knownValue - obj.Value;
        end

        function obj = reset(obj)
        % reset  Clear the current reading and calibration offset.
            obj.Value = NaN;
            obj.Timestamp = NaT;
            obj.Offset = 0;
        end
    end
end
