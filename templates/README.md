# Templates

The [experiment README template](experiment_readme_template.md) defines the required
sections for a new experiment.

## Sections

| Section | Contents |
|---|---|
| Goal | The question the experiment answers. |
| What changed | New model hook, test condition, or metric. |
| Models and conditions | Model files, key parameters, test matrix, sample time, simulation time. |
| Files | Folder tree and important files. |
| How to reproduce | Exact commands in order. |
| Results | Key numbers with units and figure references. |
| Limitations | Ideal models and cases not covered. |
| Conclusions / next steps | Verdict and follow-up work. |

## How to use it

1. Create the folder with `tools/new_experiment.m`, or copy the template manually.
2. Fill in the Goal before running the experiment.
3. Add the numerical results after the runs.
4. Keep units on every number.

A new experiment should have the standard skeleton:

```text
experiments/exp06_my_study/
├── models/
├── scripts/
├── results/
├── figures/
└── README.md
```
