# DataLogger — Complex Handle Class

A handle class that logs timestamped numeric data to memory and file. This is the class equivalent of the "lots of help" function — it exercises every class-specific grammar feature in a single file.

## Grammar features exercised

| Feature | Where it appears |
|---------|-----------------|
| Class synopsis (first line) | `classdef` help block |
| `## :properties` with long descriptions keyed by name | Class help block — `Name`, `LogFile`, `SampleRate`, `BufferSize`, `IsRunning`, `NumSamples` |
| Property inline `%` descriptions | `properties` blocks |
| Property groups with access control | `properties (SetAccess = private)`, `properties (Access = protected)` |
| Handle class + inheritance | `classdef DataLogger < handle` |
| Events with inline descriptions | `events` block — `DataLogged`, `BufferFull`, `LoggingStarted`, `LoggingStopped` |
| Constructor with `## :inputs` and NV pairs | `DataLogger(name, LogFile=..., ...)` |
| Method help with `## :inputs` | `log`, `export` |
| Method help with `## :outputs` | `getData` |
| Method help with `## :examples` | `export` |
| `> [!WARNING]` callout | Class help block |
| `> [!NOTE]` callout | `start` method help |
| `## :version-history` | Class help block |
| `## :more-about` with cross-links | Class help block |
| `See also` | Class help block |
