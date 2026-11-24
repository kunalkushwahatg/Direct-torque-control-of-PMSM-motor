# Experiment 01 — SVM-DTC vs classical DTC

**Same motor, same load, two ways of choosing the inverter voltage.**

## At a glance

| | |
|---|---|
| **Question** | How much smoother is SVM-DTC than classical DTC, and what does it cost in speed dynamics? |
| **Plant** | Surface-mounted PMSM: Rs 2.875 Ω, Ld = Lq 8.5 mH, λf 0.175 Wb, 4 pole pairs |
| **Controllers** | Classical DTC: hysteresis + switching table. SVM-DTC: torque/flux PI + space-vector modulation at 5 kHz |
| **Tests** | 1 dynamic test (0 → 20 rad/s, 0.5 → 2 N·m) + a 6-point speed × load sweep |
| **Runs** | 14 simulations: 7 per controller |
| **Runtime** | ≈3 h in one session (machine-dependent); ≈1.5 h per controller with two sessions |
| **Main result** | 3–12× lower torque ripple and 3–7× lower flux ripple for SVM-DTC; speed dynamics are close |
| **Software** | MATLAB R2026a (or compatible), Simulink, Simscape, Simscape Electrical |
| **Outputs** | `results/metrics_summary.csv`, 9 figures, one `.mat` per case |

## Words you need

| Term | Plain meaning |
|---|---|
| **PMSM** | Permanent-magnet synchronous motor — the motor being controlled. |
| **DTC** | Direct Torque Control — choose an inverter state directly from the torque and flux errors. |
| **SVM** | Space-Vector Modulation — build a smooth average voltage from the inverter's discrete states. |
| **Flux** | Magnetic strength in the stator. There is no flux sensor, so the controller estimates it. |
| **Wb** | Weber — the unit of magnetic flux. Nominal value here: 0.175 Wb. |
| **rad/s** | Angular speed. 2π rad/s ≈ one revolution per second. |
| **Torque ripple** | Fast wobble of torque around its average. Lower is smoother. |
| **THD** | Total harmonic distortion — how far the current waveform is from a pure sine. |

## Why it matters

- Torque ripple causes vibration, acoustic noise and extra current harmonics. Lower ripple is a real drive-quality gain.
- Classical DTC is simple and fast but rough. SVM-DTC adds computation to get a smoother voltage. The trade-off should be measured, not guessed.
- This experiment is the baseline for the robustness tests in exp02 and exp03.

## Signal flow

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#ffffff', 'primaryTextColor': '#000000', 'primaryBorderColor': '#000000', 'lineColor': '#000000', 'secondaryColor': '#ffffff', 'tertiaryColor': '#ffffff', 'fontFamily': 'Helvetica, Arial, sans-serif'}, 'flowchart': {'curve': 'linear', 'nodeSpacing': 28, 'rankSpacing': 35}, 'themeCSS': '.node rect, .node circle, .node ellipse, .node polygon, .node path { filter: none !important; stroke-width: 1px !important; } .cluster rect { filter: none !important; } .edgePath path { filter: none !important; stroke-width: 1px !important; }'}}%%
flowchart LR
    REF["Speed reference"] --> PI["Speed PI<br/>Kp = 2, Ki = 150"]
    PI --> TREF["Torque reference"]
    subgraph CLASSIC["Classical DTC"]
        C1["Hysteresis comparators<br/>+ switching table"]
    end
    subgraph SVM["SVM-DTC"]
        C2["Torque/flux PI<br/>+ space-vector modulation"]
    end
    FREF["Flux reference<br/>0.175 Wb"] --> C1
    FREF --> C2
    TREF --> C1
    TREF --> C2
    C1 --> INV["2-level inverter<br/>Vdc = 300 V"]
    C2 --> INV
    INV --> MOT["PMSM<br/>Rs 2.875 ohm<br/>Ld = Lq 8.5 mH<br/>4 pole pairs"]
    MOT --> SEN["Current and<br/>rotor-angle sensors"]
    SEN --> EST["Stator-flux estimator<br/>voltage model"]
    EST --> C1
    EST --> C2
```

**Two paths from the same torque command:**

- **Classical DTC** sends the torque and flux errors to hysteresis comparators; a switching table picks one of the inverter's active vectors. The switching frequency is not fixed.
- **SVM-DTC** sends the errors to PI regulators, builds a voltage reference, and modulates it with a 5 kHz carrier. The switching frequency is fixed.

Both controllers use the same 20 µs control period and the same speed PI.

## Whole-model screenshots

<p align="center">
  <img src="../../docs/screenshots/exp01_classic_dtc_final.png" width="49%" alt="Classical DTC whole model">
  <img src="../../docs/screenshots/exp01_svm_dtc_final.png" width="49%" alt="SVM-DTC whole model">
</p>

These are the full top-level models: PMSM, inverter, sensors, estimator, controller, speed loop, load, and logging.

## Test plan

| Test | Speed | Load | Analysis windows | What it checks |
|---|---|---|---|---|
| Dynamic | 0 → 20 rad/s (700 rad/s² ramp from 0.05 s) | 0.5 → 2 N·m at 0.5 s | 0.3–0.5 s, 0.7–1.0 s | startup, load step, settling |
| Sweep | 10 / 30 / 60 rad/s | 0.5 and 4 N·m (step at 0.3 s) | 0.5–0.9 s | steady-state ripple at six operating points |

Fixed conditions:

- DC bus 300 V; flux reference 0.175 Wb.
- Classical hysteresis: flux band 1% of reference (1.75 mWb), torque band 0.02 N·m.
- Speed PI: P = 2, I = 150, clamping anti-windup.
- SVM carrier: 5 kHz, 2 µs time resolution (`Ts_pwm`).
- The flux estimator uses the gate-pulse voltage averaged over each 20 µs control period, not the commanded voltage.

## What is measured

| Metric | How it is computed | Unit |
|---|---|---|
| **True torque ripple** | RMS and pk-pk of `Te = 1.5 p λf iq`, reconstructed from measured currents and rotor angle | N·m |
| **Flux ripple** | pk-pk and RMS of the estimated stator-flux magnitude | Wb |
| **Current THD** | FFT of phase-A current, up to 20 kHz | % |
| **Switching frequency** | Phase-A transitions / (2 × window length) | Hz |
| **Dynamics** | Speed overshoot, 1% settling time, load dip, recovery time, torque rise 10–90% | %, ms, rad/s |

The "true" torque is independent of the controller's own torque estimate. The estimated torque is also logged, but the comparison uses true torque.

## How to run

From the repository root:

```matlab
cd('experiments/exp01_svm_vs_classic_dtc')
setup_paths
run_all          % 14 simulations, about 3 h
make_results     % tables + 9 figures + results/metrics_summary.csv
```

`setup_paths` adds `models/`, `scripts/` and the shared `tools/` folder to the MATLAB path, and sends Simulink's generated cache to a temp folder.

To use two MATLAB sessions:

```matlab
sel = 1; run_all   % SVM-DTC only
sel = 2; run_all   % classical DTC only
```

`run_all` resumes: a case whose `results/result_*.mat` already exists is skipped. Delete those files to force a rerun.

## Files and outputs

```text
exp01_svm_vs_classic_dtc/
├── models/    svm_dtc_final.slx, classic_dtc_final.slx
├── scripts/   pmsm_dtc_parameters.m, dtc_metrics.m, run_case.m,
│              run_all.m, make_results.m, build_final.m
├── results/   result_<tag>.mat (14), metrics_summary.csv
└── figures/   fig01 ... fig09  (PNG + PDF + FIG)
```

| Output | What it contains |
|---|---|
| `results/result_<tag>.mat` | Raw waveforms and metrics for one case. |
| `results/metrics_summary.csv` | 16 rows (one per analysis window) with torque, flux, THD, switching frequency and speed. |
| `figures/fig01–fig03` | Dynamic test: overview, loaded torque zoom, load-step response. |
| `figures/fig04–fig05` | Phase-A current waveform and spectrum. |
| `figures/fig06–fig09` | Sweep bars: torque ripple, THD, flux ripple, switching frequency. |

`build_final.m` documents how the two final models were derived; it is not needed for reproduction.

A fresh clone may not include the large `.mat` or `.fig` files; regenerate them with `run_all` and `make_results`.

## Key results

### Torque ripple

| Operating point | Classical DTC | SVM-DTC | SVM advantage |
|---|---:|---:|---:|
| Dynamic, 0.5 N·m | 0.445 N·m | 0.055 N·m | 8× lower |
| Dynamic, 2 N·m | 0.451 N·m | 0.079 N·m | 5.7× lower |
| Sweep, 0.5 N·m | 0.446–0.461 N·m | 0.036–0.126 N·m | 3.5–13× lower |
| Sweep, 4 N·m | 0.437–0.451 N·m | 0.069–0.153 N·m | 3–6.5× lower |

All values are RMS of the true torque. At 2 N·m the peak-to-peak ripple is 2.09 N·m for classical DTC and 0.48 N·m for SVM-DTC. As a fraction of the mean torque, the loaded dynamic case is 22.5% vs 3.9%.

### Other metrics

| Metric | Classical DTC | SVM-DTC |
|---|---|---|
| Flux ripple, pk-pk | ≈0.010 Wb | 0.0014–0.0032 Wb |
| Current THD to 20 kHz, 4 N·m | 12.7–13.1% | 2.5–4.1% |
| Switching frequency | 7.08–7.63 kHz (variable) | 5 kHz (fixed) |
| Speed overshoot | 1.18% | 1.37% |
| 1% settling time | 33.2 ms | 41.8 ms |
| Load dip at 2 N·m step | 0.723 rad/s | 0.988 rad/s |
| Recovery after load step | 21.0 ms | 20.7 ms |
| Torque rise, 10–90% | 2.52 ms | 1.86 ms |

**Reading the trade-off:** SVM-DTC clearly wins on ripple and current distortion. The speed loop is the same PI for both controllers and was not retuned, so the small differences in overshoot, settling and dip are indicative rather than a controller ranking. SVM-DTC does raise torque faster (1.86 vs 2.52 ms).

THD is load-dependent: at 0.5 N·m the fundamental current is small, so both show high THD (classical ≈104%, SVM 14–25%). Compare THD at the same load, not across loads.

### Figures

![Dynamic test overview](figures/fig01_dynamic_overview.png)

*Dynamic test: torque, speed and stator flux. The load step at 0.5 s is visible in all three traces.*

![Loaded torque zoom](figures/fig02_torque_steady_zoom.png)

*True torque at 2 N·m. Classical DTC (top) swings about ±1 N·m; SVM-DTC (bottom) stays in a narrow band.*

![Torque ripple across the sweep](figures/fig06_sweep_torque_ripple.png)

*True torque ripple RMS at all six sweep points. SVM-DTC is lower everywhere, but the gap narrows at high speed and high load.*

## Limitations

- **Ideal inverter:** no dead time; diode forward drop is modelled as 0.8 V.
- **Simple flux estimator:** pure voltage-model integrator with no drift compensation. It is accurate here but will drift at very low speed or with Rs error — the subject of exp02 and exp03.
- **Current sign:** the current sensors are inverted in the Simscape setup; the estimator and metrics apply a −1 sign (`cfg.current_sign`).
- **SPMSM assumption:** torque is reconstructed with `Te = 1.5 p λf iq`, valid because Ld = Lq.
- **One operating envelope:** one motor, one DC bus, one speed-loop tuning; no hardware validation.
- **Fixed carrier:** the SVM carrier is 5 kHz. A different carrier frequency would change the ripple/THD trade-off.
- **THD caveat:** light-load THD is relative to a small fundamental, so it is not a fair "efficiency" number.

Next: [Experiment 02 — robustness to Rs error](../exp02_robustness/README.md)
