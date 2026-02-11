# MATLAB Custom Documentation Framework — Functional Specification

*Draft: 2026-02-10*

---

## Overview

The MATLAB Custom Documentation Framework enables authors to write richly formatted reference documentation directly in `.m` source files using an enhanced comment grammar. Documentation is rendered as formatted HTML when users invoke the `doc` command, matching the quality and structure of official MATLAB documentation pages. Authoring requires no tooling beyond the MATLAB Editor.

---

## Goals

- **Zero baseline effort**: any existing `.m` file with standard help comments produces a usable doc page with no modification
- **Progressive enhancement**: authors can add markup incrementally for richer output
- **Authoring-first**: the grammar is designed to be pleasant to write and read in plain text
- **MATLAB-native structure**: rendered output matches the structure and visual style of MATLAB's official function and class reference pages
- **Docbook generation**: a single command scans a folder/package and generates a navigable documentation site
- **WYSIWYG compatibility**: help comments can optionally be rendered and edited richly in the MATLAB Editor without changing the file format

## Non-Goals

- Generating prose tutorials or conceptual guides — this framework targets API reference pages
- Replacing `.mlx` Live Scripts for narrative documentation
- Maintaining compatibility with third-party doc tools (Sphinx, Doxygen, etc.)

---

## Help Comment Grammar

### What Constitutes a Help Comment

A **help comment block** is a contiguous block of `%`-prefixed comment lines immediately following a function or class declaration. This is consistent with existing MATLAB behavior for `help` and `doc`.

```matlab
function out = myFunc(x, opts)
% myFunc  Brief one-line description of myFunc.
%
% This paragraph begins the description. It may span multiple lines.
% Markdown formatting is supported throughout.
```

For classes, the help comment block follows the `classdef` line. Help comments end at the first non-comment line (typically the `arguments` block or function body).

### Markdown Support

Help comments support a Markdown subset for formatting. The `% ` prefix is stripped before parsing; the remainder is treated as Markdown.

**Supported syntax:**

| Syntax | Renders as |
|---|---|
| `**text**` | Bold |
| `_text_` | Italic |
| `` `code` `` | Inline code |
| ```` ```matlab ... ``` ```` | Code block (syntax highlighted) |
| `## Heading` | Section heading |
| `### Heading` | Subsection heading |
| `- item` | Unordered list |
| `1. item` | Ordered list |
| `[text](url)` | Hyperlink |
| `![alt](path)` | Image |
| `$...$` | Inline math (LaTeX) |
| `$$...$$` | Display math (LaTeX) |

Markdown syntax is stripped (not rendered) by the `help` command, which displays plain text as today. In a future richer command window, basic Markdown rendering (bold, code) may be supported where the terminal allows it.

### The First Line (Synopsis)

The first line of a help comment has special significance:

```matlab
% myFunc  Brief one-line description.
```

- The leading token matching the function/class name (case-insensitive) is recognized and stripped from the rendered body
- The remainder becomes the **synopsis** — the one-line description displayed in index pages and at the top of the rendered doc page
- This matches the existing MATLAB `help` convention and requires no change to existing files

---

## Auto-Generated Page Sections

The renderer automatically generates the following page sections from file metadata and help comments. No explicit tagging is required.

### Title
The function or class name, formatted as the page title.

### Synopsis
From the first help comment line (see above).

### Syntax Block and Description

The compact syntax block at the top of the page and the Description section below it are tightly coupled, mirroring the structure of MathWorks doc pages: each calling form in the syntax block has a corresponding description paragraph. The framework supports three modes for populating these, applied in priority order:

**Priority 1 — `## Syntax` section (explicit full control).**
When the author includes a `## Syntax` section in the help comment block, it is the sole source for the syntax block and syntax-description pairs. Auto-generation does not run. See `## Syntax` under **Optional Enhancement Sections** below for the grammar.

**Priority 2 — Calling-form paragraphs in the description text.**
If no `## Syntax` section exists, the renderer scans the freeform description (the help text before any `##` heading) for **calling-form paragraphs** — paragraphs whose first element is a backtick-wrapped expression containing the function name and `(`. These paragraphs serve double duty:

- The calling form (the backtick-wrapped portion) is extracted into the compact syntax block
- The full paragraph renders as a syntax-description pair in the Description section

Any description paragraphs that are *not* calling-form paragraphs render as introductory prose before the syntax-description pairs. When the author writes calling-form paragraphs, auto-generation does not run — the author's forms are the complete set.

**Example** — this is the traditional MATLAB help pattern, minimally enhanced with backtick wrapping:

```matlab
% weightedmean  Compute the weighted mean of an array.
%
% `m = weightedmean(x)` computes the arithmetic mean of the elements of
% `x`, using uniform weights.
%
% `m = weightedmean(x, w)` uses the weights in `w`.  `w` must be the
% same size as `x`.
%
% `m = weightedmean(x, w, dim)` operates along dimension `dim`.
%
% `___ = weightedmean(___, Name=Value)` specifies options using one or
% more name-value arguments.
%
% `[m, ci] = weightedmean(___)` also returns a confidence interval.
```

The renderer extracts five calling forms for the compact syntax block and renders five syntax-description pairs in the Description section.

**Priority 3 — Auto-generation from `metafunction` (zero-effort fallback).**
If neither a `## Syntax` section nor calling-form paragraphs exist, the renderer auto-generates the syntax block from function metadata. This is the zero-effort baseline: any function with an `arguments` block gets a useful syntax section with no authoring required.

Auto-generation uses `metafunction` (R2026a) to introspect `Signature.Inputs` and `Signature.Outputs`, then generates calling forms following these rules:

1. **Required-only form** — only required positional inputs, first declared output:
   `out = f(req1, req2)`
2. **Progressive optionals** — one additional line per optional positional input (cumulative):
   `out = f(req1, opt1)`, then `out = f(req1, opt1, opt2)`, etc.
3. **Name-value indicator** — if any name-value arguments exist:
   `___ = f(___, Name=Value)`
4. **Multiple outputs** — if the function declares 2+ outputs:
   `[out1, out2] = f(___)`

**Example** — `weightedmean(x, w, dim, opts)` where `x` is required, `w` and `dim` are optional positional, and `opts` contains name-value arguments. The function declares two outputs `[m, ci]`. Auto-generation produces:

```
m = weightedmean(x)
m = weightedmean(x, w)
m = weightedmean(x, w, dim)
___ = weightedmean(___, Name=Value)
[m, ci] = weightedmean(___)
```

Auto-generated forms have no descriptions — only the compact syntax block is rendered. To add descriptions, the author graduates to Priority 2 (calling-form paragraphs) or Priority 1 (`## Syntax`).

**Legacy fallback** — if the function has no `arguments` block (`Signature.HasInputValidation` is false), or if `metafunction` is unavailable, the renderer strips the `function` keyword from the declaration line.

**Calling-form detection heuristic:** A paragraph is recognized as a calling-form paragraph if its first inline element is a backtick-wrapped expression containing the function name followed by `(`. Plain-text calling forms (without backticks) are treated as regular prose for backward compatibility — existing unenhanced help text renders as an unstructured Description, the same as today.

### Input Arguments
Auto-generated from the `arguments` block for inputs. Each entry includes:
- **Name** — from the argument declaration
- **Size/type constraints** — from the `arguments` block
- **Default value** — from the `arguments` block
- **Short description** — from the inline trailing comment on the argument line (see below)
- **Long description** — from a matching entry in a `## Input Arguments` section in the help block, if present

Name-value arguments (`opts.Name` style) are rendered in a separate **Name-Value Arguments** subsection, consistent with MATLAB doc conventions.

### Output Arguments
Short descriptions come from an `## Output Arguments` section in the help block, keyed by argument name. If an `arguments` output block is present, size/type constraints are pulled from it automatically; otherwise the description stands alone. This symmetric design means input and output arguments are documented the same way, and output arguments never require an `arguments` block to be documented.

### See Also
If the help block contains a line beginning with `See also` (case-insensitive), the referenced names are rendered as hyperlinks to their respective doc pages. This matches the existing MATLAB convention requiring no new syntax.

```matlab
% See also interp1, griddedInterpolant
```

---

## Argument Documentation Grammar

### Inline Short Description

A trailing `%` comment on an argument line in the `arguments` block provides the short description:

```matlab
arguments
    x              (1,:) double              % Input signal, real or complex-valued
    opts.Method    string = "linear"         % Interpolation method
    opts.Verbose   (1,1) logical = false     % Enable verbose output
end
```

The inline comment should be a single concise phrase or sentence. It appears in argument summary tables in the rendered output.

### Long-Form Descriptions

For input arguments requiring more explanation, a `## Input Arguments` section in the help comment block provides extended descriptions, keyed by argument name (matched case-sensitively). Output arguments are documented in a `## Output Arguments` section using the same pattern.

```matlab
% myFunc  Interpolate signal x using the specified method.
%
% Extended description of the function...
%
% ## Input Arguments
%
% **x** — Input signal. Can be real or complex valued. Must be a
% nonempty row vector. The function does not validate monotonicity.
%
% **opts.Method** — Interpolation method. Specify as one of:
%
%   - `"linear"` *(default)* — piecewise linear interpolation
%   - `"cubic"` — cubic Hermite interpolation
%   - `"spline"` — not-a-knot spline interpolation
%
% **opts.Verbose** — When `true`, prints progress to the command window.
%
% ## Output Arguments
%
% **out** — Interpolated values, returned as a row vector the same
% length as `xi`.
%
function out = myFunc(x, opts)
    arguments
        x              (1,:) double              % Input signal
        opts.Method    string = "linear"         % Interpolation method
        opts.Verbose   (1,1) logical = false     % Enable verbose output
    end
```

The renderer merges inline and long-form descriptions: if a long-form entry exists for an argument, it appears in the argument detail section; the inline comment still populates summary tables. If no long-form entry exists, the inline comment serves both roles.

**Rationale for this design:** Inline-only descriptions are insufficient for arguments with multiple options, complex behavior, or type nuances. The `opts.Method` example above — with three named options and their descriptions — cannot be expressed cleanly in a single trailing comment. Keeping extended descriptions in the main help block, keyed by name, avoids duplicating the structural information (types, defaults, validation) already present in the `arguments` block.

*Alternative considered: continuation lines (e.g., `%<`) adjacent to each argument line in the `arguments` block. Rejected because it complicates the readability of the `arguments` block and makes multi-paragraph descriptions difficult to format naturally.*

---

## Optional Enhancement Sections

Beyond auto-generated sections, authors can include the following recognized `##` section headings. The renderer applies distinct formatting to each.

### `## Syntax` (explicit full control)

When an author includes a `## Syntax` section, it becomes the **sole source** for the compact syntax block and syntax-description pairs. Auto-generation does not run. This gives the author complete control over which calling forms appear and in what order.

The grammar inside `## Syntax` uses the same calling-form paragraph pattern as the description text: each paragraph starts with a backtick-wrapped calling form, followed by a description. Forms without descriptions are also supported via fenced code blocks.

```matlab
% ## Syntax
%
% `m = weightedmean(x)` computes the arithmetic mean of the elements of
% `x`, using uniform weights.
%
% `m = weightedmean(x, w)` uses the weights in `w`.  `w` must be the
% same size as `x`.
%
% `m = weightedmean(x, w, dim)` operates along dimension `dim`.
%
% `m = weightedmean(x, Method="harmonic")` computes the harmonic mean,
% which is appropriate when averaging rates or ratios.
%
% `___ = weightedmean(___, Name=Value)` specifies options using one or
% more name-value arguments.
%
% `[m, ci] = weightedmean(___)` also returns a confidence interval
% based on the weighted standard deviation.
```

The renderer extracts calling forms for the compact syntax block and renders the descriptions as syntax-description pairs, matching the MathWorks Description section layout.

When `## Syntax` is present, the freeform description text (before any `##` heading) renders as introductory prose only — calling-form paragraphs in it are not extracted.

**When to use `## Syntax` vs. description calling forms:** Both produce the same rendered output. `## Syntax` is useful when the author wants a clean separation between syntax documentation and introductory prose, or when migrating from a legacy help block that mixes calling forms with argument descriptions in the freeform text. Description calling forms are the more natural choice when writing new help text from scratch, since they follow the traditional MATLAB help convention.

**Rationale:** Most authors will use calling-form paragraphs in the description text (Priority 2), since it matches how MATLAB help has always been written. `## Syntax` exists as an explicit-control option for authors who prefer structured sections, or when the description text serves a different purpose (e.g., conceptual overview rather than per-syntax explanations).

*Alternative considered: additive model (writing `## Syntax` supplements auto-generated forms). Rejected because it created confusion — the author couldn't see or control the full set of forms, and couldn't attach descriptions to auto-generated entries.*

### `## Input Arguments` / `## Output Arguments`
Long-form argument descriptions (see above).

### `## Examples`
Code examples. Use fenced code blocks for MATLAB code:

````markdown
## Examples

### Interpolate a sine wave

```matlab
x = linspace(0, 2*pi, 10);
y = sin(x);
xi = linspace(0, 2*pi, 100);
yi = myFunc(x, y, xi);
plot(xi, yi)
```
````

The renderer adds syntax highlighting and a Copy button. Multiple `###` subsections become separately titled examples, matching MATLAB's doc page layout.

### `## Tips`
Guidance, best practices, and performance notes. Renders as a styled prose or bulleted section.

### `## Version History`
```markdown
## Version History

**Introduced in R2024b**

**R2025a** — Added `"spline"` option for `Method`.
```

### `## Algorithms`
Implementation notes for technically inclined users.

### `## References`
Citations and links to external sources.

### `## More About`
Links to conceptual documentation or related topics. Cross-links to other pages in the generated docbook.

### Callout Blocks
Admonition-style callouts for notes, warnings, and important notices:

```markdown
% > [!NOTE]
% > This function requires the Signal Processing Toolbox.

% > [!WARNING]
% > x must be strictly monotonically increasing.

% > [!IMPORTANT]
% > Results are undefined for empty inputs.
```

These render as styled callout boxes in the HTML output. In `help` output, they appear as plain indented text.

*The specific admonition syntax is provisional; GitHub Flavored Markdown-style `> [!NOTE]` is the current candidate.*

---

## Class Documentation

### Class-Level Help Comment
Follows the `classdef` line. Documents the class as a whole. Same grammar as function help.

### Property Documentation
Identical in structure to input argument documentation:

```matlab
properties
    SampleRate   (1,1) double = 44100    % Sample rate in Hz
    WindowLength (1,1) double = 1024     % Analysis window length in samples
end
```

Extended property descriptions live in a `## Properties` section in the class help block, keyed by property name. The pattern is intentionally identical to input argument documentation — properties and input arguments are the same concept in this framework.

### Method Documentation
Each method carries its own function-level help comment following the same grammar as standalone functions. The class doc page aggregates all public method documentation and generates a Methods section with links to per-method detail sections or pages.

### Constructor
The constructor's help comment documents the construction call form. If a class-level help block also exists, both are incorporated into the class page.

---

## WYSIWYG Editing Model

### File Format
All files remain standard `.m` files. Help comments are stored as plain `%`-prefixed lines with embedded Markdown (or more precisely, MFM — MATLAB Flavored Markdown, the format underlying plain-text Live Scripts).

The plain-text Live Script format uses a `%[text]` line prefix as a signal meaning "interpret this line as rich text / MFM, not as a code comment." For help comments, this signal is unnecessary — the parser already knows to treat them as documentation by their position in the file. The rich editor therefore leaves help comment lines as plain `% ` lines and does not add `%[text]` tags.

The one exception is **embedded images**: when an image binary is encoded in a file appendix (rather than referenced by path), a tag is needed on the comment line to point to that appendix location. Images referenced by path use standard Markdown `![alt](path)` syntax and require no tag.

Note: `%%` section break syntax (used in Live Scripts and scripts) does not appear within function help comment blocks and is not part of this grammar.

### Editor Modes

| Mode | Help comment appearance |
|---|---|
| **Plain source** | Raw `% **bold**` Markdown text |
| **Doc preview** | Read-only rendered HTML, inline with source |
| **WYSIWYG doc editing** | Richly formatted and editable; Live Editor toolbar available for inserting images, equations, and tables |

In WYSIWYG mode, inserted images or equations are stored as `%[text]` blocks in the file. Markdown typed manually remains as Markdown. The two syntaxes coexist in the same file without conflict.

---

## Documentation Rendering Modes

### Just-in-Time Rendering (`doc foo`)

Individual function and class pages are always rendered on demand from the source `.m` file — no prebuild step required. This extends MATLAB's existing behavior (today, `doc someclass` already renders class documentation JIT) to functions and to the richer formatting described in this spec.

JIT rendering is fast because it involves only:
- Parsing the help comment block from a single file
- Merging with `arguments` block metadata
- Rendering Markdown/MFM to HTML

Cross-links in `See also` sections resolve against the MATLAB path at render time, the same way `doc` already resolves names today.

### Dynamic Project Browsing

When a user opens a project or folder in the MATLAB doc browser, individual pages continue to render JIT. A background thread scans the folder to build navigation (index pages, sidebar tree, breadcrumbs), which becomes available progressively as scanning completes.

This requires no user-initiated build step. The cost is proportional to the number of files in the project and is incurred only on first browse (subsequent navigation can be cached for the session).

*Implementation note: the navigation cache requires an invalidation strategy. File system watchers on the project folder are the natural mechanism — any file addition, deletion, or rename should trigger a rescan. Individual page content is always rendered fresh from source (JIT), so edits to existing files don't require cache invalidation.*

### Docbook Build (`doc.build`)

A `doc.build` command (or equivalent) produces a standalone, portable HTML documentation site from a folder or project. This is the right tool when:

- Distributing documentation with a toolbox release
- Hosting documentation externally (GitHub Pages, internal server, etc.)
- Generating a site with full-text search (which requires a pre-built index)

The generated site mirrors the structure and visual style of MATLAB's official product documentation. No configuration file is required for a basic build; optional configuration can control site title, theme, and which folders to include or exclude.

---

## Summary of Grammar Elements

| Element | Syntax | Where |
|---|---|---|
| Synopsis | `% FunctionName  One-line description` | First help comment line |
| Paragraph | `% Plain text` | Help comment |
| Bold | `% **text**` | Help comment |
| Italic | `% _text_` | Help comment |
| Inline code | `` % `code` `` | Help comment |
| Code block | `% ```matlab ... ` `` ` `` ` | Help comment |
| Heading | `% ## Heading` | Help comment |
| Unordered list | `% - item` | Help comment |
| Ordered list | `% 1. item` | Help comment |
| Link | `% [text](url)` | Help comment |
| Image (by reference) | `% ![alt](path)` | Help comment |
| Image (embedded) | tag pointing to file appendix | Help comment (WYSIWYG inserted) |
| Inline math | `` % $...$ `` | Help comment |
| Display math | `% $$...$$` | Help comment |
| Callout | `% > [!NOTE] ...` | Help comment |
| Arg short desc | Trailing `% text` on argument line | `arguments` block |
| Input arg long desc | `**argName** — ...` under `## Input Arguments` | Help comment |
| Output arg desc | `**argName** — ...` under `## Output Arguments` | Help comment |
| Syntax annotation | `` % `out = f(x, Name=val)` description `` under `## Syntax` | Help comment |
| See also | `% See also a, b, c` | Help comment |
| Examples | `% ## Examples` + fenced code blocks | Help comment |
| Tips | `% ## Tips` | Help comment |
| Version history | `% ## Version History` | Help comment |
| Algorithms | `% ## Algorithms` | Help comment |
| References | `% ## References` | Help comment |
| More About | `% ## More About` | Help comment |

---

## Open Questions

1. **Callout syntax**: finalize the admonition syntax (`> [!NOTE]` vs. a custom prefix)
2. ~~**`## Syntax` override**: define the exact format for hand-authored syntax entries~~ — **Resolved**: see `## Syntax` (annotate/extend) under Optional Enhancement Sections. The section supports fenced code blocks (forms only) and inline-code paragraphs (forms with descriptions).
3. **Docbook configuration**: determine minimum configuration surface (site name? include/exclude patterns?)
4. **`help` stripping behavior**: specify exactly which Markdown constructs are stripped vs. passed through in `help` output

---

*End of specification draft.*
