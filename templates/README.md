# Templates

The [experiment README template](experiment_README_template.md) is the checklist every
experiment folder starts from. It keeps reports short and comparable.

## What each section is for

| Section | What to write |
|---|---|
| **Goal** | The question the experiment answers, in one or two sentences. |
| **What changed vs the previous experiment** | The new model hook, test condition, or metric. |
| **Models and conditions** | Model files, key parameters, and the test matrix. |
| **How to reproduce** | The exact commands, in order. |
| **Results** | The key numbers and units; point to files in `figures/`. |
| **Conclusions / next steps** | The verdict and what should happen next. |

## How to use it

1. Create the experiment folder with `tools/new_experiment.m`, which already writes a
   starter README, **or** copy the template into the folder as `README.md`.
2. Fill in **Goal** before running the experiment.
3. Add the numbers and conclusions after the runs finish.
4. Replace every placeholder and keep units on every number.

```text
experiments/exp06_my_study/
└── README.md   ← filled-in copy of the template
```

The template is deliberately short: one page that a reader can scan before opening any
model or script.
