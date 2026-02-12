# DataLogger — Complex Handle Class

A handle class that logs timestamped numeric data to memory and file. This is the class equivalent of the "lots of help" function — it exercises every class-specific grammar feature in a single file.

## Grammar features exercised

| Feature | Where it appears |
|---------|-----------------|
| Class synopsis (first line) | `classdef` help block |
| `## Properties` with long descriptions keyed by name | Class help block — `Name`, `LogFile`, `SampleRate`, `BufferSize`, `IsRunning`, `NumSamples` |
| Property inline `%` descriptions | `properties` blocks |
| Property groups with access control | `properties (SetAccess = private)`, `properties (Access = protected)` |
| Handle class + inheritance | `classdef DataLogger < handle` |
| Events with inline descriptions | `events` block — `DataLogged`, `BufferFull`, `LoggingStarted`, `LoggingStopped` |
| Constructor with `## Input Arguments` and NV pairs | `DataLogger(name, LogFile=..., ...)` |
| Method help with `## Input Arguments` | `log`, `export` |
| Method help with `## Output Arguments` | `getData` |
| Method help with `## Examples` | `export` |
| `> [!WARNING]` callout | Class help block |
| `> [!NOTE]` callout | `start` method help |
| `## Version History` | Class help block |
| `## More About` with cross-links | Class help block |
| `See also` | Class help block |
