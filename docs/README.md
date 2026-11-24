# Documentation index

`docs/` holds the operating manual, the research log, and the reference notes for this
simulation repository. Start with the runbook; use the rest when you need history,
debugging context, or model details.

## How the documents fit together

<p align="center">
  <img src="diagrams/docs_flow.svg" width="78%" alt="Documentation flow">
</p>

The runbook drives the experiments, the experiments produce results, and the results
become the report. The changelog and lessons learned are reviewed afterwards to decide
what to do next.

## Core documents

| File | What it is for |
|---|---|
| [RUNBOOK.md](RUNBOOK.md) | Step-by-step instructions: prerequisites, rebuilding the PDFs, running the simulations, and what each folder contains. |
| [CHANGELOG.md](CHANGELOG.md) | Dated research log: what was built, what broke, and what was fixed. |
| [lessons_learned.md](lessons_learned.md) | Numbered debugging lessons — the mistakes worth not repeating. |
| [FILE_MAP.md](FILE_MAP.md) | Short history note: the public repo keeps the final project, not the old development snapshots. |
| [literature_rs_robust_flux_estimation.md](literature_rs_robust_flux_estimation.md) | First-pass literature map on flux estimation that tolerates a wrong stator resistance, including candidate gaps. |

## Model screenshots

- [Model screenshots](screenshots/README.md) — full top-level views of every Simulink model in exp01–exp05.

## Model audit

The audit records what is inside the main clean winder model, so a parameter can be
checked without opening every block.

| File | What it contains |
|---|---|
| [block_audit_classic_clean.md](block_audit_classic_clean.md) | Human-readable audit: block counts, key parameters, and warnings about which model file is actually used. |
| [block_audit_classic_clean_important_params.csv](block_audit_classic_clean_important_params.csv) | Short curated list of the parameters that actually change behaviour. |
| [block_audit_classic_clean_key_values.csv](block_audit_classic_clean_key_values.csv) | Key block values shown as both the expression and the resolved number. |
| [block_audit_classic_clean_all_params.csv](block_audit_classic_clean_all_params.csv) | Every dialog parameter of the user-level blocks, including defaults. |
| [block_audit_classic_clean_all_blocks.csv](block_audit_classic_clean_all_blocks.csv) | Every block path in the audited model, including standard library internals. |
| [block_audit_classic_clean_matlab_functions.txt](block_audit_classic_clean_matlab_functions.txt) | Full source of the MATLAB Function blocks and the `dtc_estimator` chart. |

## Suggested reading order

1. [RUNBOOK.md](RUNBOOK.md) — learn how to run and rebuild the project.
2. [CHANGELOG.md](CHANGELOG.md) — see how the work developed.
3. [lessons_learned.md](lessons_learned.md) — avoid the known traps.
4. [FILE_MAP.md](FILE_MAP.md) — locate older files when a path looks unfamiliar.
