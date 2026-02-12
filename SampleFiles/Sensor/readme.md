# Sensor — Simple Value Class

A value class representing a physical sensor with a name, type, and current reading. Exercises class-level documentation grammar at two levels.

## Variants

| File | Key features exercised |
|------|----------------------|
| `Sensor_v1_plain.m` | `classdef` with traditional help comment. Properties with no inline descriptions and no type/size constraints. Methods with plain help. Shows the class documentation baseline. |
| `Sensor_v3_full.m` | Class synopsis, `## Properties` section with long descriptions keyed by name, property inline `%` descriptions with type/size constraints, constructor with `## Input Arguments` and NV pairs, method help with `## Input Arguments`, `## Examples` at class level, `See also`. |

## What the progression shows

- **v1 → v3**: Adding property constraints and inline `%` descriptions auto-generates a structured property table. The `## Properties` section adds long-form detail. Method help gains structured argument documentation. Class-level `## Examples` provide usage context on the class page.
