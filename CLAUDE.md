# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This is a design thinking workspace for a proposed MATLAB custom documentation framework — a system that lets `.m` file help comments render as rich HTML when users call `doc`, inspired by mkdocs/mkdocstrings. There is no runnable code here; the work product is specifications and annotated sample MATLAB files.

## Key Files

- **`doc-framework-spec.md`** — the primary deliverable. A living functional specification covering the comment grammar, auto-generated sections, argument documentation, WYSIWYG editing model, and rendering architecture. Edit this as design decisions are made.
- **`addgradient/`** — sample MATLAB function files used to explore and validate the comment grammar:
  - `addgradient1_basichelp.m` — traditional plain-text m-file help, no markup
  - `addgradient2_markup.m` — same function with markup syntax being explored (bold, inline code, fenced code blocks, image reference)

## Design Conventions in the Spec

The grammar being designed uses standard `% ` comment lines with embedded MFM (MATLAB Flavored Markdown — LaTeX-compatible Markdown, the format underlying plain-text Live Scripts). Key rules:

- Help comments = contiguous `%` block immediately after `function` or `classdef` declaration
- First line convention: `% functionName  One-line synopsis`
- Argument short descriptions: trailing `%` comment on `arguments` block lines
- Argument long descriptions: `## Input Arguments` / `## Output Arguments` sections in the help block, keyed by argument name in backticks (e.g., `` `argName` — description ``)
- Recognized section headings drive structured rendering: `## Syntax`, `## Input Arguments`, `## Output Arguments`, `## Examples`, `## Tips`, `## Version History`, `## Algorithms`, `## References`, `## More About`
- `See also name1, name2` (no heading needed) renders as hyperlinks
- No `%[text]` tags needed in help comments — position identifies them as documentation. Tags only appear for embedded images (binary encoded in file appendix).

## How to Work Here

When generating sample `.m` files to explore or validate grammar ideas, follow the conventions in `doc-framework-spec.md`. Use `addgradient2_markup.m` as a reference for the current state of explored syntax. New sample files should be organized in subfolders named for the function/class being illustrated.

When updating the spec, preserve the **Rationale** and **Alternative considered** notes — these record why decisions were made, not just what was decided.
