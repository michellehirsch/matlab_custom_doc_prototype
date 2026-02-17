# rescale — Progressive Enhancement Sample

A simple numeric utility (rescale data to a target range) used as the flagship example for the progressive enhancement story. All versions share the same code — only the comments change.

## Recommended Progression (Getting Started walkthrough)

This is the progression used in [GettingStarted.md](../../GettingStarted.md). Each step adds one concept.

| File | What it adds | Concept |
|------|-------------|---------|
| `rescale_v0_bare.m` | Just an `arguments` block, no help | Auto-generation from metadata alone |
| `rescale_v1_args.m` | Trailing `%` on each argument line | Inline argument short descriptions |
| `rescale_v2_plain.m` | Traditional `%` help block (synopsis, prose, plain-text example, `See also`) | Standard help block — argument descriptions from inline `%` merge in |
| `rescale_v3_help.m` | Same help with Markdown: backticks, fenced code block, `**bold**` | Opt-in to Markdown for richer rendering |
| `rescale_v4_argdoc.m` | Preceding `%` blocks before arguments in `arguments` block | Long argument descriptions (recommended approach) |
| `rescale_v5_sections.m` | `## Output Arguments`, `## Examples`, `## Tips`, `## Algorithms` (LaTeX math) | Structured sections |
| `rescale_v6_override.m` | `## Syntax` and `## Input Arguments` sections in help block | Overriding auto-generation for full control |

### What the progression shows

- **v0 → v1**: Adding inline `%` comments on argument lines gives auto-generated argument tables short descriptions.
- **v1 → v2**: Adding a traditional help block gives you a synopsis, description, and examples.
- **v2 → v3**: Adding Markdown formatting (backticks, fenced code blocks) gets richer rendering for free.
- **v3 → v4**: Adding preceding `%` blocks in the `arguments` block gives detailed argument descriptions — the recommended way to document arguments.
- **v4 → v5**: Adding `##` section headings creates structured page sections: examples, tips, algorithms with LaTeX math.
- **v5 → v6**: Adding `## Syntax` or `## Input Arguments` sections overrides auto-generation when you need full control.

## Earlier Variants (legacy)

These files predate the recommended progression and explore different combinations of features.

| File | What it demonstrates |
|------|---------------------|
| `rescale_v1_plain.m` | Classic MATLAB help style with `arguments` block but no inline descriptions |
| `rescale_v2_args.m` | Same help as v1_plain + inline `%` + Markdown markup |
| `rescale_v3_full.m` | Full `## Input/Output Arguments` sections, `## Examples`, `## Tips`, `## Algorithms`, LaTeX math |
