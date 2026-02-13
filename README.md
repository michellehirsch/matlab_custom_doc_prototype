# MATLAB Custom Documentation Framework

A design exploration for rendering rich HTML documentation from standard MATLAB `.m` file help comments — like mkdocs/mkdocstrings, but for MATLAB.

**[Getting Started](GettingStarted.md)** — A walkthrough of the progressive enhancement model, from zero-effort auto-generation to fully structured doc pages.

## The idea

Any `.m` file with standard `%` help comments already works. Authors can progressively add Markdown formatting (bold, code blocks, LaTeX math, images) to get richer output. Running `mdoc functionName` renders a styled HTML doc page that looks like official MathWorks documentation. Running `mdocbuild folderName` generates a simple doc book for all MATLAB functions and classes in a specified folder and subfolders. 

## What's here

- **[doc-framework-spec.md](doc-framework-spec.md)** — Functional specification for the comment grammar, rendering, and architecture
- **[class-support-design.md](class-support-design.md)** - First pass at functional spec for classes.
- **[prototype/](prototype/)** — Working MATLAB prototype (`mdoc`, `mbuilddoc`)
- **Sample files** — Example functions at progressive markup levels:
  - [addgradient/](SampleFiles/addgradient/), [rescale/](SampleFiles/rescale/), [smoothts/](SampleFiles/smoothts/) — functions
  - [Sensor/](SampleFiles/Sensor/), [DataLogger/](SampleFiles/DataLogger/) — classes
- **Sample  Documentation** - Documentation generated from all of the sample files
  - [Sample Documentation](https://michellehirsch.github.io/matlab_custom_doc_prototype/)

## Quick start

```matlab
addpath prototype
mdoc addgradient_v3_full   % renders rich HTML doc page
```


