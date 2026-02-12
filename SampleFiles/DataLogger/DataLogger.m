classdef DataLogger < handle
% DataLogger  Log timestamped data to memory and file.
%
% A `DataLogger` object collects timestamped numeric data into an
% in-memory buffer and optionally writes it to a CSV log file. The
% logger supports configurable buffer sizes, automatic flushing, and
% event notifications.
%
% `DataLogger` is a handle class, so all methods modify the object
% in place without needing to reassign the output.
%
% ## Properties
%
% `Name` — Display name for the logger. Used as a label in log file
% headers and diagnostic messages. Default is `"Untitled"`.
%
% `LogFile` — Path to the output CSV file. Specify as a string.
% When empty (`""`), data is buffered in memory only and not written
% to disk. Can be set before calling `start` or changed while logging
% (the new file takes effect on the next flush).
%
% `SampleRate` — Expected sample rate in Hz. Informational only;
% the logger does not enforce sample timing. Used to populate log
% file metadata. Default is `1`.
%
% `BufferSize` — Maximum number of samples to hold in memory before
% auto-flushing to disk. When the buffer reaches this limit, the
% `BufferFull` event fires and, if `LogFile` is set, data is written
% to disk and the buffer is cleared. Default is `10000`.
%
% `IsRunning` — Indicates whether the logger is actively accepting
% data. Read-only. Set to `true` by `start` and `false` by `stop`.
%
% `NumSamples` — Total number of samples logged since the last
% `start`, including samples already flushed to disk. Read-only.
%
% ## Examples
%
% ### Basic in-memory logging
%
% ```matlab
% dl = DataLogger("Experiment-1");
% dl.start();
% for k = 1:100
%     dl.log(randn());
% end
% dl.stop();
% data = dl.getData();
% plot(data.Time, data.Value)
% ```
%
% ### Logging to a CSV file
%
% ```matlab
% dl = DataLogger("TempSensor", LogFile="temperature_log.csv", ...
%     SampleRate=10, BufferSize=500);
% dl.start();
% % ... acquire data in a loop ...
% dl.stop();
% ```
%
% ### Responding to events
%
% ```matlab
% dl = DataLogger("PressureLog", BufferSize=1000);
% addlistener(dl, 'BufferFull', @(src,~) disp("Buffer full!"));
% addlistener(dl, 'LoggingStopped', @(src,~) disp("Done."));
% dl.start();
% % ... log data ...
% dl.stop();
% ```
%
% ## Tips
%
% - Set `BufferSize` based on available memory and desired flush
%   frequency. Smaller buffers flush more often, reducing data loss
%   risk; larger buffers reduce I/O overhead.
% - Listen to the `BufferFull` event to trigger processing pipelines
%   on each batch of data.
% - Call `export` after logging to save the complete dataset in one
%   file, regardless of how many buffer flushes occurred.
%
% > [!WARNING]
% > If `LogFile` is not set and the buffer fills, data is **not
% > lost** — the `BufferFull` event fires but the buffer continues
% > growing beyond `BufferSize`. Set a log file for long-running
% > acquisitions.
%
% ## Version History
%
% **Introduced in v1.0**
%
% **v1.1** — Added `export` method and `NumSamples` property.
%
% **v1.2** — Added `BufferFull` event and auto-flush behavior.
%
% ## More About
%
% - [Logging Best Practices](logging-best-practices.html)
% - [Working with Timetables](matlab:doc('timetable'))
%
% See also timetable, fwrite, event.EventData

    events
        DataLogged       % Fires after each call to log()
        BufferFull       % Fires when buffer reaches BufferSize
        LoggingStarted   % Fires when start() is called
        LoggingStopped   % Fires when stop() is called
    end

    properties
        Name       (1,1) string  = "Untitled"   % Logger display name
        LogFile    (1,1) string  = ""            % Path to output CSV file
        SampleRate (1,1) double  = 1             % Expected sample rate (Hz)
        BufferSize (1,1) double ...
                   {mustBePositive, ...
                   mustBeInteger} = 10000        % Max buffer size before flush
    end

    properties (SetAccess = private)
        IsRunning  (1,1) logical = false         % True while actively logging
        NumSamples (1,1) double  = 0             % Total samples since start
    end

    properties (Access = protected)
        Buffer     (:,1) double  = double.empty(0,1) % In-memory data buffer
        TimeBuffer (:,1) datetime = datetime.empty(0,1) % Timestamps for buffered data
        StartTime  (1,1) datetime = NaT          % Time logging began
    end

    methods
        function obj = DataLogger(name, opts)
        % DataLogger  Create a DataLogger object.
        %
        % `dl = DataLogger(name)` creates a logger with the specified
        % display name.
        %
        % `dl = DataLogger(name, LogFile=f, SampleRate=r, BufferSize=n)`
        % sets optional configuration properties at construction.
        %
        % ## Input Arguments
        %
        % `name` — Display name for the logger.
        %
        % `opts.LogFile` — Path to output CSV file. Default is `""`.
        %
        % `opts.SampleRate` — Expected sample rate in Hz. Default
        % is `1`.
        %
        % `opts.BufferSize` — Maximum buffer size. Default is
        % `10000`.
            arguments
                name           (1,1) string            % Logger name
                opts.LogFile   (1,1) string  = ""      % Output file path
                opts.SampleRate (1,1) double = 1       % Sample rate (Hz)
                opts.BufferSize (1,1) double ...
                    {mustBePositive, mustBeInteger} ...
                               = 10000                 % Buffer size
            end
            obj.Name = name;
            obj.LogFile = opts.LogFile;
            obj.SampleRate = opts.SampleRate;
            obj.BufferSize = opts.BufferSize;
        end

        function start(obj)
        % start  Begin a logging session.
        %
        % `start(dl)` marks the logger as running, clears the buffer,
        % and records the start time. Fires the `LoggingStarted` event.
        %
        % > [!NOTE]
        % > Calling `start` while already running first calls `stop`,
        % > which flushes the buffer and fires `LoggingStopped`.
            if obj.IsRunning
                obj.stop();
            end
            obj.Buffer = double.empty(0,1);
            obj.TimeBuffer = datetime.empty(0,1);
            obj.NumSamples = 0;
            obj.StartTime = datetime("now");
            obj.IsRunning = true;
            notify(obj, 'LoggingStarted');
        end

        function stop(obj)
        % stop  End the logging session.
        %
        % `stop(dl)` flushes any remaining buffered data to the log
        % file (if configured), marks the logger as stopped, and fires
        % the `LoggingStopped` event.
            if ~obj.IsRunning
                return
            end
            obj.flush();
            obj.IsRunning = false;
            notify(obj, 'LoggingStopped');
        end

        function log(obj, value)
        % log  Record a data sample.
        %
        % `log(dl, value)` appends a timestamped sample to the buffer.
        % If the buffer reaches `BufferSize`, it is automatically
        % flushed. Fires `DataLogged` after each sample and
        % `BufferFull` when the buffer reaches capacity.
        %
        % ## Input Arguments
        %
        % `value` — Scalar numeric value to record.
            arguments
                obj
                value (1,1) double               % Value to log
            end
            if ~obj.IsRunning
                error("DataLogger:NotRunning", ...
                    "Logger '%s' is not running. Call start() first.", ...
                    obj.Name);
            end
            obj.Buffer(end+1,1) = value;
            obj.TimeBuffer(end+1,1) = datetime("now");
            obj.NumSamples = obj.NumSamples + 1;
            notify(obj, 'DataLogged');
            if numel(obj.Buffer) >= obj.BufferSize
                notify(obj, 'BufferFull');
                if obj.LogFile ~= ""
                    obj.flush();
                end
            end
        end

        function tt = getData(obj)
        % getData  Return buffered data as a timetable.
        %
        % `tt = getData(dl)` returns the currently buffered data as a
        % timetable with columns `Time` and `Value`.
        %
        % ## Output Arguments
        %
        % `tt` — Buffered data, returned as a `timetable`. The
        % `Time` variable contains `datetime` timestamps and `Value`
        % contains the logged numeric values.
            tt = timetable(obj.TimeBuffer, obj.Buffer, ...
                'VariableNames', {'Value'});
        end

        function clear(obj)
        % clear  Discard all buffered data without writing to file.
            obj.Buffer = double.empty(0,1);
            obj.TimeBuffer = datetime.empty(0,1);
        end

        function export(obj, filename)
        % export  Save buffered data to a CSV file.
        %
        % `export(dl, filename)` writes the current buffer contents
        % to the specified CSV file. Unlike the automatic flush
        % mechanism, `export` does not clear the buffer afterward.
        %
        % ## Input Arguments
        %
        % `filename` — Output file path. Specify as a string.
        %
        % ## Examples
        %
        % ```matlab
        % dl = DataLogger("Experiment");
        % dl.start();
        % for k = 1:50
        %     dl.log(randn());
        % end
        % dl.stop();
        % dl.export("experiment_results.csv");
        % ```
            arguments
                obj
                filename (1,1) string            % Output file path
            end
            tt = obj.getData();
            writetimetable(tt, filename);
        end
    end

    methods (Access = protected)
        function flush(obj)
        % flush  Write buffered data to the log file and clear buffer.
            if obj.LogFile ~= "" && ~isempty(obj.Buffer)
                tt = obj.getData();
                writetimetable(tt, obj.LogFile, 'WriteMode', 'append');
                obj.clear();
            end
        end
    end
end
