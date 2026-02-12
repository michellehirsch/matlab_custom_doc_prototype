classdef Sensor
% Sensor  Represent a sensor with a name, type, and current reading.
%
% A Sensor object stores metadata about a physical sensor and its most
% recent reading.  Use the read method to update the stored value and
% the calibrate method to apply a zero-offset correction.
%
% Example
%   s = Sensor("Thermocouple", "temperature");
%   s = s.read(23.5);
%   disp(s.Value)
%
% See also datetime, timetable

    properties
        Name
        Type
        Value
        Units
        Timestamp
        Offset
    end

    methods
        function obj = Sensor(name, type, units)
        % Sensor  Create a Sensor object.
        %
        % S = Sensor(NAME, TYPE) creates a sensor with the given name
        % and type.  TYPE is a string such as "temperature", "pressure",
        % or "humidity".
        %
        % S = Sensor(NAME, TYPE, UNITS) also specifies the measurement
        % units, such as "C", "Pa", or "%RH".  Default is "" (empty).
            if nargin < 3
                units = "";
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
            obj.Value = value + obj.Offset;
            obj.Timestamp = datetime("now");
        end

        function obj = calibrate(obj, knownValue)
        % calibrate  Calibrate the sensor against a known reference.
        %
        % S = calibrate(S, KNOWNVALUE) calculates a zero-offset
        % correction so that future readings are adjusted to match
        % the known reference value.
            obj.Offset = knownValue - obj.Value;
        end

        function reset(obj)
        % reset  Clear the current reading and calibration offset.
            obj.Value = NaN;
            obj.Timestamp = NaT;
            obj.Offset = 0;
        end
    end
end
