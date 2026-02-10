# rescale — Progressive Enhancement Sample

A simple numeric utility (rescale data to a target range) shown at four documentation levels. This is the flagship example for the progressive enhancement story.

## Variants

| File | Help? | `arguments` block? | Markdown / Sections? | What it demonstrates |
|------|-------|---------------------|----------------------|----------------------|
| `rescale_v0_bare.m` | None | Yes (no inline descriptions) | — | Zero effort baseline: what the renderer produces from just a function signature and `arguments` block |
| `rescale_v1_plain.m` | Traditional | No | No | Classic MATLAB help style: synopsis, prose, plain-text examples. No `arguments` block. |
| `rescale_v2_args.m` | Traditional | Yes, with inline `%` | No | Same help as v1, but the `arguments` block with inline descriptions auto-generates formatted argument tables |
| `rescale_v3_full.m` | Rich | Yes, with inline `%` | `## Input/Output Arguments`, `## Examples`, `## Tips`, `## Algorithms`, `See also`, LaTeX math | Full expressiveness with every relevant grammar feature |

## What the progression shows

- **v0 → v1**: Adding traditional help comments gives you a synopsis, description, and examples — the basics.
- **v1 → v2**: Adding an `arguments` block (with inline `%` descriptions) auto-generates structured argument tables. The help text can be simpler because argument types/defaults come from the `arguments` block.
- **v2 → v3**: Adding `##` sections and Markdown gives you structured rendering: separate argument detail sections, fenced code examples with syntax highlighting, LaTeX math for the algorithm, tips, and hyperlinked See-also.
