# RUNBOOK — manual control of the simulation and report build

This is the operator's guide. It assumes you run MATLAB and the TeX tools yourself.
All relative paths below assume you start in the repository root.
There is no separate GUI application: the "app" is the Simulink models plus the
MATLAB scripts, and the public deliverable is the report PDF.

---

## 0. What is in the project

| Folder | What it is |
|---|---|
| `experiments/exp01_svm_vs_classic_dtc` | Classical DTC vs SVM-DTC: dynamic test + speed/load sweep |
| `experiments/exp02_robustness` | Stator-resistance mismatch, low speed, speed reversal |
| `experiments/exp03_rs_boundary` | Fine Rs sweep: where the shared flux estimator loses control |
| `experiments/exp05_winder_mechanics` | Winder plant + both drives + tension loop + feedforward; **main results** |
| `reports/final_2026-11` | 14-page report (XeLaTeX) |
| `tools/save_figure.m` | Saves PNG 300 dpi + vector PDF + .fig |
| `docs/` | Logs, lessons, this runbook |

The three `exp01`–`exp03` studies are the mid-semester work. `exp05` is the final
winder study and reads the motor parameters from `exp03`.

---

## 1. Prerequisites

- MATLAB with **Simulink** and **Simscape** (the models use `fl_lib` and
  `nesl_utility` blocks; the PMSM/inverter blocks come from Simscape Electrical).
- TeX: **XeLaTeX** + **BibTeX** (real Times New Roman from `fonts/`).
- Keep the project path short. Windows' 260-character limit breaks Simulink
  code generation in deep folders.
- `setup_paths` (exp01–exp03) sends Simulink's cache to `%TEMP%\dtc_sim_cache`.

Check the MATLAB side once:

```matlab
ver Simulink
ver Simscape
ver Simscape_Electrical
```

If `ver Simscape_Electrical` returns nothing, the drive models will not open.

---

## 2. Fast path — rebuild the PDFs only, no simulation

Use this when only the text, layout, or existing saved data changed.

### 2.1 Regenerate the report figures from local `.mat` results

The raw `.mat` results are not committed. If they exist locally:

```matlab
cd('reports/final_2026-11')
run('make_overlay3.m')      % report 3-panel overlay
```

The figures already included in `reports/final_2026-11/figures/` are part of the
repository. To recreate them from scratch, first run the exp05 matrix, then run
`make_overlay3.m`.

### 2.2 Build the report

```powershell
cd "reports/final_2026-11"
xelatex -interaction=nonstopmode main.tex
bibtex main
xelatex -interaction=nonstopmode main.tex
xelatex -interaction=nonstopmode main.tex
```

Output: `reports/final_2026-11/main.pdf` (14 pages).

If Perl is installed and you prefer one command:

```powershell
latexmk -pdf main.tex
```

The `latexmkrc` already selects XeLaTeX.

---

## 3. Full simulation — what to run and what it produces

### 3.1 exp05 — the main 18-case winder matrix (about 57 minutes measured)

```matlab
cd('experiments/exp05_winder_mechanics')
run('scripts\run_final_matrix.m')
```

It runs, with identical mechanics/controllers/limits:

- 8 four-way cases: SVM/classical × FF off/on × winding/unwinding;
- 4 line-speed cases: 0.8 and 1.6 m/s, both controllers, FF on;
- 4 initial-radius cases: winding r0 = 0.08 m, unwinding r0 = 0.10 m;
- 2 tension-step cases: 15 → 18 N at 1.2 s, both controllers.

Measured wall time of the saved matrix: **3397 s ≈ 57 min** (139–279 s per case).
With a cold Simulink cache, budget 1–1.5 h.

Produces:

| Output | Contents |
|---|---|
| `results/final_matrix.csv` | One row per case: RMSE, min/max, speed RMSE, mismatch, Te peak/ripple, Ia peak/rms, saturation time, balance residual, radius/inertia endpoints, wall time |
| `results/final_matrix.mat` | The same table as a MATLAB table |
| `results/val2s_<tag>.mat` | Raw time series for every case (`t,F,omg,wr,vl,r,J,TL,Te,ia,met`) |
| `figures/fig2s_<tag>.png/.pdf/.fig` | Six-panel figure for every case (tension, speed, radius, inertia, torque, mismatch) |

Case tags look like `SVM_wind_ff1`, `Classical_wind_ff0`,
`SVM_wind_v0.8_ff1`, `Classical_unwind_r100_ff1`, `SVM_wind_Fstep_ff1`.

**One case only** (about 2–4 min):

```matlab
cd('experiments/exp05_winder_mechanics')
run('..\exp03_rs_boundary\scripts\pmsm_dtc_parameters.m')
run('scripts\winder_params.m')
met = run_case_2s('svm_dtc_winder', +1, 0.06, 'my_test', 1, 1);
```

Arguments of `run_case_2s`:

```
run_case_2s(model, mode, r0, tag, ffon, fffull)
model  : 'svm_dtc_winder' or 'classic_dtc_winder'
mode   : +1 winding, -1 unwinding
r0     : initial radius [m], e.g. 0.06 or 0.115
tag    : filename tag
ffon   : 0 = feedforward off, 1 = on
fffull : 1 = full feedforward, 0 = inertia only
```

It writes `results/val2s_my_test.mat` and `figures/fig2s_my_test.*`.
It forces `Tsim = 2 s`, `T_ramp = 1 s`, `H0 = 0`, `F0 = F_ref`,
and `filt_on = 1`; change those lines in `run_case_2s.m` if you want other values.

**Plant-only validation** (no drive):

```matlab
cd('experiments/exp05_winder_mechanics')
addpath('scripts')
run('scripts\winder_params.m')
winder_mode = 1;  r0 = winder.r0_wind;
omega0 = v_init/r0; J0 = winder_Jfun(r0); H0 = J0*omega0; F0 = winder.F0;
Te0 = F0*r0;
build_winder_model
run('scripts\validate_winder.m')
```

This **deletes and rebuilds** `winder_mechanics.slx`. It writes
`results/validation_metrics.csv`, `results/validation_winding.mat`,
`results/validation_unwinding.mat`, and the winding/unwinding validation figures.
Do not run `build_winder_model` if you have manual edits in that model.

### 3.2 exp01 — classical vs SVM, dynamic test + sweep

```matlab
cd('experiments/exp01_svm_vs_classic_dtc')
setup_paths
run_all            % about 3 h; or sel = 1 (SVM) then sel = 2 (classical)
make_results
```

`run_all` runs 14 simulations (2 dynamic + 12 sweep cases). It **resumes**:
existing `results/result_*.mat` files are skipped. Delete them to force a rerun.

`make_results` prints the tables and writes 9 figures plus
`results/metrics_summary.csv`.

### 3.3 exp02 — robustness

```matlab
cd('experiments/exp02_robustness')
setup_paths
sel = 1; run_all   % SVM-DTC, about 1 h
sel = 2; run_all   % classical DTC, about 1 h (use a second MATLAB session if RAM allows)
make_results
```

20 simulations total (10 per controller). Outputs 6 figures and
`results/metrics_summary.csv`.

### 3.4 exp03 — Rs boundary

```matlab
cd('experiments/exp03_rs_boundary')
setup_paths
run_all            % about 2 h total; sel = 1 / 2 to split
make_results
```

20 simulations, 3 figures, `results/metrics_summary.csv`.

**Note:** exp05 reads `exp03_rs_boundary/scripts/pmsm_dtc_parameters.m` directly.
Changing the motor there changes the exp05 results too.

---

## 4. How to change parameters

### Winder mechanics and tension loop — `exp05/scripts/winder_params.m`

| Field | Meaning |
|---|---|
| `winder.rho, w, h, E, L` | Web material and geometry |
| `winder.rc, rmax, r0_wind, r0_unwind` | Core and roll radii |
| `winder.Jc, Jm, Bm` | Core/shaft inertia, motor inertia, viscous damping |
| `winder.F_ref, Fmax, Tmax` | Tension setpoint, web limit, torque limit |
| `winder.v_line_set, T_ramp` | Line speed and startup ramp |
| `winder.C_web` | Kelvin–Voigt web damping |
| `winder.Kp_F, Ki_F` | Tension PI gains |
| `winder.f_c, filt_on` | Feedback filter |
| `winder.ff_on, ff_full` | Default feedforward gates |
| `winder.w_min, w_max` | Speed-reference limits |

Write the file, then rerun the case or matrix. Every script reads this file.

### Motor and drive — `exp03_rs_boundary/scripts/pmsm_dtc_parameters.m`

`Rs, Ld, Lq, lambda_f, p, J, B, Vdc, Ts_dtc, Ts_pwm`, hysteresis bands, speed-loop
gains, and the default test scenario. exp01 and exp02 have their own copies of
`pmsm_dtc_parameters.m`; if you change the motor, update those copies too.

### Case-level overrides

- `run_case_2s` arguments: model, direction, radius, FF gates.
- `run_final_matrix.m`: edit the `cfgs`, `v`, `radcases`, or the step block values
  at the top of each section.
- `v_line_set` in the base workspace can be set before calling `run_case_2s`
  (the function does not overwrite it).
- To change simulation time or ramp inside a single case, edit lines 22–23 of
  `run_case_2s.m`; the matrix always uses 2 s / 1 s.

---

## 5. Reading the outputs

### `final_matrix.csv`

Important columns:

- `F_rmse` — tension RMS error over the last 0.7 s (t ≥ 1.3 s);
- `F_max`, `F_min` — full-run tension envelope;
- `speed_rmse` — speed-reference tracking error;
- `mismatch_max` — maximum |v_surf − v_line|;
- `Te_peak`, `ripple` — peak torque and torque standard deviation;
- `ia_peak`, `ia_rms` — phase-current peak and RMS;
- `sat_time` — time at the 99 % torque limit (should be 0);
- `balance_rms` — mechanical torque-balance residual.

Nominal expectations (FF on, 2 s): SVM wind RMSE ≈ 0.77 N, classical wind ≈ 0.27 N,
SVM unwind ≈ 0.05 N, classical unwind ≈ 0.10 N. If a value is far from these,
check that the correct `ffon=1, fffull=1` case was run.

### Six-panel figure

Panels: web tension, shaft speed vs reference, roll radius, total inertia,
motor torque (with ±5 N·m limits), surface-speed mismatch.
The filename tells you the case.

### Report

- `reports/final_2026-11/main.pdf` - 14 pages; figures: Fig. 1 plant, Fig. 2
  classical DTC, Fig. 3 SVM-DTC, Fig. 4 architecture, results figures, etc.

---

## 6. Figures: which script makes which file

| Figure | Producer |
|---|---|
| `fig_classic_wind.png`, `fig_svm_wind.png` (report) | generated from the saved exp05 results |
| `fig_overlay3.png` (report) | `reports/final_2026-11/make_overlay3.m` |
| `fig2s_<tag>.png/.pdf/.fig` | `run_case_2s` (during a run) |
| `fig_ff_summary.png`, `fig_svm_unwind.png`, `fig_classic_unwind.png` | copied from the corresponding exp05 six-panel/ff figures; the repo has no single regeneration script for these |
| `fig_plant_validation*.png` | `validate_winder.m` |

After regenerating, rebuild the PDF(s). LaTeX reads the PNGs at compile time, so
a figure change alone requires a `xelatex` / `pdflatex` run.

---

## 7. Manual Simulink use (GUI)

If you want to press **Run** yourself instead of using `run_case_2s`:

```matlab
cd('experiments/exp05_winder_mechanics')
run('..\exp03_rs_boundary\scripts\pmsm_dtc_parameters.m')
run('scripts\winder_params.m')
open_system('svm_dtc_winder')
```

Then set the base-workspace variables the model expects (`winder_mode_set`, `r0`,
`H0`, `F0`, `Tsim`, `T_ramp`, `ff_on`, `ff_full`, `filt_on`) and press Run.
The logging blocks (`F_log`, `w_data`, `r_log`, `J_log`, `TL_log`, `Te_log`,
`ia_data`, `wref_log`, `vline_log`) are added by `run_case_2s`; a fresh model may
not have all of them. For repeatable results, use `run_case_2s` rather than
pressing Run on a modified model.

Do **not** run these unless you intend to rewrite the `.slx` files:

- `build_drive_native.m` (rebuilds the drive model and saves it),
- `add_feedforward.m`, `add_startup_and_filter.m` (modify and save the model),
- `build_winder_model.m` (deletes and rebuilds `winder_mechanics.slx`).

Back up `models/` before any of them.

---

## 8. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Undefined function or variable 'F_ref'` | Run `pmsm_dtc_parameters.m` and `winder_params.m` first |
| `Undefined function 'save_figure'` | Add `tools/` to the MATLAB path |
| `Cannot find library 'fl_lib'` | Simscape / Simscape Electrical not installed or not licensed |
| Model not found | `cd` to exp05 and add `models/` to the path |
| Simulink cache or code-generation errors | Run `setup_paths` (exp01–exp03); keep the path short |
| `run_all` does nothing | It resumes; delete the relevant `results/result_*.mat` to force rerun |
| Matrix rerun seems to reuse old data | Each case overwrites `val2s_<tag>.mat`; check the tag and the timestamp |
| Report has `??` references | Run the full xelatex → bibtex → xelatex → xelatex sequence |
| XeLaTeX cannot find Times New Roman | Use XeLaTeX, not pdfLaTeX; the fonts are in `reports/final_2026-11/fonts` |
| MiKTeX prints “major issue: … updates” | It is a warning; check the final “Output written” line |
| Report is not 14 pages | Check the `\ifextras` switch and the figure includes |

---

## 9. Suggested operating order

1. Decide what changed (parameter, controller, or text only).
2. For a parameter/controller change: run **one** `run_case_2s` case, inspect the
   six-panel figure and the printed metrics.
3. If it looks right, run `run_final_matrix` (≈1 h).
4. Regenerate the document figures.
5. Rebuild the report.
6. Archive the old `results/` and `figures/` if you need to compare runs.

Never edit a finished experiment's models in place; copy the model into a new
experiment folder, as the project rules require.
