# Final report — winder/unwinder tension control

Built on the mid-semester report template (`../midsem_2026-10/main.tex`):
IEEEtran, 12 pt, A4, one column, 1.5 spacing, real Times New Roman via XeLaTeX,
TikZ block diagrams and `booktabs` tables. The compiled report contains the
academic cover and submission details.

## Files

| File | Purpose |
|---|---|
| `main.tex` | report source (14 pages compiled) |
| `refs.bib` | DTC / PMSM references (from the mid-sem report) |
| `refs_winder.bib` | winder / web-tension references |
| `figures/` | all figures used in the report |
| `fonts/` | Times New Roman + TeX Gyre Termes Math (needed by XeLaTeX) |

## Build

`latexmk` needs Perl on this machine, so compile directly:

```
xelatex -interaction=nonstopmode main.tex
bibtex main
xelatex -interaction=nonstopmode main.tex
xelatex -interaction=nonstopmode main.tex
```

The math font is loaded by file name (`fonts/texgyretermes-math.otf`) because
the system font database name is not always visible to XeTeX.

## Length switch

At the top of `main.tex`:

```
\newif\ifextras \extrasfalse   % unwinding figures omitted (15 pages)
```

Set `\extrastrue` to add the two unwinding figures (about two extra pages).

## Before submission

- Change the cover line `Final Research Project Report` if the course uses a
  different name, and set the date.
- Verify the two winder references in `refs_winder.bib` (Koc 2002, Pagilla 2007)
  against the library record; they were added without DOIs.
- The parameter table is illustrative, not identified from a machine; this is
  stated in the text.
