# exp05 - Winder/unwinder mechanical subsystem for the PMSM DTC-SVM drive

**Status:** complete. The final 18-case matrix and report are included.
Sections 14-15 record the historical SVM winding investigation; the resolution is in
sections 16-21.

> **Final results:** see §21. **Acceptance status:** see §20.

## 1. What this is

A modular, physically consistent model of a winder/unwinder roll, web and tension,
built to be used as the application plant for the existing PMSM DTC / SVM-DTC drive.
It is an extension of the existing work: no controller, estimator or modulation
block was changed.

The standalone verification model (`models/winder_mechanics.slx`) is one Level-2
MATLAB S-function (`scripts/winder_plant_sfun.m`) wrapped in a subsystem, so the
diagram is readable and the equations live in one file. That S-function implements
a pure-spring web. The final drive models (`models/svm_dtc_winder.slx`,
`models/classic_dtc_winder.slx`) use a native Kelvin–Voigt plant with
`C_web = 500 N·s/m`; see §16.

## 2. Physical model and sign conventions

`mode = +1` winding, `mode = -1` unwinding. `omega` is always positive in the
direction of web travel for the selected mode.

```
r(t)      roll radius
m(r)      = rho*w*pi*(r^2 - rc^2)                 roll mass
J_roll(r) = Jc + 0.5*m*(r^2 + rc^2)                roll inertia
J(r)      = Jm + J_roll(r)                         total inertia (motor + roll)
T_web     = mode*F*r                               torque of the web on the roll
v_surf    = omega*r                                roll surface speed

dr/dt     = mode*h*v_line/(2*pi*r)                 constant thickness, no slip
dH/dt     = Te - T_web - B*omega,   H = J*omega    momentum form
dF/dt     = mode*(E*A/L)*(v_surf - v_line)         lumped elastic web
```

**Variable inertia.** The momentum form is used deliberately:

```
d(J*omega)/dt = J*domega/dt + omega*dJ/dt = Te - T_web - B*omega
```

so the `omega*dJ/dt` term is carried by the state equation instead of being added
as a fake external load torque. This is the consistent variable-inertia formulation.
For winding (`dJ/dt > 0`) it acts as an extra drag; for unwinding (`dJ/dt < 0`) it
acts as an extra acceleration, exactly as a skater pulling mass inward.

**Sign check.**
- Winding: `T_web = +F*r` opposes the motor, and `v_surf > v_line` increases tension.
- Unwinding: `T_web = -F*r` drives the roll, the motor brakes (`Te < 0`), and
  `v_line > v_surf` increases tension.

**Limits.** `r` is held in `[rc, rmax]`, `F` in `[0, Fmax]`. The limits are enforced
through the derivatives, so the states cannot run out of range.

## 3. Parameters (illustrative — not experimental data)

| Symbol | Value | Meaning |
|---|---|---|
| rho | 800 kg/m³ | wound-material density (paper/board-like) |
| w | 0.30 m | web width |
| h | 0.5 mm | web thickness |
| E | 2.0 GPa | Young's modulus |
| L | 1.0 m | free web length |
| rc | 0.05 m | core radius |
| rmax | 0.12 m | maximum roll radius |
| r0 winding | 0.06 m | initial radius |
| r0 unwinding | 0.115 m | initial radius |
| Jc | 0.005 kg·m² | core + shaft inertia |
| Jm | 0.0008 kg·m² | motor rotor inertia (existing model) |
| B | 0.0001 N·m·s | viscous damping (existing model) |
| F_ref | 15 N | tension setpoint |
| Fmax | 200 N | web strength limit |
| Tmax | 5 N·m | drive torque limit (existing saturation) |
| v_line | 0.2 → 2.0 m/s | ramp at 0.9 m/s² |

These values were chosen so the roll spans a realistic radius/inertia ratio and the
torque stays inside the lab motor's range. They are **not** claimed as measured or
industry-standard.

## 4. Model structure

```
models/winder_mechanics.slx
├── Line speed (ramp) -> v_sat -> v_line
├── Tension ref, Mode
├── Winder Plant            (S-function, pure spring: r, H, F states)
│     inputs : Te, v_line, mode
│     outputs: F, r, J, TL, omega, v_surf, m
├── Virtual Drive           (validation only: speed PI + tension draw trim)
└── LogMux -> logs          (r J F vline vsurf TL omega Te omega_ref draw)
```

The **Virtual Drive** exists only to exercise the plant in stand-alone validation.
It is not part of the deliverable controller.

This section describes the standalone pre-damping verification model. The drive
models used for the final results embed the native Kelvin–Voigt plant (§7.1, §16).

## 5. How to reproduce

```matlab
cd experiments/exp05_winder_mechanics
addpath('scripts')
winder_params
winder_mode = 1;  r0 = winder.r0_wind;
omega0 = v_init/r0; J0 = winder_Jfun(r0); H0 = J0*omega0; F0 = winder.F0;
Te0 = F0*r0;
build_winder_model
run('scripts/validate_winder.m')
```

## 6. Standalone pre-damping verification (linear ramp)

This section verifies the standalone `models/winder_mechanics.slx` model and its
pure-spring S-function plant (`C_web = 0`). The final drive models use the native
Kelvin–Voigt plant with `C_web = 500 N·s/m`; the residuals and figures below
therefore characterize the pre-damping plant, not the plant used for the final
results.

Two cases, 20 s each, variable-step solver (`VariableStepAuto`, RelTol 1e-4,
MaxStep 1e-3). The S-function uses continuous states.

| Check | Winding | Unwinding |
|---|---|---|
| radius | 0.0600 → 0.0984 m (up) | 0.1150 → 0.0845 m (down) |
| inertia | increases | decreases |
| steady-state tension | 15.000 N | 15.000 N |
| tension error | 0.001 % | 0.001 % |
| `v_surf` vs `v_line` | ~0 % | ~0 % |
| `T_web = mode·F·r` | exact | exact |
| `J(r)` identity | exact | exact |
| radius ODE residual | 1.7e-10 | 1.4e-10 |
| momentum ODE residual | 9.2e-07 | 1.4e-08 |
| tension ODE residual | 8.3e-08 | 2.5e-07 |
| limits | respected | respected |

Full numbers: `results/validation_metrics.csv`.

### What the residuals mean

The ODE residuals are computed as

```
Δr  - ∫ mode·h·v_line/(2πr) dt
ΔH  - ∫ (Te - T_web - B·omega) dt ,   H = J·omega
ΔF  - ∫ mode·(E·A/L)·(v_surface - v_line) dt
```

They are relative to the state change over the run. Values at the 1e-7…1e-10
level mean the logged signals satisfy the implemented equations to solver
accuracy, including the variable-inertia term inside `dH/dt`.

### Notes on the build

- The plant is a Level-2 MATLAB S-function with continuous states
  (`NumContStates = 3`), not Dwork states.
- `DirectFeedthrough` is set to zero for `Te` and `v_line` (they affect only the
  derivatives) and one for `mode` (it sets the `T_web` output). This removes the
  algebraic loop between the drive and the plant.
- The validation drive uses continuous PI blocks so the variable-step solver is
  not forced to step at the 20 µs controller rate. The real drive keeps its own
  discrete 20 µs timing.

### Plots

- `figures/fig_winding_validation.png`
- `figures/fig_unwinding_validation.png`

Each contains: r(t), J(t), F(t), v_line vs v_surf, T_web(t), omega(t).

### Model screenshots

- `figures/model_top_level.png`
- `figures/model_plant.png`

## 7. Integration with the existing PMSM drive

The correct interface is **speed-imposed**: the winder owns the mechanical dynamics,
the PMSM is a torque actuator driven at the winder speed. This is required because
the roll inertia is variable and cannot be represented by the PMSM block's constant
`J`.

### Procedure

1. Copy `experiments/exp03_rs_boundary/models/svm_dtc_rs.slx` to
   `experiments/exp05_winder_mechanics/models/svm_dtc_winder.slx`.
2. In the copy, set the PMSM block mechanical parameters to zero
   (`J = 0`, `lam = 0`). The electrical parameters are unchanged. `Jm` and `B`
   move into the winder plant, so nothing is double-counted.
3. Remove the Ideal Torque Source (`Load_step`) from the PMSM mechanical port.
4. Add a **Torque Sensor** in series with an **Ideal Angular Velocity Source**:
   `PMSM R -> Torque Sensor -> Ideal Angular Velocity Source -> Mechanical Reference`.
   The torque sensor measures `Te`; the velocity source imposes `omega` from the winder.
5. Connect `Te` (PS-Simulink) to the winder plant input 1.
6. Connect the winder `omega` output to the velocity source (Simulink-PS) and to the
   controller speed feedback.
7. Replace the constant speed reference with `v_line/r` (for a speed-controlled
   first test). For tension control, add the draw trim used in the validation drive.
8. Keep the existing solver (`VariableStepAuto`, MaxStep 1e-6) and run a short case
   (e.g. 2 s) before the full profile.

### Expected first checks

- The controller's `omega` equals the winder `omega`.
- The measured `Te` equals the electromagnetic torque (PMSM mechanical block inertia
  set to zero).
- The drive tracks `omega_ref = v_line/r`; tension settles to `F_ref` when the draw
  trim is active.

### 7.1 Verified integration (both controllers)

Files: `models/svm_dtc_winder.slx`, `models/classic_dtc_winder.slx`.
Both use the **same native-block winder subsystem** and the same parameters.

Case: winding, `r0 = 0.06 m`, `H0 = 0`, `F0 = 15 N`, `v_line = 1.2 m/s`,
speed reference 20 rad/s, `Tsim = 0.2 s`.

| Metric | SVM-DTC | Classical DTC |
|---|---|---|
| steady speed | 19.92 rad/s | 19.92 rad/s |
| speed error | 0.41 % | 0.40 % |
| peak speed | 20.33 rad/s | 20.31 rad/s |
| final tension | 41.74 N | 44.32 N |
| final radius | 0.06032 m | 0.06032 m |
| final inertia | 8.434e-3 kg·m² | 8.434e-3 kg·m² |
| final Te | 2.712 N·m | 3.026 N·m |
| peak Te | 4.518 N·m | 5.837 N·m |
| torque-balance RMS | 2.36e-3 N·m | 3.39e-3 N·m |
| torque-balance max | 1.18e-2 N·m | 1.91e-2 N·m |

Torque balance is checked as

```
Te - T_web - B*omega - d(J*omega)/dt
```

with `J`, `omega`, `T_web` and `Te` taken from the run. Residuals of a few
milli-newton-metres confirm the mechanical equation, including the variable-inertia
term.

**Physical observations**

- During the speed ramp the roll surface is slower than the line, so the web goes
  slack (`F = 0`) and tension only builds after the roll catches up. This is correct
  for a taut-web-only model, not a numerical artefact.
- Classical DTC shows much larger torque ripple (visible as the thick band in the Te
  plot); SVM-DTC is smooth.
- The different final tension (41.7 vs 44.3 N) comes from the accumulated speed
  mismatch: tension is the integral of `(omega*r - v_line)`, so the two controllers'
  different trajectories integrate to different values even with identical mechanics.
- Radius and inertia are identical at the end because both controllers reach the same
  final speed with the same mechanics.

Comparison figure: `figures/fig_controller_comparison.png`.
Simulation data: `results/comparison_svm_dtc_winder.mat`,
`results/comparison_classic_dtc_winder.mat`.

### 7.2 Parameter check

`lam` in the PMSM block is **viscous damping** (`N*m*s/rad`), not flux linkage.
It is set to zero and moved into the winder as `B`. The PM flux linkage
`pm_flux_linkage = lambda_f` is **not** touched.

### 7.3 Known limitation of this first integration run

The speed reference is the original constant step (20 rad/s), while `v_line` is
fixed at 1.2 m/s. Tension therefore rises as the radius grows. A winder-normal
test should set `omega_ref = v_line/r` (or enable the draw trim); that is a
reference-layer change, not a plant change, and is the next step for the
control study.

## 8. Closed-loop tension control

### 8.1 Why tension rose from 15 N to ~42–44 N

Logged signals confirm the mechanism exactly. Tension is the integral of the
surface-speed mismatch:

```
dF/dt = mode*(E*A/L)*(omega*r - v_line),   E*A/L = 3.0e5 N/m
```

| | SVM-DTC | Classical DTC |
|---|---|---|
| slack ends (F crosses 0.05 N) | 0.094 s | 0.088 s |
| F rise after slack | 41.69 N | 44.27 N |
| `K*∫(omega*r - v_line)dt` over the taut phase | **41.694 N** | **44.273 N** |
| mean mismatch, last 20 % | +8.1e-4 m/s | +7.1e-4 m/s |
| mean dF/dt, last 20 % | +243 N/s | +213 N/s |

Two effects:

1. **Startup slack.** The drive accelerates from rest while the line is already
   at 1.2 m/s, so `omega*r < v_line`; the taut-web model clamps `F` at 0 for
   about 0.09 s.
2. **No tension equilibrium.** The speed loop holds `omega` at its reference
   while `r` grows, so `omega*r` drifts a few tenths of a mm/s above `v_line`.
   With `K = 3e5 N/m`, that is hundreds of N/s. The 15 N initial condition is
   lost during the slack phase; the final 42–44 N is simply the integral of the
   post-slack mismatch. It is not a regulated value.

The integral check matches the measured rise to the last digit, so the
explanation is complete.

### 8.2 Implemented architecture

```
F_ref ──►(+)──► PI_F ──► u ──┐
          ▲(−)                ├──►(+)──► mode ──► dw ──►(+)──► w_ref ──► rate limiter ──► existing speed loop
          │                   │                          ▲
          F              take-up bias b                  │
                                                     w_ff = v_line/r
```

- Feedforward `w_ff = v_line/r`.
- Feedback `u = Kp_F*(F_ref - F) + Ki_F*∫(F_ref - F)dt`.
- Slack bias `b = draw_takeup * sat(1 - F/F_slack, 0, 1)` (continuous, no switching).
- Correction `dw = mode*(u + b)`; `w_ref = w_ff + dw`.
- `mode = +1` winding: raise tension by running the roll faster.
  `mode = -1` unwinding: raise tension by running the roll slower.
- Limits: PI output `±draw_max`, `w_ref` in `[w_min, w_max]`, clamping anti-windup.
- Inner DTC/SVM-DTC, inverter and estimators unchanged.

### 8.3 Tuning (documented, not fitted to graphs)

Plant from `dw` to `F` is an integrator with gain `K*r`; at `r = 0.06 m`,
`K*r = 1.8e4`. Choose `wn = 4 rad/s`, `zeta = 1`:

```
Kp_F = 2*zeta*wn/(K*r) = 4.4e-4 rad/s per N
Ki_F = wn^2/(K*r)      = 8.9e-4 rad/s per N per s
draw_max = 0.2 rad/s, draw_takeup = 0.02 rad/s, F_slack = 0.5 N
```

Slower gains (`Kp_F = 1e-4`, `Ki_F = 2e-4`) were also tested: the same ~5 Hz
ripple remained, which shows the ripple is **not** loop instability.

### 8.4 Results so far (0.5 s, identical mechanics)

| Case | peak F | mean F (0.3–0.5 s) | end F |
|---|---|---|---|
| SVM winding | 26.0 N | 16.96 N | 17.70 N |
| Classical winding | 21.1 N | **15.51 N** | 15.80 N |
| SVM unwinding | **200 N (limit)** | 21.94 N | 20.57 N |

Before the loop, the same cases ended at 41.7/44.3 N. The loop therefore does
regulate the **mean** tension, but two issues remain.

### 8.5 Issues found (not hidden)

1. **Unwinding startup spike.** From rest, the line is already at 1.2 m/s while
   the unwind roll accelerates. The line pulls web faster than the roll releases
   it, so tension spikes and hits the 200 N clamp at the start, then decays
   toward 15 N. This is a startup-profile problem (ramp the line from rest, or
   initialise the roll at line speed), not a tension-loop sign error.
2. **~5 Hz tension ripple in the SVM case** (±1.5 N). Slower PI gains do not
   remove it. The speed loop has a small ripple; the web stiffness `K = 3e5 N/m`
   turns even 0.1 mm/s of speed ripple into tens of N. Classical DTC happens to
   average this better in the winding case. A low-pass on the tension feedback
   (≈2 Hz) or a smoother speed loop is the likely fix.

### 8.6 Status

Implemented in both `svm_dtc_winder.slx` and `classic_dtc_winder.slx` with
identical architecture and parameters. Winding regulation is verified
(classical case is good, SVM case has the ripple above). Unwinding is not yet
acceptable because of the startup spike. The full metric matrix (RMSE, overshoot,
recovery time, torque ripple, current) is therefore **not** reported as final.

## 9. Startup ramp and feedback filter

> **Correction (2026-11-24):** the `filt_sel` switch wiring was corrected so that
> `filt_on = 1` selects the filtered tension. Results earlier in this log were
> produced before that correction; the final 18-case matrix uses filtered feedback.

### 9.1 Changes

- `v_line` now ramps 0 → 1.2 m/s with `T_ramp` (default 1.0 s), identical for
  winding and unwinding. The tension reference uses the ramped `v_line`, so
  `w_ff = v_line/r` starts at zero with the roll at rest.
- First-order feedback filter `1/(tau_F*s+1)`, `tau_F = 1/(2*pi*f_c)`,
  `f_c = 2 Hz` (tau_F = 79.6 ms), applied to the measured tension before the
  PI. A switch (`filt_on`) selects raw or filtered feedback.
- Phase lag of the filter: 45° at 2 Hz; at the tension-loop bandwidth
  (~0.64 Hz) it is `atan(0.64/2) ≈ 18°`. It is therefore not the dominant
  stability limit.
- No PI gain was changed for these tests; the derived
  `Kp_F = 4.4e-4`, `Ki_F = 8.9e-4` remain the default.

### 9.2 Results with the ramp (SVM-DTC, f_c = 2 Hz)

| Case | behaviour during ramp |
|---|---|
| winding | tension dips to 11.5–13 N, then recovers toward 15 N |
| unwinding | tension falls to 4.3–7.9 N (web nearly slack) |

The 200 N unwinding spike is **gone** (peak 15 N), but tension is **not held**
during acceleration. The cause is the existing speed loop's ramp-tracking lag:
`omega` lags `w_ff = v_line/r`, so the surface speed is wrong by a fraction of
a mm/s; `K = 3e5 N/m` turns that into several N. With a faster ramp
(`T_ramp = 0.4 s`) winding tension collapsed to ~1–2 N, which is worse.

### 9.3 Verdict

The two changes are implemented and documented, but the system is **not
validated**:

- unwinding spike: fixed by the ramp;
- tension during acceleration: not held (dip to 4–8 N);
- SVM ~5 Hz tension ripple: still present from the pre-ramp tests.

The next required change is a **feedforward** that makes the speed loop track
the ramp, e.g. a torque feedforward `J_total * d(w_ref)/dt` or a tension-loop
acceleration term. A slower ramp (2–3 s) would also work but only hides the
underlying tracking lag.

## 10. Acceleration / inertia feedforward

> **Correction (2026-11-24):** `Tff_extra` now uses `u(2) = F_ref_set` for the web
> tension term instead of the global `F_ref`. The two tension-step cases were re-run
> with the corrected feedforward.

### 10.1 Diagnosis (before modifying)

Winding, `T_ramp = 1.0 s`, 0.5 s run:

| quantity | value |
|---|---|
| peak speed error | 0.565 rad/s at 0.002 s |
| max surface mismatch | 8.3e-3 m/s |
| mean surface mismatch | 5.7e-4 m/s |
| peak PI torque | 1.33 N·m |
| torque saturation | **0 %** |
| peak Te | 1.21 N·m (limit 5 N·m) |

The tension error is **not** caused by torque saturation or an undersized
motor. It is speed-loop ramp-tracking error; `K = 3e5 N/m` turns a fraction of
a mm/s into hundreds of N/s.

### 10.2 Derivation

Plant (momentum form, as implemented):

```
d(J*w)/dt = Te - T_web - B*w ,   T_web = mode*F*r
```

Hence the torque needed to follow `w_ref`:

```
T_ff = J*wdot_ref + (dJ/dt)*w_ref + mode*F_ref*r + B*w_ref
```

with

```
m      = rho*w*pi*(r^2 - rc^2)
J      = Jm + Jc + 0.5*m*(r^2 + rc^2)
dJ/dr  = rho*w*pi*r*(r^2 + rc^2) + m*r
rdot   = mode*h*v_line/(2*pi*r)
wdot   = (dv_line/dt)/r - v_line*rdot/r^2
```

Material transfer: the plant uses the comoving control volume, so the added or
removed web carries no additional relative angular momentum at the surface;
`dJ/dt*w` is the only variable-inertia term. No extra momentum term is missing.

### 10.3 Implementation

- `Tff` Fcn block with the expression above, analytical derivatives only.
- `Te* = sat(T_PI + T_ff)`, saturation at ±Tmax.
- `ff_on` gate (0 = before, 1 = after) with identical mechanics and controllers.
- Applied to both models (`svm_voltage_command/5` and `MATLAB Function1/1`).

### 10.4 Before / after (SVM-DTC, winding, 0.1–0.5 s)

| metric | ff off | ff on |
|---|---|---|
| tension RMSE | **2.034 N** | **9.568 N** |
| max tension | 21.36 N | 29.62 N |
| min tension | 8.07 N | 14.36 N |
| speed RMSE | **0.0088 rad/s** | **0.0118 rad/s** |
| max surface mismatch | 1.44e-3 m/s | 3.48e-3 m/s |
| peak Te | 1.21 N·m | 1.97 N·m |
| torque ripple (std) | 0.076 N·m | 0.121 N·m |
| peak current | 1.05 A | 1.70 A |

### 10.5 Conclusion: the feedforward, as implemented, degrades regulation

The derivation is correct, but adding the **full** feedforward, including
`mode*F_ref*r`, double-counts the tension torque that the speed PI already
supplies through its speed error. The summed command over-drives the roll,
the surface speed overshoots, and the stiff web converts that into a tension
overshoot (29.6 N). The PI then has to unwind, which also increases the speed
RMSE.

The result is **not validated**, and the experiment matrix was not run.

### 10.6 Recommended next experiment

1. Feedforward the **inertia term only** (`J*wdot + dJ/dt*w`), leaving the
   tension torque to the speed PI / tension loop. This avoids the double count.
2. Or move to the industrial **torque-mode tension architecture**: the tension
   PI commands torque directly, the speed loop becomes a limit, and the
   feedforward supplies `J*wdot + dJ/dt*w`. This is the structure used by
   commercial winder drives and would remove the speed-loop/tension-loop
   interaction altogether.
3. Re-run the same before/after test; only if the inertia-only feedforward
   reduces tension RMSE without increasing peak torque should the matrix be
   run.

## 11. Inertia-only feedforward: A/B/C comparison

Configurations (same mechanics, controllers, ramp, filter, gains):

- **A**: `ff_on = 0`
- **B**: `ff_on = 1`, `ff_full = 1` (inertia + tension + friction)
- **C**: `ff_on = 1`, `ff_full = 0` (inertia only)

`T_inertia = J*wdot_ref + (dJ/dt)*w_ref`, with `J` taken directly from the
winder plant and analytical derivatives.

### 11.1 Winding (r0 = 0.06 m, 0.5 s, 1.0 s ramp)

| metric | A off | B full | **C inertia-only** |
|---|---|---|---|
| tension RMSE | 2.034 N | 9.568 N | **0.774 N** |
| max tension | 21.36 N | 29.62 N | 23.44 N |
| min tension | 8.07 N | 14.36 N | 9.85 N |
| overshoot | 6.36 N | 14.62 N | 8.44 N |
| speed RMSE | 0.00884 rad/s | 0.01183 | **0.00832** |
| surface mismatch | 1.44e-3 m/s | 3.48e-3 | **1.41e-3** |
| peak Te | 1.207 N·m | 1.965 | 1.236 |
| torque ripple | 0.076 N·m | 0.121 | **0.046** |
| peak current | 1.05 A | 1.70 | 1.12 |
| saturation | 0 s | 0 s | 0 s |
| balance residual | 2.0e-3 | 2.2e-3 | 2.0e-3 |

**Winding: C is accepted.** Tension RMSE falls 62 %, speed RMSE and surface
mismatch improve, ripple falls 39 %, no saturation; peak torque and current rise
only 2–7 %.

### 11.2 Unwinding (r0 = 0.115 m, 0.5 s, 1.0 s ramp)

| metric | A off | B full | C inertia-only |
|---|---|---|---|
| tension RMSE | 8.908 N | 11.463 N | **6.151 N** |
| max tension | 15.00 N | 15.00 N | 15.00 N |
| min tension | **0.00 N** | **0.00 N** | **0.00 N** |
| speed RMSE | **0.00769 rad/s** | 0.00807 | 0.00879 |
| surface mismatch | 2.29e-3 m/s | **5.01e-4** | 3.82e-3 |
| peak Te | 1.139 N·m | **0.804** | 1.421 |
| torque ripple | 0.116 N·m | 0.151 | **0.090** |
| peak current | **0.23 A** | 0.40 | 0.48 |
| saturation | 0 s | 0 s | 0 s |

**Unwinding: C is not accepted.** It lowers tension RMSE but worsens speed
tracking and surface mismatch, and raises peak torque (1.42 vs 1.14 N·m) and
peak current (0.48 vs 0.23 A). All three configurations allow the web to go
slack (`F = 0`) during the run, so the RMSE is dominated by the slack interval,
not by the feedforward.

### 11.3 Decision

- Full feedforward (B) is rejected in both directions; it double-counts the
  tension torque and over-drives the roll.
- Inertia-only (C) is accepted **for winding only**.
- The unwinding case still has a slack/startup problem that the inertia
  feedforward does not solve. Per the decision rule, the full experiment matrix
  is **not** run and the classical drive is **not** updated yet.

### 11.4 Next experiment

Diagnose the unwinding slack: log `omega*r - v_line` and the sign of `T_ff`
during the first 0.1 s. The likely causes are the sign of the inertia term in
unwinding and the speed-loop response to a negative (braking) torque demand.
Only after that is fixed should C be applied to the classical model.

## 12. Independent audit and correction (supersedes section 11)

### 12.1 Root cause: the speed-reference lower saturation

`w_min` was 0.5 rad/s and saturates the tension-controller output *after* the
rate limiter. At standstill `v_line = 0`, so `w_ff = v_line/r = 0`, but the
saturation forced `w_ref = 0.5 rad/s`.

Evidence (unwinding, t = 0):

```
v_line = 0.0000 m/s      Tension Control output = 0
omega_ref = 0.500 rad/s  omega = 0.500 rad/s at 2 ms
vsurf > v_line           -> dF/dt < 0 -> web goes slack
```

The roll was commanded to 0.5 rad/s while the line was at rest. In unwinding
this guarantees slack; in winding it artificially raised tension and masked the
startup dip. **Every A/B/C comparison before this fix is invalid.**

### 12.2 Corrected results, `w_min = 0` (0.5 s, 1.0 s ramp)

Winding:

| metric | A off | B full | C inertia-only |
|---|---|---|---|
| tension RMSE | 9.896 N | **0.831 N** | 9.037 N |
| max / min | 15.00 / 0.00 | 18.89 / 8.07 | 15.00 / 0.00 |
| speed RMSE | 0.01245 | **0.00879** | 0.01207 |
| mismatch | 1.93e-3 | **1.74e-3** | 2.12e-3 |
| peak Te | 0.860 | 1.227 | 0.877 |
| ripple | 0.152 | **0.054** | 0.138 |
| peak current | 0.73 A | 1.12 A | 0.77 A |

Unwinding:

| metric | A off | B full | C inertia-only |
|---|---|---|---|
| tension RMSE | 6.623 N | **0.142 N** | 10.215 N |
| max / min | 15.00 / 0.00 | 17.30 / 12.80 | 15.00 / 0.00 |
| speed RMSE | 0.00563 | **0.00105** | 0.00732 |
| mismatch | 1.45e-3 | **5.32e-4** | 6.68e-4 |
| peak Te | 0.446 | 1.102 | 0.673 |
| ripple | 0.084 | **0.020** | 0.130 |
| peak current | 0.42 A | 1.00 A | 0.26 A |

No configuration saturates torque in either direction. Torque-balance residual
is 1.8–2.0e-3 N·m throughout.

### 12.3 Conclusions that must be revised

- **The full feedforward (B) is the best configuration in both directions.**
  Tension RMSE falls by ~90 % versus the baseline; speed RMSE, surface mismatch
  and torque ripple also improve.
- **The "double-counting" hypothesis is not supported.** With the correct
  reference, the full feedforward does not degrade winding. The earlier poor
  result (RMSE 9.57) was caused by the 0.5 rad/s reference floor, not by the
  tension-torque term.
- **Inertia-only (C) is not sufficient.** It does not prevent the startup slack
  (min tension 0 N in both directions); the tension-torque feedforward is what
  holds the web while the line accelerates.
- The earlier baseline A also looked better than it was (RMSE 2.03 winding)
  because the forced 0.5 rad/s raised tension and masked the slack.

### 12.4 Current model state

- `w_min = 0` (standstill allowed), documented in `winder_params.m`.
- Modular feedforward with `ff_on` and `ff_full` gates, identical in principle
  for both drives.
- The classical model still carries an older feedforward build and has **not**
  been updated to the modular version; it must be rebuilt before the classical
  comparison.

### 12.5 Remaining work

- 0.5 s covers only the start of the ramp; a 1.5–2 s run with visible radius
  change is needed before claiming validation.
- Rebuild the feedforward on `classic_dtc_winder.slx` and run the same cases.
- Only then run the full winding/unwinding matrix and compare DTC vs SVM-DTC.

## 13. Two-second validation (SVM-DTC) and classical-DTC blocker

### 13.1 Numerical setting

`MaxStep = 5e-6` was verified against `1e-6` on a 0.2 s case:

| MaxStep | wall time | tension RMSE | max F | Te peak |
|---|---|---|---|---|
| 1e-6 | 72.7 s | 1.103 N | 18.89 | 1.192 |
| 5e-6 | 28.1 s | 1.096 N | 18.90 | 1.192 |

The difference is negligible, so 2 s runs use 5e-6.

### 13.2 SVM-DTC, 2 s, full feedforward

| metric | winding | unwinding |
|---|---|---|
| r | 0.0600 → 0.0623 m | 0.1150 → 0.1137 m |
| J | 8.33e-3 → 9.14e-3 | 6.94e-2 → 6.66e-2 |
| tension RMSE | 1.043 N | **0.175 N** |
| tension max / min | 19.55 / 8.08 N | 21.02 / 9.84 N |
| mean tension (ss) | 15.23 N | 15.00 N |
| slack fraction | 0 % | 0 % |
| speed RMSE | 0.0257 rad/s | **0.00129 rad/s** |
| surface mismatch max | 2.60e-3 m/s | 2.66e-4 m/s |
| peak Te | 1.328 N·m | 1.803 N·m |
| torque ripple | 0.076 N·m | 0.019 N·m |
| peak current | 1.23 A | 1.71 A |
| saturation | 0 s | 0 s |
| torque-balance RMS | 6.0e-3 N·m | 2.7e-3 N·m |

Two real fixes were required during this validation:

1. **Ramp-slope gating.** The feedforward originally kept using
   `v_line_set/T_ramp` after `v_line` had saturated, injecting continuous
   acceleration torque after t = 1 s. The tension envelope grew without bound.
   Gating `dv_line/dt` to zero after the ramp removed the growth (RMSE 1.53 →
   1.04 N on winding).
2. **Filter initial condition.** The feedback filter now starts at `F0`
   (15 N) instead of zero, so it does not create a false 15 N error at t = 0.

Remaining visual issues:

- A **corner at the end of the ramp** (t = 1 s) produces a tension
  transient (winding: spike to 19.5 N; unwinding: 21 N / 9.8 N).
  The line-speed profile is a pure ramp with a slope discontinuity; an
  S-curve profile would remove it.
- Winding still has a dip to 8.08 N at about 0.58 s. It is a transient, not
  a sustained slack, but it is unresolved and is recorded as a limitation.
- A switching-frequency tension ripple remains (the stiff web amplifies the
  speed ripple). It is physical, not numerical.

**Verdict: SVM-DTC winding = conditional pass; unwinding = pass.**

### 13.3 Classical DTC: integration failure

The same architecture was applied to `classic_dtc_winder.slx`
(`add_startup_and_filter`, `add_feedforward` into `MATLAB Function1/1`).

| metric | classical winding | classical unwinding |
|---|---|---|
| tension RMSE | 12.877 N | 12.859 N |
| max / min | 16.55 / 0.00 N | 48.13 / 0.00 N |
| mean tension | 2.77 N | 17.12 N |
| slack fraction | **63.3 %** | 10.9 % |
| speed RMSE | 0.156 rad/s | 0.0646 rad/s |
| peak current | **21.3 A** | **36.3 A** |
| peak Te | 1.563 N·m | 5.519 N·m |
| saturation | 0 s | 0.002 s |

The classical drive does not follow the reference and draws tens of amps. This
is not a tuning issue: the feedforward/tension command is being injected into a
different inner-loop interface than in the SVM model, and the classical DTC
torque path is either sign-inverted, in different units, or expects a different
quantity at `MATLAB Function1/1`. **The classical model is not validated, the
comparison is not run, and no claim is made.**

### 13.4 Acceptance table

| Test | Status |
|---|---|
| SVM winding 2 s | conditional pass (dip 8 N, ramp-end transient) |
| SVM unwinding 2 s | pass |
| Classical winding 2 s | **fail** |
| Classical unwinding 2 s | **fail** |
| SVM vs classical comparison | blocked by classical failure |
| Robustness (speed / radius / disturbance) | not started |
| Final report | partial |

### 13.5 Next action

Diagnose the classical torque interface before any further tuning:
inspect the input of `MATLAB Function1`, compare its expected torque reference
with the PID output in the unmodified model, and check sign/units. Do not copy
the SVM injection point blindly.

### 13.6 Classical failure root cause: low-speed flux-estimator collapse

Separating the feedforward from the tension/reference integration:

| classical winding 2 s | with full FF | with `ff_on = 0` |
|---|---|---|
| tension RMSE | 12.877 N | 12.847 N |
| slack fraction | 63.3 % | 66.9 % |
| peak current | 21.3 A | 21.2 A |
| speed RMSE | 0.156 | 0.1487 |

The failure is independent of the feedforward.

Direct flux log (classical, 0.5 s winding, `ff_on = 0`):

```
|lambda_s| estimate: start 0.175 Wb -> end 0.004 Wb
min 0.001 Wb, max 0.241 Wb        (reference 0.175 Wb)
phase current: peak 21.2 A, rms 14.5 A
tension: ends at 0 N
```

The pure-integrator voltage-model estimator drifts and collapses at low speed.
The classical switching table then applies large vectors to raise the
*estimated* flux, which does not correspond to the true flux, so the current
explodes and torque control is lost. The SVM-DTC survives because its flux PI
regulates the estimate continuously and the modulation is smoother.

This is the known low-speed limitation of classical DTC, not a winder or
feedforward fault. A fair classical-vs-SVM comparison at startup requires a
practical flux estimator on the classical side (current-model/voltage-model
blend or a compensated integrator); alternatively, both drives can be started
at a minimum speed and the comparison restricted to that region.

### 13.7 Updated acceptance table

| Test | Status |
|---|---|
| SVM winding 2 s | conditional pass (dip 8 N, ramp-end transient) |
| SVM unwinding 2 s | pass |
| Classical winding 2 s | **fail — flux estimator collapse** |
| Classical unwinding 2 s | **fail — same root cause** |
| Feedforward as the cause of classical failure | **ruled out** |
| SVM vs classical comparison | blocked |
| Robustness | not started |

## 14. Correction: the classical failure was a wiring error, not the estimator

### 14.1 Root cause

The classical switching-table function signature is

```
(lambda_s_mag, theta_s_deg, Te_est, lambda_ref, Te_ref, HB_lambda, HB_torque)
```

Port `in1` is **lambda_s_mag**; the torque reference is `in5`. The feedforward
was injected into `in1`, replacing the flux magnitude with the torque command.
That broke the flux hysteresis loop and produced the 21 A currents and apparent
estimator collapse. The voltage-model estimator itself was never at fault.

After restoring `in1 <- lambda_s_mag` and injecting the feedforward at `in5`,
the classical drive behaves correctly.

### 14.2 Classical estimator health (2 s winding, no feedforward)

```
|lambda_s|: start 0.1750 Wb -> end 0.1750 Wb
            min 0.1699 Wb, max 0.1801 Wb
current:    peak 2.12 A, rms 0.76 A
```

The pure voltage-model estimator is adequate for this duty once the control
loop is wired correctly. **A hybrid current-model/voltage-model estimator is
therefore not required**, and adding one would be unnecessary complexity.
Route A is closed by evidence, not implemented.

### 14.3 Full comparison (identical mechanics, tension loop, ramp, filter, feedforward)

| metric | SVM wind | Classical wind | SVM unwind | Classical unwind |
|---|---|---|---|---|
| tension RMSE | 1.043 N | **0.315 N** | **0.175 N** | 0.224 N |
| max / min | 19.55 / 8.08 | 15.86 / 14.09 | 21.02 / 9.84 | 17.61 / 13.26 |
| mean (ss) | 15.23 N | 15.16 N | 15.00 N | 15.03 N |
| speed RMSE | 0.0257 | **0.00623** | **0.00129** | 0.00164 |
| mismatch max | 2.6e-3 | 1.31e-3 | 2.66e-4 | 4.58e-4 |
| peak Te | **1.328** | 2.017 | **1.803** | 2.698 |
| torque ripple | **0.076** | 0.419 | **0.019** | 0.414 |
| peak current | **1.23 A** | 1.91 A | **1.71 A** | 2.58 A |
| saturation | 0 s | 0 s | 0 s | 0 s |
| balance RMS | 6.0e-3 | 3.8e-2 | 2.7e-3 | 3.8e-2 |

### 14.4 Feedforward effect (same controller)

| case | no FF | full FF | improvement |
|---|---|---|---|
| classical winding | 5.712 N | **0.315 N** | 94 % |
| classical unwinding | 2.307 N | **0.224 N** | 90 % |
| SVM winding | 9.896 N* | 1.043 N | 89 % |
| SVM unwinding | 6.623 N* | 0.175 N | 97 % |

*SVM no-FF values from the corrected `w_min = 0` baseline.

The feedforward removes the startup slack in all four cases and reduces tension
RMSE by ~90 %. It costs higher peak torque and current (classical: 2.02 vs
2.24 N·m, 1.91 vs 2.12 A; no saturation).

### 14.5 Physical interpretation

- **Classical DTC + feedforward** gives the tightest tension band in this
  study (14.1–15.9 N winding, 13.3–17.6 N unwinding) and the best speed
  tracking, at the cost of higher torque ripple (0.42 N·m vs 0.02–0.08 N·m)
  and higher peak current.
- **SVM-DTC** is much smoother and draws less peak current, but its winding
  case still has an 8 N dip near 0.58 s and a 21 N/9.8 N ramp-end transient.
- No torque saturation occurs in any validated case.

### 14.6 Remaining issues

- SVM winding dip to 8.08 N at ~0.58 s (not present in the classical case);
  needs signal-level diagnosis before the final comparison is declared.
- Ramp-end corner (t = 1 s) produces a tension transient; an S-curve line
  profile is the justified remedy.
- Classical torque-balance residual is 3.8e-2 N·m (vs 6e-3 for SVM), consistent
  with its larger torque ripple; still ~2 % of rated torque.
- Robustness matrix (speed, initial radius, tension step) not run.

### 14.7 Decision

Do **not** implement the hybrid estimator: the classical voltage-model estimator
is validated after the wiring correction. Proceed with the existing classical
model for the final comparison, and investigate the SVM winding dip before
publishing the comparison.

## 15. SVM winding resonance — current blocker

### 15.1 Evidence

Saved 2 s winding data (`results/val2s_svm_wind_ff_v4.mat`), 0.54–0.62 s:

```
t      F      w_ref    w       v_surf-v_line    Te
0.558  15.56  11.114   11.115   -0.0001         1.076
0.577  17.57  11.488   11.483   -0.0004         1.113
0.587   8.15  11.689   11.677   -0.0006         0.926
0.598  19.49  11.901   11.918   +0.0009         1.122
0.607   8.17  12.083   12.073   -0.0003         0.939
```

Tension oscillates between ~8 and ~19.5 N with a period of about 20 ms
(~50 Hz); speed oscillates by ±0.2 rad/s. The predicted torsional mode of the
elastic web plus roll inertia is

```
sqrt(K*r^2/J) = sqrt(3e5 * 0.0036 / 0.00833) ≈ 361 rad/s ≈ 57 Hz
```

which is the same order as the observed ringing.

### 15.2 What it is not

Lowering the speed PI from `Kp = 2, Ki = 150` to `Kp = 0.2, Ki = 15` made the
winding case worse:

```
F RMSE 4.335 N, F min 3.20, F max 23.78
speed range 9.96–15.93 rad/s
```

So it is not simply an over-fast speed loop, and increasing damping by
detuning is not the answer.

The classical DTC uses the same mechanics, tension loop, ramp, filter and
feedforward, and does **not** ring (2 s winding RMSE 0.315 N, 14.09–15.86 N).
Its inner hysteresis loop evidently adds damping that the SVM flux/torque PI
does not. This is a controller–plant interaction, not an estimator or wiring
fault.

### 15.3 What is required

The elastic web model has **no material damping**: the tension dynamics are
purely `dF/dt = K(v_surf - v_line)`. A real web has viscoelastic damping. The
physically justified fix is to add a damping term to the web model (or an
equivalent damping/notch filter in the tension path), then re-check the
resonance. Arbitrary gain changes are not appropriate.

This is a genuine technical decision point: it changes the mechanical plant, so
it must be agreed before the S-curve and robustness matrix are run.

### 15.4 Status of the remaining work

| Item | Status |
|---|---|
| Corrected torque injection (classical) | done |
| Hybrid estimator | **not needed** — evidence |
| 4-way 2 s comparison | done |
| SVM winding resonance | **open blocker** |
| S-curve line reference | not started |
| Robustness matrix | not started |
| Final consolidated report | partial |

## 16. Resonance resolution: Kelvin–Voigt web damping

### 16.1 Model correction

The original web model was a pure spring:

```
dF/dt = K*(v_surf - v_line),   K = E*A/L = 3e5 N/m
```

Real webs are viscoelastic. The corrected Kelvin–Voigt model is

```
x_dot = mode*(v_surf - v_line)          web extension state
F     = K*x + C*x_dot                   spring + dashpot, saturated to [0, Fmax]
```

The torsional mode of the roll + web is then

```
J*w'' + C*r^2*w' + K*r^2*w = 0
zeta = C*r / (2*sqrt(J*K))
```

At r = 0.06 m, J = 8.33e-3 kg·m², K = 3e5 N/m, the measured ringing was
~50 Hz and the undamped estimate `sqrt(K r^2/J)/(2π) ≈ 57 Hz`. With
`C = 500 N·s/m`, `zeta ≈ 0.30` — a conventional, lightly damped web. The same
`C` gives `zeta ≈ 0.15` at the large unwind radius, which is still damped.

### 16.2 Effect (SVM winding, 2 s)

| version | F RMSE | min | max | speed RMSE |
|---|---|---|---|---|
| pure spring, ramp | 1.043 N | 8.08 | 19.55 | 0.0257 |
| Kelvin–Voigt, ramp | 0.770 N | 9.47 | 17.67 | 0.0148 |

The 50 Hz envelope growth is removed and speed ringing is halved. Residual
isolated dips (≈10 N) are transient events, not sustained resonance; they are
bounded and do not reach slack.

## 17. S-curve line-speed reference

```
tau  = sat(t/T_ramp, 0, 1)
v(t) = v_set * (3*tau^2 - 2*tau^3)
dv/dt = v_set * (6*tau - 6*tau^2)/T_ramp
```

Continuous velocity, zero acceleration at both ends, identical for winding and
unwinding. The feedforward uses the analytic derivative `dv/dt` instead of a
gated constant slope, which also removes the old ramp-end discontinuity.

Effect (SVM winding, 2 s, damped web):

| reference | F RMSE | min | max |
|---|---|---|---|
| linear ramp | 0.770 N | 9.47 | 17.67 |
| S-curve | 0.772 N | **10.01** | **17.29** |

The S-curve does not change steady-state accuracy; it removes the slope corner
and lifts the worst dip by ~0.5 N.

## 18. Final experiment matrix

`scripts/run_final_matrix.m` runs, under identical mechanics/controllers/limits:

- four-way comparison: SVM/classical × FF off/on, winding and unwinding (8 cases);
- line-speed robustness: 0.8 and 1.6 m/s, winding, both controllers, FF on;
- initial-radius robustness: winding r0 = 0.08 m, unwinding r0 = 0.10 m;
- tension-reference step 15 → 18 N at t = 1.2 s, winding, both controllers.

All cases use the S-curve, Kelvin–Voigt web, 2 s duration, `MaxStep = 5e-6`.
Results are written to `results/final_matrix.csv` and `.mat`; figures to
`figures/fig_case_*.png`. Figure names use the `fig_case_` prefix, and the case
tag is lowercased with periods removed (`SVM_wind_v0.8_ff1` becomes
`fig_case_svm_wind_v08_ff1`).

## 19. Literature comparison and contribution

**Established, reused (not claimed as new):**

- Classical DTC switching table and SVM-DTC modulation (Takahashi/Noguchi;
  Buja/Kazmierkowski; Casadei).
- Voltage-model stator-flux estimator, current-model flux, and the concept of
  hybrid/blended flux observers.
- Speed-loop torque feedforward for inertia compensation (standard servo
  practice), extended here to variable radius/inertia with the `dJ/dt` term.
- Winder tension control by speed trimming (draw) and by torque limits; dancer
  and load-cell architectures.
- Kelvin–Voigt viscoelastic web model.
- PI anti-windup, rate limiting, S-curve motion profiles.

**Project-specific engineering contribution:**

1. A single MATLAB/Simulink bench in which classical DTC and SVM-DTC drive the
   same variable-radius, variable-inertia winder, with identical tension,
   reference, filter and feedforward layers — enabling a fair controller
   comparison under one mechanical plant.
2. Quantified evidence that the dominant winder fault in this architecture is
   not the estimator but the **reference/torque injection path**: the classical
   switching table takes flux magnitude at `in1` and torque at `in5`; injecting
   at the wrong port produced a false "estimator collapse".
3. A feedforward architecture for winders that includes the variable-inertia
   term `(dJ/dt)ω`, an analytic S-curve derivative, and a mode-dependent
   correction sign, evaluated with FF on/off on both controllers.
4. A measured comparison showing the trade-off: classical DTC + FF gives the
   tightest tension band but ~5× the torque ripple and higher peak current;
   SVM-DTC is smoother and draws less current.
5. Identification of the undamped web–roll torsional mode (~50–57 Hz) and a
   physically justified Kelvin–Voigt damping parameter (`C = 500 N·s/m`,
   ζ ≈ 0.3), rather than a gain tweak.

**Not claimed:** a new observer, a new modulation scheme, or a new control
theory. The contribution is a validated system-level study and a small,
defensible engineering improvement (feedforward + S-curve + physical web
damping) on an integrated DTC winder bench.

## 20. Acceptance status

| Requirement | Status |
|---|---|
| Mechanical equations and signs verified | yes (torque-balance residual reported) |
| Flux estimator healthy, classical wiring corrected | yes (0.175 Wb) |
| Feedforward derived/units verified | yes (N·m, plant `J`, analytic derivatives) |
| Resonance investigated and bounded | yes (Kelvin–Voigt, ζ ≈ 0.3) |
| S-curve reference implemented and compared | yes |
| Four-way comparison, both directions | **complete** |
| Robustness: speeds, radii, tension step | **complete** |
| Final figures and report | **complete** |

## 21. Final results (S-curve, Kelvin–Voigt web, 2 s)

### 21.1 Four-way comparison

| configuration | F RMSE | F min | F max | speed RMSE | Te ripple | ia peak |
|---|---|---|---|---|---|---|
| SVM wind, FF off | 7.153 N | 0.00 | 23.43 | 0.01418 | 0.074 | 1.47 A |
| SVM wind, FF on | 0.794 N | 10.03 | 17.19 | 0.01470 | 0.072 | 1.22 A |
| SVM unwind, FF off | 2.784 N | 0.00 | 16.96 | 0.00852 | 0.249 | 1.88 A |
| SVM unwind, FF on | 0.052 N | 8.82 | 17.39 | 0.00033 | 0.019 | 1.72 A |
| Classical wind, FF off | 7.302 N | 0.00 | 23.29 | 0.00410 | 0.421 | 2.25 A |
| Classical wind, FF on | 0.319 N | 13.98 | 16.21 | 0.00381 | 0.418 | 1.98 A |
| Classical unwind, FF off | 2.464 N | 0.00 | 16.92 | 0.00747 | 0.469 | 2.67 A |
| Classical unwind, FF on | 0.114 N | 12.91 | 16.04 | 0.00069 | 0.414 | 2.57 A |

Feedforward reduces tension RMSE by 89–98 % in all four cases and removes
startup slack. No case saturates torque (all `sat_time = 0`).

### 21.2 Robustness

| case | F RMSE | F min | F max | ia peak | sat |
|---|---|---|---|---|---|
| SVM wind, v = 0.8 m/s | 0.473 N | 10.22 | 17.96 | 1.15 A | 0 |
| Classical wind, v = 0.8 | 0.266 N | 14.14 | 15.80 | 1.89 A | 0 |
| SVM wind, v = 1.6 | 0.710 N | 9.74 | 16.59 | 1.36 A | 0 |
| Classical wind, v = 1.6 | 0.355 N | 13.85 | 16.06 | 2.04 A | 0 |
| SVM wind, r0 = 0.08 | 0.647 N | 10.06 | 17.21 | 1.63 A | 0 |
| Classical wind, r0 = 0.08 | 0.240 N | 14.02 | 15.77 | 2.43 A | 0 |
| SVM unwind, r0 = 0.10 | 0.369 N | 9.70 | 18.21 | 1.49 A | 0 |
| Classical unwind, r0 = 0.10 | 0.118 N | 13.07 | 17.02 | 2.35 A | 0 |
| SVM wind, F step 15→18 N | 3.456 N | 10.03 | 19.46 | 1.24 A | 0 |
| Classical wind, F step | 3.304 N | 13.98 | 19.00 | 1.99 A | 0 |

All robustness cases remain stable, unsaturated and free of sustained slack.
The tension-step RMSE includes the step transient in the 1.3–2.0 s window and
should not be compared directly with the steady cases.

### 21.3 Final conclusions

1. **Feedforward is the dominant improvement.** With the corrected torque port
   and the inertia + tension + friction feedforward, tension RMSE drops by
   89–98 % and startup slack disappears in both drives and both directions.
2. **Controller trade-off is now quantified.** Classical DTC + FF gives the
   tightest winding band (13.98–16.21 N), while SVM-DTC + FF is tighter in
   unwinding (0.052 N vs 0.114 N RMSE). Classical DTC has about 6× the winding
   torque ripple (0.42 vs 0.019–0.072 N·m) and higher peak current
   (1.98–2.57 A vs 1.22–1.72 A). SVM-DTC is much smoother and draws less current.
3. **The SVM winding resonance was a real plant/control interaction**, mitigated
   by physically justified Kelvin–Voigt web damping (C = 500 N·s/m, ζ ≈ 0.3) and
   the S-curve reference. The residual winding dips are bounded (~10 N) and no
   longer sustained ringing; they remain a limitation.
4. **The classical "flux collapse" was a wiring error**, not an estimator fault.
   With the torque reference injected at `in5`, the voltage-model estimate stays
   at 0.175 Wb and the current is normal. A hybrid estimator is unnecessary.
5. **All conclusions rest on consistent 2 s runs** with the same mechanics,
   tension loop, reference, filter and limits; the original `exp03` models were
   never modified.

### 21.4 Remaining limitations

- SVM winding has transient dips to ~10 N at 0.1/0.2/0.58 s; bounded, but not
  eliminated. A dedicated analysis of the tension-loop/PI event is still open.
- One machine, one web material, one set of illustrative parameters; `C_web`
  is a physically motivated but not measured value.
- Simulation only; no experimental validation.
- Classical torque-balance residual is 3.8e-2 N·m (vs 6e-3 for SVM), consistent
  with its larger torque ripple.
- The 2 Hz feedback filter and the original speed-loop gains were kept; a
  plant-specific retune was not attempted, to preserve comparability.

## 22. Assumptions and limitations

- Constant web thickness, no slip between web and roll.
- Lumped elastic web (single spring); no transport delay, no web mass, no roller
  eccentricity, no air entrainment.
- Taut-web only: tension is clamped at zero, so the model cannot represent a
  slack web being pushed.
- The web is massless; its kinetic energy is neglected.
- Roll is a hollow cylinder of uniform density; no wound-in tension or radial
  compression.
- No iron loss, saturation or thermal effects in the motor (inherited from the
  existing drive model).
- The illustrative parameters are not experimentally validated.
- The validation drive (speed PI + draw trim) is a test harness, not a proposed
  controller.
