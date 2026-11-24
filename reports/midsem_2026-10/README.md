# Mid-semester report: how to use this folder

## Build
1. Compile `main.tex` with **XeLaTeX** (the included `latexmkrc` also sets this), or run `latexmk main.tex`.
2. Run BibTeX, then XeLaTeX twice more if page numbers or references look off.
3. The report uses free TeX Gyre Termes. If XeLaTeX fails, switch to pdfLaTeX: the same file then uses a Times-compatible fallback.

## Switches in `main.tex` (near the top, after `\setstretch{1.5}`)
- `\extrastrue` / `\extrasfalse`: include / drop three optional figures (current spectrum, estimated-vs-true flux, Simulink model of the conventional DTC).
- `\toctrue` / `\tocfalse`: contents page (off by default).
The compiled `main.pdf` in this folder is the reference copy.

## References
Every reference has its DOI as a clickable link (blue text in the reference list; click it in the PDF). DOIs resolve to IEEE Xplore (checked). Kadjoudj et al. links to KoreaScience.

## Regenerating figures
- `scripts/make_report_figures.m` rebuilds the seven result figures from `../../experiments/`.
- `scripts/capture_model_screenshots.m` rebuilds the two Simulink screenshots from tidied temporary copies of the final models (the experiment models are not changed).
