# Sensor — Progressive Enhancement Sample (Class)

A simple value class (sensor with name, type, and current reading) used as the class example for the progressive enhancement story. All versions share the same code — only the comments change.

## Recommended Progression

Each step adds one concept, mirroring the [rescale](../rescale/) function progression but for class-specific features.

| File | What it adds | Concept |
|------|-------------|---------|
| `Sensor_v0_bare.m` | `classdef` + typed `properties` + methods with `arguments` blocks, no comments | Auto-generation from class metadata alone |
| `Sensor_v1_args.m` | Trailing `%` on property lines and method argument lines | Inline short descriptions for properties and arguments |
| `Sensor_v2_plain.m` | Traditional `%` help block on `classdef` and each method | Standard help — inline descriptions merge into auto-generated tables |
| `Sensor_v3_help.m` | Same help with Markdown: backticks, fenced code blocks | Opt-in to Markdown for richer rendering |
| `Sensor_v4_propdoc.m` | Preceding `%` blocks before properties and method arguments | Long descriptions (recommended approach) |
| `Sensor_v5_sections.m` | `## Properties`, `## Input Arguments`, `## Examples` with subsections | Structured sections for professional layout |
| `Sensor_v6_override.m` | `## Syntax` on constructor, property groups | Overriding auto-generation for full control |

### What the progression shows

- **v0 → v1**: Adding inline `%` comments on property and argument lines gives auto-generated tables short descriptions.
- **v1 → v2**: Adding traditional help blocks gives synopsis, description, and examples for the class and each method.
- **v2 → v3**: Adding Markdown formatting (backticks, fenced code blocks) gets richer rendering for free.
- **v3 → v4**: Adding preceding `%` blocks in `properties` and `arguments` blocks gives detailed descriptions — the recommended way to document properties and arguments.
- **v4 → v5**: Adding `##` section headings creates structured page sections: property docs, argument docs, examples with subsections.
- **v5 → v6**: Adding `## Syntax` and property groups overrides auto-generation when you need full control.

## Earlier Variants (legacy)

These files predate the recommended progression and explore different feature combinations.

| File | What it demonstrates |
|------|---------------------|
| `legacy/Sensor_v1_plain.m` | Traditional class help, no `arguments` blocks, no property types |
| `legacy/Sensor_v2_inline.m` | Inline `%` + preceding blocks on properties, `arguments` blocks on methods |
| `legacy/Sensor_v3_full.m` | Full structured sections, named-value constructor, type/size constraints |
