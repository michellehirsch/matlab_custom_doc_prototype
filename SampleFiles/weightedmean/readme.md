# weightedmean — Progressive Documentation Example

Compute the weighted mean of an array, with options for method (arithmetic, harmonic, geometric), NaN handling, and confidence intervals.

This example demonstrates six levels of documentation for the same function. The code is identical across all versions — only the comments change.

## Arguments block features exercised

- Required positional with no size constraint (`x double`)
- Optional positional with empty default (`w double = []`)
- Scalar with chained validators (`dim (1,1) double {mustBeNonnegative, mustBeInteger} = 0`)
- Name-value with `mustBeMember` enum (`Method`, `NanFlag`)
- Name-value with logical type (`Normalize`)
- Name-value with `mustBeInRange` validator (`Confidence`)
- Multiple outputs (`[m, ci]`)

## Versions

| File | Documentation level | What it adds |
|------|-------------------|--------------|
| `v0_bare` | None | No help comments at all — tests what auto-generation gives for free |
| `v1_args` | Inline argument comments | Trailing `%` on each arguments line |
| `v2_help` | Traditional help block | H1 line, description, prose argument descriptions, indented example, See also |
| `v3_markup` | Markdown formatting | Backtick code, **bold**, fenced code block — same content, richer rendering |
| `v4_sections` | Custom sections | `## Examples` (two subsections) and `## Tips` |
| `v5_override` | Section override | `## Syntax` overrides the auto-generated syntax block |
