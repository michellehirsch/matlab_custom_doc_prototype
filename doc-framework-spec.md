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

## Design Philosophy: Single Source of Truth

The framework's overarching principle is **single source of truth**: every piece of rendered documentation should trace back to exactly one authoritative location, and that location should be as close to the corresponding code as possible.

This principle drives a deliberate split between what the framework generates automatically from code and what the author must provide manually. The rules of thumb are:

1. **If the code is sufficient documentation, use it.** Argument names, types, sizes, defaults, and validators are already declared in `arguments` blocks — the framework extracts them directly. There is no reason for the author to repeat this information in prose.

2. **If the author must add information, keep it close to the code.** Argument descriptions go as inline or preceding comments right next to the argument declaration in the `arguments` block. Property descriptions go next to the property declaration. This proximity makes the documentation easy to find, easy to keep in sync, and hard to forget.

3. **If there is no natural code location for the information, it goes in the help comment block.** Some documentation — the synopsis, examples, tips, algorithms — has no corresponding code construct. These live in the help comment block, organized by recognized `##` section headings.

### What's Automatic vs. What's Manual

| Page element | Automatic from code | Author provides | Where the author writes it |
|---|---|---|---|
| **Title** | Function/class name | — | — |
| **Synopsis** | — | One-line description | First line of help comment |
| **Syntax block** | Generated from `metafunction` / `arguments` block (calling forms only, no descriptions) | Calling forms + descriptions | Calling-form paragraphs in description text, or `## Syntax` section |
| **Description** | — | Free-form prose, optionally with calling-form paragraphs | Help comment body (before any `##` heading) |
| **Input arguments: name, type, size, default** | Extracted from `arguments` block | — | — |
| **Input arguments: descriptions** | — | Short and/or long descriptions | Inline/preceding comments in `arguments` block, or `## Input Arguments` section |
| **Output arguments: name, type, size** | Extracted from `arguments (Output)` block if present | — | — |
| **Output arguments: descriptions** | — | Short and/or long descriptions | Comments in `arguments (Output)` block, or `## Output Arguments` section |
| **Name-value arguments** | Name, type, size, default from `arguments` block | Descriptions | Same as input arguments |
| **Properties** | Name, type, size, default from `properties` block | Descriptions | Inline/preceding comments in `properties` block, or `## Properties` section |
| **See also** | — | Related function names | `See also` line in help comment |
| **Examples** | — | Code examples with narrative | `## Examples` section |
| **Tips, Algorithms, References, etc.** | — | Prose content | Corresponding `##` sections |
| **Version History** | — | Release history entries | `## Version History` section |
| **Methods (class page)** | Method list auto-aggregated from class | Per-method documentation | Each method's own help comment |

This table illustrates the progressive enhancement model: a bare function with an `arguments` block already produces a page with a title, a syntax block, and a fully structured argument table (names, types, defaults). Every row in the "Author provides" column is optional — the author adds only what they want, where they want it.

---

## Help Comment Grammar

### What Constitutes a Help Comment

A **help comment block** is a contiguous block of comment lines immediately following a function or class declaration. This is consistent with existing MATLAB behavior for `help` and `doc`. Two comment forms are supported:

**Line-comment form** — each line begins with `%`:

```matlab
function out = myFunc(x, opts)
% myFunc  Brief one-line description of myFunc.
%
% This paragraph begins the description. It may span multiple lines.
% Markdown formatting is supported throughout.
```

**Block-comment form** — the block is delimited by `%{` and `%}`, with bare text inside:

```matlab
function out = myFunc(x, opts)
%{
myFunc  Brief one-line description of myFunc.

This paragraph begins the description. It may span multiple lines.
Markdown formatting is supported throughout.
%}
```

Both forms produce identical rendered output from the framework. The content grammar (synopsis, sections, Markdown, `See also`, etc.) is the same — only the comment delimiters differ. A help block uses one form or the other; they cannot be mixed within a single help block.

Block-comment form is especially convenient for Markdown-heavy documentation, since the body reads like a plain `.md` file with no `%` noise on every line.

**`help` command compatibility.** MATLAB's built-in `help` command does not currently extract `%{...%}` blocks as help text — it only recognizes contiguous `%`-prefixed lines. Authors who use block-comment form should be aware that `help functionName` at the command line will not display their documentation. The `doc` command (which uses this framework's renderer) handles both forms. A MATLAB enhancement request has been filed to extend `help` to recognize block comments.

For classes, the help comment block follows the `classdef` line. Help comments end at the first non-comment line (typically the `arguments` block or function body).

### Markdown Support

Help comments support a Markdown subset for formatting. Before Markdown parsing, the raw documentation text is extracted from the comment:

- **Line-comment form**: the leading `% ` (percent-space) or `%` (percent alone, for blank lines) is stripped from each line.
- **Block-comment form**: the `%{` and `%}` delimiter lines are discarded. The enclosed lines are then **dedented** to the column position of the opening `%{`.

**Dedent rule for block comments.** When `%{` is indented (e.g., inside an `arguments` or `methods` block), authors naturally indent the body text to match the surrounding code. This layout indentation is not meaningful Markdown indentation — the parser strips leading whitespace up to the column position of `%{`. Any indentation *beyond* that column is preserved and treated as meaningful Markdown (code blocks, list continuations, etc.).

| Context | `%{` column | Whitespace stripped from body lines |
|---|---|---|
| Help block (top-level) | 1 | None — body lines used as-is |
| `arguments` block | 5 (4 leading spaces) | Up to 4 spaces |
| `methods` block | 9 (8 leading spaces) | Up to 8 spaces |

> **Rationale:** Without the dedent rule, all content inside an indented `%{...%}` would render as preformatted code (2+ spaces = code block). The dedent rule makes block comments "just work" at any nesting level. This mirrors Python's `textwrap.dedent()` — layout indentation is invisible; only deliberate Markdown indentation matters.
>
> *Alternative considered: require authors to left-align block-comment bodies regardless of surrounding code indentation. Rejected because it looks unnatural in indented contexts (`arguments`, `methods`) and fights the editor's natural indentation.*

In both forms, the extracted text is then parsed identically as MFM (MATLAB Flavored Markdown).

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

**Paragraph and line-break handling:** Standard Markdown whitespace rules apply after text extraction. In line-comment form, a blank comment line (`%` alone or `% ` with only whitespace) becomes a blank line that separates paragraphs. In block-comment form, an empty line between `%{` and `%}` serves the same role. Consecutive non-blank lines within the same paragraph are joined with a space (soft wraps). This means existing plain-text help comments — which already use blank `%` lines between paragraphs — render with correct paragraph breaks and no markup required. Authors do not need to add any formatting to get proper paragraph separation; the blank lines they already write are sufficient.

**Indented code blocks:** Lines indented by two or more spaces (after text extraction, including dedenting for block comments) are rendered as preformatted code blocks, matching the traditional MATLAB help convention where examples are written with indentation. Consecutive indented lines are grouped into a single code block. This means existing help text like:

```matlab
% Example
%   x = [1 2 3 4 5];
%   y = rescale(x)
```

renders "Example" as a paragraph and the indented lines as a syntax-highlighted code block — with no fenced code block markup required. Authors who prefer explicit control can use fenced code blocks (` ``` `) instead; fenced blocks take priority and are not affected by indentation.

Markdown syntax is stripped (not rendered) by the `help` command, which displays plain text as today. In a future richer command window, basic Markdown rendering (bold, code) may be supported where the terminal allows it.

### The First Line (Synopsis)

The first line of a help comment has special significance:

```matlab
% myFunc  Brief one-line description.
```

In block-comment form, the first line after `%{` (after dedenting) follows the same convention:

```matlab
%{
myFunc  Brief one-line description.
...
%}
```

- The leading token matching the function/class name (case-insensitive) is recognized and stripped from the rendered body
- The remainder becomes the **synopsis** — the one-line description displayed in index pages and at the top of the rendered doc page
- This matches the existing MATLAB `help` convention and requires no change to existing files

### Block-Comment Considerations

**Recognition.** A `%{` block is recognized as the help comment when it is the first comment construct immediately after the function or class declaration — the same position rule as line comments. A `%{` block elsewhere in the file is an ordinary code comment.

**No nesting.** MATLAB does not support nested `%{...%}` blocks. A `%{` appearing inside a block comment is treated as literal text, not as a nested delimiter. The framework inherits this behavior.

**Literal `%` inside block comments.** A `%` character on a line inside `%{...%}` is literal content, not a comment delimiter. This is natural for documentation: a code example like `y = foo(x)  % returns 42` inside a block comment renders the trailing `% returns 42` as text — which is exactly what the author intends in a displayed code example.

**Closing delimiter.** The `%}` that closes a block comment must appear on its own line (with optional leading whitespace). This is a MATLAB language requirement.

**Mutual exclusivity.** A help block is either entirely line-comment or entirely block-comment. This is inherited from MATLAB's own parsing — there is no mixing of forms within a single help block.

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

#### The Syntax Description Gap

The syntax block is the one major page element where the single-source-of-truth principle encounters a structural limitation. For arguments, the framework's strategy works cleanly: the code declares arguments in the `arguments` block, and the author puts descriptions right next to each declaration — the code construct and its documentation live side by side. For syntax, there is no analogous code construct. A function's calling forms are *emergent* — they arise from the combination of required arguments, optional arguments, name-value arguments, and output arguments — but they are not declared anywhere in the source file. There is no place next to the code where the author can annotate "this calling form does X."

This creates an all-or-nothing gap between zero effort and full manual authoring:

| Approach | Syntax block | Syntax descriptions | Author effort |
|---|---|---|---|
| **Do nothing** (Priority 3) | Auto-generated from `metafunction` — correct, complete | None — syntax block only, no per-syntax descriptions | Zero |
| **Calling-form paragraphs** (Priority 2) | Extracted from author's backtick-wrapped forms | Author writes a paragraph per form | Must write every form + description manually |
| **`## Syntax` section** (Priority 1) | From the section | Author writes a paragraph per form | Must write every form + description manually |

There is no middle ground where the author gets the auto-generated forms *and* attaches descriptions to them. The moment the author writes any calling-form paragraph or `## Syntax` entry, auto-generation turns off entirely and the author owns the full set. This is by design — partial override of an auto-generated list would be confusing and fragile — but it means the step from "free syntax block" to "syntax block with descriptions" is a significant jump in authoring effort.

**Why this gap exists and why it's acceptable:**

- The syntax block alone (no descriptions) is already useful. Many internal and community functions ship with just a list of calling forms and no per-form descriptions; the reader infers meaning from argument names and the argument detail section below.
- The gap only affects *descriptions of calling forms*. The auto-generated syntax block itself is free and accurate. The argument detail section (names, types, defaults, descriptions) is also independent and can be fully documented close to the code. So even at zero effort, the page is structured and informative.
- Syntaxes are inherently a *summary-level concern* — they describe the function's external API, not any single code construct. Documenting them in the help comment block (rather than next to code) is appropriate because they are about the function as a whole.

**Rationale for all-or-nothing behavior:** An additive or merge model — where the author writes descriptions for *some* forms and the renderer auto-generates the rest — was considered and rejected. It would require a matching algorithm (which auto-generated form does this description attach to?), would silently break when the `arguments` block changes, and would make it unclear to the author what the reader sees. The current model is simple: if you write syntax entries, you own all of them; if you don't, the renderer handles it.

#### Potential Editor Workflows for Bridging the Gap

The gap between auto-generated syntaxes (no descriptions) and fully manual syntaxes (with descriptions) could be eased by editor tooling that helps the author graduate from Priority 3 to Priority 2 or Priority 1 without starting from a blank page. Several approaches could help:

**1. "Populate Syntax" code action / quick fix.** The editor detects that a function has an `arguments` block but no calling-form paragraphs or `## Syntax` section. It offers a code action (lightbulb menu or right-click) that inserts a scaffolded set of calling-form paragraphs into the help comment, pre-filled with the same forms that auto-generation would produce. The author then edits these paragraphs to add descriptions. For `weightedmean`, this would insert:

```matlab
% weightedmean  Compute the weighted mean of an array.
%
% `m = weightedmean(x)`
%
% `m = weightedmean(x, w)`
%
% `m = weightedmean(x, w, dim)`
%
% `___ = weightedmean(___, Name=Value)`
%
% `[m, ci] = weightedmean(___)`
```

Each calling-form paragraph is ready for the author to append a description after the backtick-wrapped form. This eliminates the tedious work of figuring out and typing each calling form — the author's only task is writing descriptions.

**2. "Populate Syntax Section" variant.** Same idea, but inserts a `## Syntax` section instead of calling-form paragraphs in the description body. Useful for authors who prefer the `## Syntax` organizational style.

**3. Staleness detection / sync warnings.** When the author has calling-form paragraphs or a `## Syntax` section, the editor compares the documented forms against what `metafunction` would generate. If the `arguments` block has changed (e.g., a new optional argument was added), the editor warns that the documented syntaxes may be out of date. This could surface as:
- A diagnostic/warning squiggle on the `## Syntax` heading or on calling-form paragraphs that don't match current metadata
- A quick fix to insert a new calling-form paragraph for the unmatched argument

**4. Live preview pane.** A side panel shows the rendered doc page as the author edits. This helps the author see what the reader will see — particularly useful for verifying that calling-form paragraphs are being detected correctly and that the syntax block looks right.

These are editor features, not grammar changes — they don't affect the spec's syntax rules or priority model. They simply reduce the friction of moving from zero-effort auto-generated syntaxes to fully documented syntaxes.

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

There are three ways to document arguments, in order of increasing detail. Authors choose based on the complexity of their arguments. These same rules apply symmetrically to `arguments (Output)` blocks.

### Inline Short Description

A trailing `%` comment on an argument line in the `arguments` block provides the **short description**. It appears in argument summary tables in the rendered output. If no long-form description exists, it also serves as the long-form description.

```matlab
arguments
    x              (1,:) double              % Input signal, real or complex-valued
    opts.Method    string = "linear"         % Interpolation method
    opts.Verbose   (1,1) logical = false     % Enable verbose output
end
```

The inline comment should be a single concise phrase or sentence.

### Long-Form Descriptions in the `arguments` Block

For arguments requiring more explanation, a comment block **immediately preceding** the argument declaration provides the long-form description. The trailing `%` comment still provides the short description.

Both line-comment and block-comment forms are supported for preceding descriptions:

**Line-comment form:**

```matlab
arguments
    % Input signal, specified as a real or complex-valued row vector.
    % The function does not validate monotonicity.
    x              (1,:) double              % Input signal

    % Interpolation method. Specify as one of:
    %
    %   - `"linear"` *(default)* — piecewise linear interpolation
    %   - `"cubic"` — cubic Hermite interpolation
    %   - `"spline"` — not-a-knot spline interpolation
    opts.Method    string = "linear"         % Interpolation method

    % When `true`, prints progress messages to the command window
    % during computation.
    opts.Verbose   (1,1) logical = false     % Enable verbose output
end
```

**Block-comment form:**

```matlab
arguments
    %{
    Input signal, specified as a real or complex-valued row vector.
    The function does not validate monotonicity.
    %}
    x              (1,:) double              % Input signal

    %{
    Interpolation method. Specify as one of:

      - `"linear"` *(default)* — piecewise linear interpolation
      - `"cubic"` — cubic Hermite interpolation
      - `"spline"` — not-a-knot spline interpolation
    %}
    opts.Method    string = "linear"         % Interpolation method

    %{
    When `true`, prints progress messages to the command window
    during computation.
    %}
    opts.Verbose   (1,1) logical = false     % Enable verbose output
end
```

The dedent rule applies: body text is dedented to the column of the `%{` opener, so the indentation above is layout, not Markdown formatting. Trailing `%` short descriptions on argument lines remain line-comment style (they are part of the code line, not a block).

The long description should **repeat/incorporate the short description** so it reads naturally as a standalone paragraph. The renderer does not merge them — each is used independently (short in summary tables, long in detail sections).

This approach works best when descriptions are short to moderate (1–5 lines per argument). For arguments with extensive documentation (bulleted option lists, multi-paragraph explanations, math), the help-block approach below may be cleaner, since it avoids interleaving prose with type/size/validator declarations.

### Long-Form Descriptions in `## Input Arguments` / `## Output Arguments`

For input arguments requiring more explanation, a `## Input Arguments` section in the help comment block provides extended descriptions, keyed by argument name wrapped in backticks (matched case-sensitively). Output arguments are documented in a `## Output Arguments` section using the same pattern. In the rendered output, argument names are displayed in **bold monospace** — the renderer adds bold styling even though the source uses only backticks.

Each entry has a **structural short/long split**: the text on the same line as `` `argName` — `` is the short description; additional lines below it form the long description (which should repeat/incorporate the short description so it reads naturally on its own).

```matlab
% myFunc  Interpolate signal x using the specified method.
%
% Extended description of the function...
%
% ## Input Arguments
%
% `x` — Input signal.
% Input signal, specified as a real or complex-valued row vector. The
% function does not validate monotonicity.
%
% `opts.Method` — Interpolation method.
% Interpolation method. Specify as one of:
%
%   - `"linear"` *(default)* — piecewise linear interpolation
%   - `"cubic"` — cubic Hermite interpolation
%   - `"spline"` — not-a-knot spline interpolation
%
% `opts.Verbose` — Enable verbose output.
%
% ## Output Arguments
%
% `out` — Interpolated values.
% Interpolated values, returned as a row vector the same length as
% `xi`.
%
function out = myFunc(x, opts)
    arguments
        x              (1,:) double              % Input signal
        opts.Method    string = "linear"         % Interpolation method
        opts.Verbose   (1,1) logical = false     % Enable verbose output
    end
```

For simple arguments where the short description says everything needed, the long description can be omitted — the entry is just the one line:

```
% `opts.Verbose` — Enable verbose output.
```

### Override Rules

The renderer resolves argument documentation using the **first available** source from this priority list:

| Priority | Source | Short description | Long description |
|----------|--------|-------------------|-----------------|
| 1 (highest) | `## Input Arguments` section | Text after `` `arg` — `` on same line | Remaining lines below |
| 2 | Preceding comment block + trailing `%` in `arguments` block | Trailing comment | Preceding block |
| 3 | Trailing `%` only in `arguments` block | Trailing comment | Trailing comment (serves both) |
| 4 | `arguments` block, no comments | — | — (type/size/default still auto-rendered) |
| 5 (lowest) | Function declaration only | — | — (just argument name) |

**Section wins entirely.** If a `## Input Arguments` section exists in the help block, it is the sole source for **all** input argument documentation. Preceding comments and trailing comments in the `arguments` block are treated as ordinary code comments (not rendered as documentation). The same rule applies independently for `## Output Arguments` vs. `arguments (Output)` block documentation.

This means you can freely mix approaches across input vs. output (e.g., arguments-block docs for inputs, `## Output Arguments` in help for outputs). But you cannot mix per-argument within the same category — all input args come from one source, all output args come from one source.

**Rationale:** Per-argument merging across two locations would be confusing to authors and hard for tooling to surface clearly. The "section wins entirely" rule is simple to explain and implement.

*Alternative previously considered: continuation lines (e.g., `%<`) adjacent to each argument line in the `arguments` block. This was rejected in favor of standard `%` comment blocks preceding the argument line, which use familiar comment syntax and support multi-paragraph descriptions naturally.*

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
Identical in structure to input argument documentation. Trailing `%` comments, preceding line-comment blocks, and preceding `%{...%}` block comments all work the same way as for arguments:

```matlab
properties
    SampleRate   (1,1) double = 44100    % Sample rate in Hz
    WindowLength (1,1) double = 1024     % Analysis window length in samples
end
```

Extended property descriptions live in a `## Properties` section in the class help block, keyed by property name, or as preceding comment blocks in the `properties` block. The pattern is intentionally identical to input argument documentation — properties and input arguments are the same concept in this framework.

### Method Documentation
Each method carries its own function-level help comment following the same grammar as standalone functions. The class doc page aggregates all public method documentation and generates a Methods section with links to per-method detail sections or pages.

### Constructor
The constructor's help comment documents the construction call form. If a class-level help block also exists, both are incorporated into the class page.

---

## WYSIWYG Editing Model

### File Format
All files remain standard `.m` files. Help comments are stored as either `%`-prefixed line comments or `%{...%}` block comments, with embedded Markdown (or more precisely, MFM — MATLAB Flavored Markdown, the format underlying plain-text Live Scripts). The WYSIWYG editor **preserves the author's chosen comment form** — if the author wrote `%{...%}`, the editor round-trips it as `%{...%}`.

> **Rationale:** Normalizing block comments to line comments on save would silently reformat files. Authors who chose block-comment form did so intentionally. The editor respects that choice.

The plain-text Live Script format uses a `%[text]` line prefix as a signal meaning "interpret this line as rich text / MFM, not as a code comment." For help comments, this signal is unnecessary — the parser already knows to treat them as documentation by their position in the file. The rich editor therefore leaves help comment lines in their original form and does not add `%[text]` tags.

The one exception is **embedded images**: when an image binary is encoded in a file appendix (rather than referenced by path), a tag is needed on the comment line to point to that appendix location. Images referenced by path use standard Markdown `![alt](path)` syntax and require no tag. In block-comment form, the image tag appears as a bare line inside the `%{...%}` block.

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

| Element | Syntax (line-comment form) | Where |
|---|---|---|
| Synopsis | `% FunctionName  One-line description` | First help comment line |
| Paragraph | `% Plain text` | Help block |
| Bold | `% **text**` | Help block |
| Italic | `% _text_` | Help block |
| Inline code | `` % `code` `` | Help block |
| Code block | `% ```matlab ... ` `` ` `` ` | Help block |
| Heading | `% ## Heading` | Help block |
| Unordered list | `% - item` | Help block |
| Ordered list | `% 1. item` | Help block |
| Link | `% [text](url)` | Help block |
| Image (by reference) | `% ![alt](path)` | Help block |
| Image (embedded) | tag pointing to file appendix | Help block (WYSIWYG inserted) |
| Inline math | `` % $...$ `` | Help block |
| Display math | `% $$...$$` | Help block |
| Callout | `% > [!NOTE] ...` | Help block |
| Arg short desc | Trailing `% text` on argument line | `arguments` block |
| Arg long desc (preceding) | `%` block or `%{...%}` before argument line | `arguments` block |
| Input arg long desc (section) | `` `argName` — ... `` under `## Input Arguments` | Help block |
| Output arg desc | `` `argName` — ... `` under `## Output Arguments` | Help block |
| Syntax annotation | `` % `out = f(x, Name=val)` description `` under `## Syntax` | Help block |
| See also | `% See also a, b, c` | Help block |
| Examples | `% ## Examples` + fenced code blocks | Help block |
| Tips | `% ## Tips` | Help block |
| Version history | `% ## Version History` | Help block |
| Algorithms | `% ## Algorithms` | Help block |
| References | `% ## References` | Help block |
| More About | `% ## More About` | Help block |

All elements in the "Help block" column apply equally to both line-comment (`% `) and block-comment (`%{...%}`) forms. The syntax column shows line-comment form; in block-comment form the `% ` prefix is absent.

---

## Open Questions

1. **Callout syntax**: finalize the admonition syntax (`> [!NOTE]` vs. a custom prefix)
2. ~~**`## Syntax` override**: define the exact format for hand-authored syntax entries~~ — **Resolved**: see `## Syntax` (annotate/extend) under Optional Enhancement Sections. The section supports fenced code blocks (forms only) and inline-code paragraphs (forms with descriptions).
3. **Docbook configuration**: determine minimum configuration surface (site name? include/exclude patterns?)
4. **`help` stripping behavior**: specify exactly which Markdown constructs are stripped vs. passed through in `help` output

---

*End of specification draft.*
