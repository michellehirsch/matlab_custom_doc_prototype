# Class Documentation Support — Design

This document captures preliminary design decisions for extending the documentation framework to MATLAB classes. It is a working document — decisions here will be folded into `doc-framework-spec.md` once validated with sample files and prototyping.

**Benchmark:** The MathWorks [DelimitedTextImportOptions](https://www.mathworks.com/help/releases/R2025a/matlab/ref/matlab.io.text.delimitedtextimportoptions.html) page represents the target page structure.

---

## Class Page Structure

Modeled after MathWorks. **Sections are only included when they have content** — no auto-generated empty sections. The possible sections, in order:

1. **Title** — class name (auto from `classdef`)
2. **Synopsis** — first line of class help comment
3. **Description** — free text from class help (before any `##` heading)
4. **Creation** — pulled from constructor method's help (omitted if no constructor and no public settable properties)
5. **Properties** — grouped or flat, from `properties` blocks (omitted if no public properties)
6. **Object Functions** — grouped or flat table of public methods (omitted if no public methods beyond constructor)
7. **Events** — table with descriptions (omitted if no public events)
8. **Examples, Tips, Algorithms, etc.** — from class help `##` sections (each only if present)
9. **Version History** — from class help (only if present)
10. **See Also** — from class help (only if present)

---

## Design Decisions

### 1. Class Description = Class Help Comment

The help comment after `classdef` works exactly like a function help comment: first line is synopsis, free text is description, `##` sections provide structured content. No new conventions needed.

**No superclass display.** The `classdef Foo < handle` inheritance chain is implementation detail for the class author, not information for the end user. If handle semantics (or other superclass behavior) matter to users, the author should explain what that means in the class description text — e.g., _"DataLogger is a handle class — all methods modify the object in place without needing to reassign the output."_

**Rationale:** Superclass names like `handle`, `matlab.mixin.Copyable`, or `dynamicprops` are meaningful to class authors but opaque to most end users. Surfacing them without explanation adds noise. The author knows which inherited behaviors matter and can describe them in user-facing terms.

### 2. Creation Section ← Constructor Help

The constructor is a method whose help comment has calling-form paragraphs, description, and `## Input Arguments` — exactly like a function page. We automatically pull this into the class page's "Creation" section.

**Why not a `## Creation` section in the class help?** It would duplicate the constructor's help and create a sync problem. The constructor IS the authoritative source for creation documentation.

**Classes with no explicit constructor:** Auto-generate a minimal creation syntax: `obj = ClassName` or `obj = ClassName(Name=Value)` if the class has public settable properties. No description section. If the class has neither a constructor nor settable properties, omit the Creation section entirely.

#### Factory Functions and the Namespace Pattern

A common MATLAB pattern is a convenience function on the path (e.g., `delimitedTextImportOptions` — lowercase) that creates an instance of a namespaced class (`matlab.io.text.DelimitedTextImportOptions` — uppercase, same name). In our framework, these are separate `.m` files that each produce their own doc page:

- The **factory function** gets a normal function page (syntax, description, arguments, etc.)
- The **class** gets a class page (properties, methods, events, etc.)
- They cross-reference each other via `See also` or description prose

We don't try to merge them into one page or auto-discover factory functions. The author controls the cross-references. This is simpler and follows the single-source-of-truth principle: each `.m` file owns its own page.

**Open question:** For user-authored code, this separation is natural — the constructor IS the creation mechanism, so the class page's Creation section is self-contained. The factory-function pattern is mostly a MathWorks internal convention. We can revisit if it proves to be a pain point for users who adopt the namespace + factory pattern.

### 3. Properties ← Treated Like Arguments

The three-layer documentation model carries over directly:

| Layer | Where | When to use |
|---|---|---|
| **Inline short** | Trailing `%` on property line | Always (summary tables, tooltips) |
| **Preceding block** | Multi-line `%` before property line, inside `properties` block | Moderate detail (1–5 lines) |
| **`## Properties` section** | In class help comment | Extensive (multi-paragraph, math, images) |

Override rule: **"Section wins entirely"** — same as arguments. If a `## Properties` section exists in the class help, inline/preceding comments are ignored for ALL properties.

**Recommendation: Use inline comments as the default.** Only graduate to `## Properties` if you genuinely need multi-paragraph descriptions for properties. Most classes won't.

**Rationale for keeping "section wins entirely":** Consistency with the argument model. Two different override models would be confusing. The inline approach is compact enough that even classes with 30+ properties stay manageable.

### 4. Property Groups via `properties` Block Header Comments

```matlab
properties  % Variable Properties
    VariableNames  (1,:) string    % Names of variables to import
    VariableTypes  (1,:) string    % Data types for each variable
end

properties  % Location Properties
    DataLines      (1,2) double    % Row range for data
    VariableNamesLine (1,1) double % Header row number
end

properties (SetAccess = private)  % State
    IsReady  (1,1) logical = false  % Whether options are configured
end
```

Rules:
- A trailing comment on the `properties` keyword line becomes the **group heading**
- Multiple `properties` blocks = multiple groups
- Order in file = order in rendered doc
- No group comment = **ungrouped** (rendered without a heading, or under a generic "Properties" heading if mixed with grouped blocks)
- If there's only one `properties` block with no comment → flat list, no groups

**Tradeoff:** This requires splitting a single `properties` block into multiple blocks to get groups. This is a minor code structure change, but arguably better code organization, and entirely optional. Users who don't want groups don't split.

**Alternative considered:** `### Group Name` subheadings inside a `## Properties` section. Rejected because it requires the verbose `## Properties` approach and disconnects group structure from code.

### 5. Property Visibility from Block Attributes

The parser reads `properties(...)` attributes to determine what appears in docs:

| Attribute combination | Visible in docs? | How shown |
|---|---|---|
| `properties` (default) | Yes | Read/write |
| `properties (SetAccess = private)` | Yes | Read-only (noted) |
| `properties (SetAccess = protected)` | Yes | Read-only (noted) |
| `properties (GetAccess = private)` | No | — |
| `properties (Access = private)` | No | — |
| `properties (Access = protected)` | No | — |
| `properties (Hidden)` | No | — |
| `properties (Dependent)` | Yes | Noted as dependent |
| `properties (Constant)` | Yes | Noted as constant |
| `properties (Abstract)` | Yes | Noted as abstract |

### 6. Methods — Function Calling Syntax, `obj` Documented, Grouped

#### Calling Syntax

All method documentation uses **function calling syntax**, not dot syntax:

```
% Good: read(s, value)
% Bad:  s.read(value)
```

With function calling syntax, the object argument (`obj`, `s`, etc.) is explicit. It **must be documented** as an input argument, just like any other argument. The rendered Input Arguments entry for the object argument links back to the class reference page.

**Rationale:** Function calling syntax is the standard in MathWorks documentation. It makes the object argument visible in the signature, which is important for users who are learning the API. Dot syntax hides the object, which is convenient for experienced users but less clear for documentation.

Example method help:
```matlab
function obj = read(obj, value)
% read  Record a new sensor reading.
%
% `s = read(s, value)` stores `value` as the current reading.
%
% ## Input Arguments
%
% `s` — Input `Sensor` object.
%
% `value` — Raw sensor reading, specified as a scalar double.
    arguments
        obj                          % Input Sensor object
        value (1,1) double           % Raw sensor reading
    end
```

The renderer recognizes that the object argument's type matches the containing class and renders it as a link to the class page.

#### Object Functions Table

The class page shows an **Object Functions** table with method name and one-line synopsis:

| Function | Description |
|---|---|
| `read` | Record a new sensor reading |
| `calibrate` | Calibrate against a known reference |
| `reset` | Clear reading and calibration offset |

Each name links to the method's own page.

**Static methods** appear using qualified syntax: `ClassName.staticMethod`. This reflects how users actually call them.

#### Method Groups via `methods` Block Header Comments

Parallel to property groups — separate `methods` blocks with inline comments on the block header:

```matlab
methods  % Data Collection
    function start(obj) ...
    function stop(obj) ...
    function log(obj, value) ...
end

methods  % Data Access
    function tt = getData(obj) ...
    function export(obj, filename) ...
end
```

Rules (same pattern as property groups):
- Trailing comment on `methods` keyword line → group heading in Object Functions table
- Multiple `methods` blocks = multiple groups
- Order in file = order in doc
- No comment = ungrouped
- Single `methods` block with no comment → flat list, no groups

#### Method Visibility

- `methods` (default) → public, documented
- `methods (Access = public)` → documented
- `methods (Access = protected/private)` → not documented
- `methods (Hidden)` → not documented
- `methods (Static)` → documented, shown as `ClassName.method`
- Constructor → documented in the Creation section, **not** listed in Object Functions

To exclude a method from documentation, the author makes it `Hidden`, `protected`, or `private`. No other exclusion mechanism needed.

#### Method Pages

Each public method gets its own standalone page, structured identically to a function page. Additions:
- Title area indicates class context (e.g., subtitle "ClassName method")
- Navigation link back to class page
- The object input argument links to the class page

### 7. Events

```matlab
events
    DataLogged       % Fires after each call to log()
    BufferFull       % Fires when buffer reaches BufferSize
end
```

Rendered as a simple table on the class page **only if the class defines public events**. Inline comments provide descriptions. No multi-layer documentation model — events are typically simple enough that one line suffices. If someone needs more, they can write about events in the class description.

Events with `(Hidden)` or non-public access are excluded.

### 8. Namespace Handling

Classes in packages (e.g., `+mypackage/MyClass.m`) are documented with their full qualified name (`mypackage.MyClass`) in the title. Short name used in syntax forms if that's what the constructor help shows.

No special machinery for cross-referencing factory functions — handled by prose in the class description and `See also`.

---

## File Size Impact Analysis

Concern: will classdef files get gigantic with comments?

**Estimate for a moderate class** (8 methods, 10 properties, like DataLogger):

| Component | Lines (inline property docs) | Lines (## Properties section) |
|---|---|---|
| Class help (description, examples, tips, see also) | ~40 | ~40 |
| `## Properties` section in class help | 0 | ~50 |
| Properties blocks (with inline comments) | ~15 | ~12 |
| Constructor help | ~25 | ~25 |
| Other method helps (7 × ~15) | ~105 | ~105 |
| Code | ~150 | ~150 |
| **Total** | **~335** | **~382** |

**For a large class** (20 methods, 30 properties):

| Component | Lines (inline) | Lines (## Properties) |
|---|---|---|
| Class help | ~50 | ~50 |
| `## Properties` section | 0 | ~150 |
| Properties blocks | ~45 | ~35 |
| Constructor help | ~30 | ~30 |
| Method helps (19 × ~15) | ~285 | ~285 |
| Code | ~400 | ~400 |
| **Total** | **~810** | **~950** |

**Key insight:** The inline property documentation approach keeps files ~15% smaller and avoids a massive comment block at the top of the file. Method docs are distributed throughout (next to each method), so no single block is overwhelming.

MATLAB class files of 800–1000 lines are normal for well-factored classes. The comments add ~40% overhead, which is reasonable for comprehensive documentation.

**Mitigations for large files:**
- IDE code folding handles comment blocks within methods
- `@ClassName` folder organization puts methods in separate files (parser support deferred to later)
- Inline property docs keep the class help block bounded regardless of property count
- Progressive enhancement: authors only document what they want — bare properties with no comments still produce useful output (name, type, default)

---

## What Carries Over Unchanged from Functions

- Help comment grammar (Markdown, `##` sections, `See also`)
- Argument documentation (three-layer model) — applies to constructor and methods
- Syntax block generation (three-priority model) — applies to constructor and methods
- Section headings (`## Examples`, `## Tips`, `## Algorithms`, etc.)
- Rendering: Markdown, code blocks, callouts, math, cross-references

## What's New for Classes

| Concept | Status |
|---|---|
| Class page template | New — different structure than function page |
| Property parsing | New — `properties` blocks with attributes, group comments |
| Property rendering | New — grouped tables with type/default/description |
| Method aggregation | New — collect public methods, build Object Functions table |
| Method groups | New — from `methods` block header comments |
| Method page rendering | Modified — function page + class context + obj linking |
| Event parsing/rendering | New — simple table |
| Visibility rules | New — attribute-based filtering for properties, methods, events |
| Constructor extraction | New — pull constructor help into Creation section |
| `obj` argument linking | New — object argument links back to class page |
| Conditional sections | New — only render sections that have content |

## Deferred / Out of Scope

- **`@ClassName` folder organization** — methods in separate files. Important but adds parser complexity. Handle after single-file classes work.
- **Enumeration classes** — `enumeration` block support. Niche, defer.
- **Abstract classes** — noting abstract methods/properties. Minor addition, do after basics.
- **Sealed classes** — no doc impact beyond a note.
