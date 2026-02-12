# `mbuilddoc` — Build Documentation Book

## Purpose

Generate a standalone, navigable HTML documentation site from a folder of MATLAB code. This is the "quick and dirty" build tool — it scans a folder, renders every documented `.m` file, and produces index pages for navigation. No configuration file required.

## Syntax

```matlab
mbuilddoc(sourceFolder)
mbuilddoc(sourceFolder, outputFolder)
```

- `sourceFolder` — Root folder to scan. All `.m` files in this folder and subfolders are included.
- `outputFolder` — Where to write the generated HTML. Defaults to `fullfile(sourceFolder, "doc")`.

## Behavior

### 1. Discovery

Recursively scan `sourceFolder` for `.m` files. Include:
- Function files (`function` declaration)
- Class files (`classdef` declaration)
- Files in `+package` folders (namespace packages)
- Files in `@ClassName` folders (class method files — associate with parent class)

Exclude:
- `Contents.m` files (handled separately — see below)
- Files inside folders named `private`, `test`, `tests`, `+internal`
- The `outputFolder` itself (if nested inside `sourceFolder`)

### 2. Page Generation

For each discovered `.m` file, call `mdoc_parse` → `mdoc_render` to produce a standalone HTML page. Write the result to the output folder, mirroring the source folder structure:

```
sourceFolder/
    foo.m                → outputFolder/foo.html
    bar.m                → outputFolder/bar.html
    utils/
        helper.m         → outputFolder/utils/helper.html
    +pkg/
        MyClass.m        → outputFolder/+pkg/MyClass.html
        myFunc.m         → outputFolder/+pkg/myFunc.html
```

Each page gets a small navigation header added (see Navigation below).

### 3. Index Pages

Generate an `index.html` at each folder level that has documented `.m` files. The index page lists:

- **Folder title** — the folder name (or package name for `+pkg` folders)
- **Subfolders** — links to child index pages
- **Functions and Classes** — table with name and synopsis, linking to each page

```
| Name         | Description                          |
|--------------|--------------------------------------|
| `foo`        | Compute the foo transform            |
| `bar`        | Bar utility for signal processing    |
| `MyClass`    | Represent a data acquisition session |
```

The table is sorted alphabetically. Classes and functions are intermixed (no separate sections needed for this basic version).

If a `Contents.m` file exists in a folder, its first comment line becomes the folder title and its body becomes a description paragraph above the table. This follows the existing MATLAB `Contents.m` convention.

### 4. Navigation

Each generated page gets a simple navigation header:

```
📂 sourceFolder > utils > helper
```

This is a breadcrumb trail where each segment links to the corresponding `index.html`. Minimal CSS, inline in each page (no external stylesheet dependency — pages remain self-contained).

The index pages also get breadcrumbs so you can navigate up.

### 5. Cross-References

`See also` links and any `[text](name)` references should resolve to other pages **within the generated site** where possible. Resolution logic:

1. Look for `name.html` in the same folder
2. Look for `name.html` anywhere in the output tree (match by function/class name)
3. If no match, render as a `matlab:doc('name')` link (falls back to MATLAB's built-in doc)

This is a best-effort pass — ambiguous names or external references gracefully degrade to `matlab:doc` links.

### 6. Output

The output folder contains:
- One `.html` file per documented `.m` file
- One `index.html` per folder level
- No external CSS/JS files — everything is inline in each page (same as `mdoc_render` today)

The entire output folder is self-contained and can be opened directly from the file system, hosted on a web server, or zipped for distribution.

## What This Version Does NOT Do

- **No configuration file** — no way to set site title, exclude patterns, or customize theme. Hardcoded defaults only.
- **No full-text search** — that requires a search index, which is a larger feature.
- **No sidebar navigation** — just breadcrumbs and index pages. A sidebar tree is a future enhancement.
- **No incremental builds** — always regenerates everything. For large codebases, incremental builds (based on file timestamps) would be a future optimization.
- **No table of contents across the site** — the root `index.html` serves as the entry point, with drill-down into subfolders.

## Implementation Notes

This is a thin orchestration layer over the existing prototype:

```
mbuilddoc(folder)
  ├── discover .m files (dir recursive)
  ├── for each .m file:
  │     ├── mdoc_parse(file) → info struct
  │     ├── mdoc_render(info) → html string
  │     ├── inject breadcrumb nav header
  │     └── write .html to output
  ├── for each folder with content:
  │     └── generate index.html (list of pages + subfolders)
  └── resolve cross-references (second pass or inline)
```

The cross-reference resolution is the only part that needs global knowledge (the full list of generated pages). Everything else is per-file.
