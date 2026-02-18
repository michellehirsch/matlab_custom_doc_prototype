# smoothts — Complex Function with Lots of Help

A time series smoother with multiple call forms and name-value options. This example exercises the most grammar features in a single function file.

## Variants

| File | Key features exercised |
|------|----------------------|
| `smoothts_v1_plain.m` | Traditional help documenting multiple call forms in prose. No `arguments` block. Positional API (`method`, `window` as positional args). Shows how conventional help handles a complex function. |
| `smoothts_v3_full.m` | The full grammar: `## Syntax` override (multiple call forms), `## Input Arguments` with NV-pair long descriptions (enumerated options with defaults), `## Output Arguments`, multiple `## Examples`, `## Algorithms` (math-heavy with LaTeX), `## Tips` with `> [!NOTE]` callout, `## References`, `See also`. Redesigned API uses name-value pairs via `arguments` block. |

## Block-Comment Variants

| File | Line-comment counterpart | What it demonstrates |
|------|--------------------------|---------------------|
| `smoothts_v3_full_block.m` | `smoothts_v3_full.m` | Full grammar in block-comment form: `## Syntax`, `## Input/Output Arguments`, `## Examples`, `## Algorithms` (LaTeX), `## Tips`, `## References`, `See also` — all as bare Markdown text. |

## Design notes

The two variants intentionally use slightly different APIs (positional vs. name-value) to reflect how a real function might evolve its interface. The v1 traditional approach uses positional arguments; the v3 version uses name-value pairs, which is the modern MATLAB convention and generates richer auto-documented argument tables.
