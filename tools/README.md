# Tools

Three small MATLAB helpers used across the experiments.

## `save_figure.m`

Saves one figure in all three formats the project needs:

| Output | Why it exists |
|---|---|
| `.png` | 300 dpi image for quick viewing and documents |
| `.pdf` | Vector version that stays sharp when zoomed |
| `.fig` | Editable MATLAB figure |

It also creates the output folder if it does not exist.

```matlab
fig = figure;
plot(1:10);
save_figure(fig, 'fig01_example', fullfile('experiments', 'exp05_winder_mechanics', 'figures'));
```

## `new_experiment.m`

Creates the next numbered experiment folder with the standard `models/`, `scripts/`,
`results/`, and `figures/` subfolders, plus a starter `README.md`. It copies the common analysis scripts and models from the previous experiment and
chooses the next free number automatically. Model-building scripts are not copied.

```matlab
addpath('tools')
new_experiment('web_tension_observer')
% -> experiments/exp06_web_tension_observer/
```

The copied files are a snapshot, not a finished experiment. Rename the models and
edit the scripts before running anything. The starter README comes from
`templates/experiment_readme_template.md`.

`projectRoot` is an optional second argument; leave it out when running from the
repository root.

## `export_model_screenshots.m`

Saves full top-level screenshots of the canonical experiment models into
`docs/screenshots/`.

```matlab
addpath('tools')
export_model_screenshots
```

The script only loads, prints, and closes the models; it does not save or modify them.
