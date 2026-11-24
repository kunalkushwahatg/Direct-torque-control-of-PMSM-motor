# Block and Parameter Audit — `classic_dtc_winder_clean.slx`

**Audit target:** `experiments/exp05_winder_mechanics/models/classic_dtc_winder_clean.slx`  
**Parameter files:** `experiments/exp03_rs_boundary/scripts/pmsm_dtc_parameters.m` and `experiments/exp05_winder_mechanics/scripts/winder_params.m`  
**Runtime wrapper:** `experiments/exp05_winder_mechanics/scripts/run_case_2s.m`  
**Date:** 21 November 2026

This audit concentrates on the parameters that actually change the model's behaviour. It does not repeat every port, scope, position, colour, or library default. Values were read from the saved model with `get_param`, after running `pmsm_dtc_parameters.m` and `winder_params.m` in the base workspace; runtime overrides from `run_case_2s.m` are shown separately. The exhaustive machine-readable dumps are supplied alongside this document:

| File | Contents |
|---|---|
| `classic_dtc_winder_clean_important_params.csv` | 155 rows: curated high-impact parameters, plus the parameter-file and runtime values |
| `classic_dtc_winder_clean_key_values.csv` | 268 records: the important block values, with the expression and resolved number |
| `classic_dtc_winder_clean_all_params.csv` | 4,553 records: every dialog parameter of the 264 user-level/custom blocks, including defaults |
| `classic_dtc_winder_clean_all_blocks.csv` | All 1,048 block paths: 247 user-level blocks + 801 standard library internals |
| `classic_dtc_winder_clean_matlab_functions.txt` | Full source of the two MATLAB Function blocks and the `dtc_estimator` chart |

---

## 1. Scope, counting, and an important warning

`classic_dtc_winder_clean` contains:

- **247 user-level blocks** visible without looking under masks;
- **17 internal blocks** inside `Controller/dtc_estimator`;
- **1,048 blocks in total** when standard library internals are expanded.

The 801 standard-library internals are not “set” by the user. They are the implementation of the PWM-free DTC controller, Simscape electrical blocks, scopes, and signal converters. They are listed by path in the `all_blocks` CSV; their parameters are not individually meaningful for the research argument.

### Important: the clean file is not the file used by the matrix runner

`run_final_matrix.m` calls:

```matlab
run_case_2s('classic_dtc_winder', ...)
```

and edits blocks at paths such as:

```matlab
[m '/F_ref_set']
[m '/Tension Control/5']
[m '/FF_Mux/2']
```

Those paths exist in the **flat** `classic_dtc_winder.slx`. In `classic_dtc_winder_clean.slx`, the same blocks are wrapped:

```text
Line_Reference/F_ref_set
Tension Control
Feedforward/FF_Mux
Controller/omega_ref_ramp
Controller/Sum
Controller/PID Controller
Controller/dtc_estimator
```

So:

- the numerical results in the report come from the **flat** `classic_dtc_winder` model;
- `classic_dtc_winder_clean` is a re-packaged/clean copy for readability;
- `run_final_matrix` cannot be pointed at the clean file without changing its path-based edits;
- the two files should not be assumed to be bit-identical without a diff.

The values below are the values in the clean file. They match the physical parameters used by the flat model, but the hierarchy difference is real.

---

## 2. Model configuration that affects every result

These are solver settings, not block constants.

| Setting | Value in clean model | Effect |
|---|---|---|
| Solver | `VariableStepAuto` | Simulink chooses the variable-step solver; the Simscape network makes this an implicit solve, not a fixed-step solve |
| Solver type | Variable-step | Time steps are chosen by error control, not fixed |
| `StopTime` | `Tsim` | `winder_params.m` sets 20 s; `run_case_2s.m` overrides to 2 s |
| `MaxStep` | `1e-6` s | Limits the largest solver step; `run_case_2s` relaxes this to `5e-6` s |
| `RelTol` | `1e-3` | Relative error target; this is the main accuracy/speed knob |
| `StartTime` | `0.0` s | Simulation starts at zero |
| `SaveTime` | `on` | Time vector saved |
| `SaveOutput` | `on` | Logged outputs saved |
| `SaveState` | `off` | State history not saved |
| `SignalLogging` | `on` | `logsout` signal logging enabled |
| `SignalLoggingName` | `logsout` | Name of the signal log |
| `ReturnWorkspaceOutputs` | `on` | `sim` returns a `Simulink.SimulationOutput` object |
| `LimitDataPoints` | `off` | All logged samples retained |
| `Decimation` | `1` | No decimation |
| `AlgebraicLoopMsg` | `warning` | Algebraic loops warn rather than abort |
| `ConsistencyChecking` | `none` | No extra consistency check |
| `ExtrapolationOrder` | `4` | Solver extrapolation order |
| `NumberNewtonIterations` | `1` | One Newton iteration for implicit solves |
| `Refine` | `1` | No output refinement |

The Simscape network has its own `Solver Configuration` block. Its selected mask values include:

```text
NE_BACKWARD_EULER_ADVANCER
ODE1
0.001 s local sample
```

That is the local Simscape network solver/advancer setting, **not** the Simulink variable-step solver. It is a default-style setting, not a research parameter. The `MaxStep = 5e-6` override in `run_case_2s` is the setting that most directly controls simulation cost.

---

## 3. The parameters that actually set the operating point

These are the values a reader/examiner should be able to see immediately.

| Quantity | Value | Where it is set | What it does |
|---|---:|---|---|
| DC-bus voltage | **300 V** | `Vdc` / `Constant1` | Sets inverter voltage and the voltage reconstruction scale |
| Controller/estimator sample time | **20 µs** | `Ts_dtc` / `Constant9` | DTC sample, estimator Euler step, unit-delay and speed-PID sample |
| Stator resistance | **2.875 Ω** | `Rs` / `Constant7` | Resistive drop in the flux estimator |
| `Rs` mismatch factor | **1.0** | `Rs_factor` | Estimator uses the true `Rs`; no robustness mismatch in nominal case |
| d/q inductance | **8.5 mH** both | `Ld`, `Lq` | Surface-PMSM electrical dynamics |
| PM flux linkage | **0.175 Wb** | `lambda_f` | Torque constant `kt = 1.5 p lambda_f = 1.05 N·m/A` |
| Pole pairs | **4** | `p` | Torque and electrical-speed scaling |
| Stator flux reference | **0.175 Wb** | `lambda_ref` | Flux magnitude the DTC hysteresis regulates |
| Flux hysteresis band | **1.75 mWb** | `HB_lambda = 0.01 lambda_ref` | Flux error band; 1% of reference |
| Torque hysteresis band | **0.02 N·m** | `HB_torque` | Torque error band; 3-level torque comparator |
| Speed-loop proportional gain | **2.0** | `Kp_speed` | N·m per rad/s of speed error |
| Speed-loop integral gain | **150** | `Ki_speed` | N·m per (rad/s·s); integral time `Kp/Ki = 13.3 ms` |
| Torque limit | **5 N·m** | `Tmax` | Saturates the speed-PI/feedforward torque command |
| Maximum speed reference | **60 rad/s** | `w_max` | Tension-loop speed-reference clamp |
| Minimum speed reference | **0 rad/s** | `w_min` | Standstill allowed; no reverse command from tension loop |
| Web tension reference | **15 N** | `F_ref` | Nominal tension setpoint |
| Web tension limit | **200 N** | `Fmax` | Plant tension clamp and `Int_x` state limit |
| Line speed | **1.2 m/s** | `v_line_set` | Nominal web speed |
| Line-speed ramp | **1.0 s** runtime; 0.4 s saved default | `T_ramp` | S-curve duration; `run_case_2s` uses 1.0 s |
| Web stiffness | **3.0 × 10⁵ N/m** | `K_web = E A / L` | Tension generated by web stretch |
| Web damping | **500 N·s/m** | `C_web` | Damping term in the tension equation |
| Motor inertia | **8.0 × 10⁻⁴ kg·m²** | `Jm` | Part of plant inertia; **not** in PMSM block |
| Core/shaft inertia | **5.0 × 10⁻³ kg·m²** | `Jc` | Fixed roll/core inertia |
| Core radius | **0.05 m** | `rc` | Inner roll radius |
| Maximum roll radius | **0.12 m** | `rmax` | Radius state upper limit |
| Web density | **800 kg/m³** | `rho` | Roll mass and inertia |
| Web width | **0.30 m** | `w` | Roll mass and inertia |
| Web thickness | **0.5 mm** | `h` | Radius growth per revolution and roll mass |
| Tension PI gain | **4.4 × 10⁻⁴ rad/s per N** | `Kp_F` | Tension error to speed trim |
| Tension PI integral | **8.9 × 10⁻⁴ rad/s per (N·s)** | `Ki_F` | Removes steady tension error |
| Tension PI output limit | **±0.2 rad/s** | `draw_max` | Limits draw trim |
| Slack take-up | **0.02 rad/s** | `draw_takeup` | Extra draw when the web is slack |
| Slack threshold | **0.5 N** | `F_slack` | Below this, take-up is blended in |
| Feedforward enable | **1** | `ff_on` | Feedforward normally on |
| Feedforward mode | **0 saved / 1 runtime** | `ff_full` | Saved model: inertia only. Matrix runner: full tension+friction+inertia |
| Tension filter | **on** | `filt_on` | `1` selects filtered tension, `0` raw |
| Filter cutoff | **2 Hz** | `f_c` | `tau_F = 1/(2 pi f_c) = 79.6 ms` |
| Initial momentum | **0** | `H0` runtime | Cold start; `omega = H/J = 0` initially |
| Initial tension | **15 N** | `F0` runtime | Matches reference |
| Initial radius | **0.06 m winding / 0.115 m unwinding** | `r0` runtime | Defines roll-inertia case |

### What each major knob changes

| Change | Main effect | Watch for |
|---|---|---|
| Increase `Tmax` | More torque authority; faster tension recovery | Higher current, torque ripple, possible drive limit |
| Increase `Kp_speed` | Faster speed correction | Overshoot and interaction with the tension loop |
| Increase `Ki_speed` | Removes speed error faster | Windup, oscillation, torque saturation |
| Increase `HB_lambda` / `HB_torque` | Lower switching frequency and losses | Higher flux/torque ripple; may disturb tension |
| Increase `Kp_F` | Faster tension correction | Noise amplification and oscillation; filter lag limits it |
| Increase `Ki_F` | Faster steady-state tension correction | Overshoot and windup |
| Increase `T_ramp` | Smoother line start | Longer transient; less tension excitation |
| Set `ff_full = 1` | Compensates tension, friction, and variable inertia | More dependent on parameter accuracy |
| Increase `Jm` / `Jc` | Slower speed response | More torque needed for the same acceleration |
| Increase `rc` / `rmax` | Larger roll and inertia range | Lower maximum speed at fixed line speed |
| Increase `K_web` | Stiffer web; stronger tension for a given stretch | Higher loop gain, easier oscillation |
| Increase `C_web` | More web damping | Less oscillation, but more dissipative torque |
| Increase `f_c` | Less filter lag | More tension noise |
| Decrease `f_c` | Smoother tension feedback | More phase lag, slower loop |
| Increase `F_ref` | Higher tension and load torque | More current and torque saturation risk |
| Increase `v_line_set` | Higher line speed/power | `w_max`, `Tmax`, and converter limits |
| Change `Rs_factor` away from 1 | Introduces estimator `Rs` mismatch | Flux drift and torque-estimate error |
| Change `Ts_dtc` | Alters controller/estimator resolution | Too large: inaccurate flux; too small: slow simulation |

### Quick physical checks

- Nominal winding speed at `r = 0.06 m`, `v_line = 1.2 m/s`:
  `omega = v/r = 20 rad/s`.
- Nominal winding torque at `F = 15 N`, `r = 0.06 m`:
  `T_L = F r = 0.9 N·m`.
- Nominal power:
  `P = F v = 15 × 1.2 = 18 W`.
- Drive envelope:
  `Tmax × w_max = 5 × 60 = 300 W`.
  The 300 W is a **drive-limit envelope**, not a motor nameplate.
- Total inertia at `r = 0.06 m`: approximately **0.00833 kg·m²**.
- Total inertia at `r = 0.115 m`: approximately **0.0694 kg·m²**.
- Total inertia at `r = 0.12 m`: approximately **0.0816 kg·m²**.

---

## 4. Block-level audit: what is set and why

### 4.1 Top-level constants and tension filter

| Block | Parameter | Value | Effect |
|---|---|---:|---|
| `Constant1` | `Value` | `Vdc` = 300 V | Inverter DC link used by voltage reconstruction and DC source |
| `Constant7` | `Value` | `Rs*Rs_factor` = 2.875 Ω | Estimator stator resistance; factor 1 means no mismatch |
| `Constant8` | `Value` | `p` = 4 | Pole pairs in torque estimate |
| `Constant9` | `Value` | `Ts_dtc` = 20 µs | DTC/estimator sample time |
| `Constant11` | `Value` | `HB_lambda` = 1.75 mWb | Flux hysteresis band |
| `Constant12` | `Value` | `HB_torque` = 0.02 N·m | Torque hysteresis band |
| `Constant13` | `Value` | `lambda_ref` = 0.175 Wb | Stator flux reference |
| `filt_on` | `Value` | `filt_on` = 1 | Selects filtered tension feedback |
| `filt_sel` | `Criteria` | `u2 > 0.5` | Switch selects filtered path when `filt_on > 0.5` |
| `filt_sel` | `Threshold` | 0.5 | Threshold for the switch above |
| `lpf_gain` | `Gain` | `1/tau_F` = 12.566 rad/s | First-order filter bandwidth |
| `lpf_int` | `InitialCondition` | `F0` = 15 N | Filter starts at the tension setpoint |
| `lpf_int` | `LimitOutput` | `off` | Filter state is not clamped; physical plant clamps tension |
| `lpf_sum` | `Inputs` | `+ -` | Forms `F - F_filtered` |

The filter is:

```text
dF_filt/dt = (F - F_filt) / tau_F,    F_filt(0) = F0
tau_F = 1/(2*pi*f_c) = 79.6 ms
```

With `filt_on = 1`, the tension controller sees `F_filt`; with `filt_on = 0`, it sees raw `F`. The filter reduces tension noise but adds about 80 ms of lag, which matters for the tension-loop phase margin.

---

### 4.2 `Controller` subsystem

#### Port and signal meaning

| Port | Name | Meaning |
|---:|---|---|
| In 1–3 | `ib`, `ic`, `ia` | Phase-current feedback (note the order) |
| In 4 | `Rs` | Stator-resistance estimate |
| In 5 | `p` | Pole pairs |
| In 6 | `HB_lambda` | Flux hysteresis band |
| In 7 | `Ts` | Controller sample time |
| In 8 | `Vdc` | DC link |
| In 9 | `HB_torque` | Torque hysteresis band |
| In 10 | `lambda_ref` | Flux reference |
| In 11 | `In11` | Measured speed `omega` |
| In 12 | `In12` | Speed reference from `Tension Control` |
| In 13 | `Te_ref` | Torque reference from `Feedforward` |
| Out 1 | `lambda_s_mag` | Estimated flux magnitude |
| Out 2, 5, 7 | `Sa`, `Sb`, `Sc` | Upper-switch commands |
| Out 3 | `i_beta` | Clarke beta current |
| Out 4 | `Sa1` | Delayed `Sa` |
| Out 6 | `Te_est` | Estimated torque |
| Out 8, 10, 12 | `Out8`, `Out10`, `Out12` | Complementary gate commands |
| Out 9, 11 | `lambda_alpha`, `lambda_beta` | Flux components |
| Out 13 | `Out13` | Legacy reference sum; not connected at top level |
| Out 14 | `y` | Speed-PI torque command |
| Out 15 | `Out15` | Rate-limited active speed reference |

#### Speed PID — selected options

| Option | Selected value | Why it matters |
|---|---|---|
| Controller | **PI** | No derivative; speed loop is a PI regulator |
| Form | **Parallel** | `P`, `I` act independently |
| Time domain | **Discrete-time** | Runs at `Ts_dtc` |
| Sample time | **`Ts_dtc` = 20 µs** | Matches DTC sample |
| Integrator method | **Forward Euler** | Simple discrete integrator |
| P | **2.0** | Torque per rad/s of speed error |
| I | **150** | Torque per rad/s·s of speed error |
| D | **0** | Derivative disabled |
| N | **100** | Derivative filter pole; inactive because `D = 0` |
| Limit output | **on** | Torque command is bounded |
| Upper limit | **+5 N·m** | Matches `Tmax` |
| Lower limit | **−5 N·m** | Symmetric torque limit |
| Anti-windup | **clamping** | Integrator stops growing when saturated |
| `Kb` | **1** | Back-calculation gain for clamping |
| Initial conditions | **0** | Cold start |

The PID output goes to `Controller/y`, then to `Feedforward/In3`. The speed error is formed by `Controller/Sum` with input spec `+ -`:

```text
omega_err = omega_ref_ramp - omega
```

#### Rate limiter and legacy speed steps

| Block | Parameter | Value | Effect |
|---|---|---:|---|
| `omega_ref_ramp` | Rising slew | **+700 rad/s²** | Limits how fast the active speed reference can rise |
| `omega_ref_ramp` | Falling slew | **−700 rad/s²** | Symmetric falling limit |
| `omega_ref` | Step time | 0.05 s | Legacy open-loop speed step |
| `omega_ref` | Initial value | 0 rad/s | Before step |
| `omega_ref` | Final value | `w_ref` = 20 rad/s | After step |
| `omega_rev` | Step time | `t_rev` = 1e9 s | Effectively disabled |
| `omega_rev` | Final value | `-2*w_ref` = −40 rad/s | Legacy reversal command |
| `ref_sum` | Inputs | `+ +` | Adds the two legacy steps |

**Important:** `omega_ref` and `omega_rev` are **not** the active speed reference in the integrated winder model. Their sum feeds `Controller/Out13`, which is unconnected at top level. The active reference is `Tension Control/omega_ref` into `Controller/In12`, then through `omega_ref_ramp`. The 700 rad/s² limiter is therefore still active, but the 20 rad/s step is not.

#### Gate generation

| Block | Setting | Effect |
|---|---|---|
| `Unit Delay1/2/3` | IC 0, `Ts_dtc` | Holds previous `Sa`, `Sb`, `Sc` for voltage reconstruction and gate logic |
| `Logical Operator`, `Operator1`, `Operator2` | `NOT`, 2 inputs | Generates complementary lower-switch commands |
| `Data Type Conversion` (inside controller) | `double` | Converts Boolean gates to double |
| `Data Type Conversion1/2` (top level) | `double` | Converts complementary gates to double for Simscape-PS inputs |

The DTC switching table produces `Sa/Sb/Sc`. The inverter needs six gate signals: three upper and three complementary lower. The `NOT` blocks provide the lower devices. There is **no PWM block**; the switching table drives the converter gates directly.

#### `MATLAB Function` — voltage reconstruction

```matlab
function [v_alpha, v_beta] = calculate_voltages(Sa, Sb, Sc, Vdc)
v_alpha = (2/3) * Vdc * (Sa - 0.5 * (Sb + Sc));
v_beta  = (2/3) * Vdc * (sqrt(3)/2) * (Sb - Sc);
end
```

This converts the **last commanded** switching state and `Vdc` into the alpha-beta voltage applied to the motor. It replaces a voltage sensor. The block uses the delayed `Sa/Sb/Sc`, so the estimator integrates the voltage that was actually applied in the previous sample.

#### `MATLAB Function1` — DTC hysteresis and switching table

Selected thresholds and logic:

| Element | Value | Effect |
|---|---:|---|
| Flux comparator | 2-level | `d_lambda = 1` if `lambda_ref - lambda_s_mag > HB_lambda`; `0` if `< -HB_lambda`; otherwise hold |
| Torque comparator | 3-level | `d_torque = +1` if error `> HB_torque`; `-1` if `< -HB_torque`; `0` otherwise |
| Initial `d_lambda` | 1 | Start assuming flux must rise |
| Initial `d_torque` | 0 | Start with zero torque error |
| Sector edges | 30°, 90°, 150°, 210°, 270°, 330° | Six 60° sectors |
| Zero vector | `V0 = [0 0 0]` | Used when `d_torque = 0` |
| Vector selection | `n+1`, `n-1`, `n+2`, `n-2` | Flux/torque increase/decrease rules |
| Vector map | V1–V6 and V0 | Maps vector index to `Sa/Sb/Sc` |

The vector table is:

| `d_lambda` | `d_torque` | Selected vector |
|---:|---:|---|
| any | 0 | `V0` (zero vector) |
| 1 | +1 | `n+1` |
| 1 | −1 | `n−1` |
| 0 | +1 | `n+2` |
| 0 | −1 | `n−2` |

This is the classical DTC switching-table core. The hysteresis bands are the main ripple/frequency trade-off: smaller `HB_lambda`/`HB_torque` gives lower ripple but higher switching frequency.

#### `dtc_estimator` — flux and torque estimator

Full source is in `classic_dtc_winder_clean_matlab_functions.txt`. Key lines:

```matlab
persistent lam_a lam_b
if isempty(lam_a)
    lam_a = 0.175;
    lam_b = 0;
end

ia_true = -ia;
ib_true = -ib;

i_alpha = ia_true;
i_beta  = (1/sqrt(3))*ia_true + (2/sqrt(3))*ib_true;

lam_a = lam_a + Ts * (v_alpha - Rs*i_alpha);
lam_b = lam_b + Ts * (v_beta  - Rs*i_beta);

lambda_s_mag = sqrt(lam_a^2 + lam_b^2);
theta_s_rad  = atan2(lam_b, lam_a);
theta_s_deg  = mod(theta_s_rad * 180/pi, 360);

Te_est = 1.5 * p * (lam_a*i_beta - lam_b*i_alpha);
```

| Setting | Value | Effect |
|---|---:|---|
| Initial `lam_a` | 0.175 Wb | Stator flux starts at reference magnitude |
| Initial `lam_b` | 0 Wb | Flux aligned with alpha axis at `t = 0` |
| Current sign | `ia_true = -ia`, `ib_true = -ib` | Corrects the physical current-sensor sign convention |
| Flux integration | Forward Euler, `Ts` | Simple voltage-model integrator |
| `Rs` | 2.875 Ω | Resistive drop compensation |
| Torque formula | `1.5 p (lam_a i_beta - lam_b i_alpha)` | Standard PMSM torque estimate |

The pure integrator is the known weak point at low speed: any DC offset or `Rs` error causes flux drift. The model documents this and uses the nominal `Rs`; the experiment can vary `Rs_factor` to study it.

---

### 4.3 `Feedforward` subsystem

Inputs:

```text
In1 = J
In2 = omega_ref
In3 = torque command from speed PI
In4 = v_line
In5 = mode (+1 winding, -1 unwinding)
In6 = r
In7 = r
In8 = F_ref
```

Equations set by the blocks:

```text
Tff_extra = mode*F_ref*r + B*omega_ref
rdotFF    = mode*h*v_line/(2*pi*r)
wdotFF    = (dv_line/dt)/r - omega_ref*rdotFF/r^2
Jwdot     = J*wdotFF
dJ/dr     = rho*w*pi*r*(r^2+rc^2) + rho*w*pi*(r^2-rc^2)*r
dJw       = (dJ/dr)*rdotFF*omega_ref
T_inertia = Jwdot + dJw
T_total   = T_inertia + ff_full*(Tff_extra)
T_ff      = ff_on*T_total
Te_sum    = T_PI + T_ff
Te_sat    = sat(Te_sum, -Tmax, +Tmax)
```

| Block | Parameter | Value | Effect |
|---|---|---:|---|
| `ff_on` | `Value` | `ff_on` = 1 | Feedforward enabled |
| `ff_full_c` | `Value` | `ff_full` = 0 saved | 0 = inertia only; 1 = full tension+friction+inertia |
| `Te_sat` | Upper limit | `Tmax` = +5 N·m | Final torque-command clamp |
| `Te_sat` | Lower limit | `-Tmax` = −5 N·m | Symmetric clamp |
| `v_tau_ff` | `Gain` | `1/T_ramp` = 2.5 saved; 1.0 runtime | S-curve time scaling |
| `v_tau_sat_ff` | Limits | 0 to 1 | Clamps normalized time |
| `v_scurve_d` | `Expr` | `v_line_set*(6u-6u^2)/T_ramp` | Analytic S-curve acceleration |
| `Tff_extra` | `Expr` | `u1*F_ref*u3 + B*u4` | Tension load plus friction |
| `dJdr` | `Expr` | derivative of roll inertia | Captures variable-inertia effect |
| `wdotFF` | `Expr` | `u4/u1 - u2*u3/u1^2` | Angular acceleration from line acceleration |

**Saved default vs matrix runtime:** the clean model is saved with `ff_full = 0` (inertia-only). `run_final_matrix` calls `run_case_2s(..., fffull = 1)`, so the matrix results use **full feedforward**. This must be stated in any report table; otherwise the reader will think the default and the result used the same mode.

The feedforward is physically important because the plant inertia is not constant:

```text
J(r) = Jm + Jc + 0.5*m(r)*(r^2 + rc^2)
m(r) = rho*w*pi*(r^2 - rc^2)
```

At `r = 0.06 m`, `J ≈ 0.00833 kg·m²`; at `r = 0.115 m`, `J ≈ 0.0694 kg·m²`. An inertia-only feedforward that ignores `dJ/dr` will under-compensate during radius growth.

---

### 4.4 `Line_Reference` subsystem

| Block | Parameter | Value | Effect |
|---|---|---:|---|
| `v_tau` | `Gain` | `1/T_ramp` = 2.5 saved; 1.0 runtime | Normalizes time by ramp duration |
| `v_tau_sat` | Limits | 0 to 1 | Keeps normalized time in range |
| `v_scurve` | `Expr` | `v_line_set*(3u^2 - 2u^3)` | S-curve from 0 to `v_line_set` |
| `v_sat` | Limits | 0 to `v_line_set` = 1.2 m/s | Safety clamp |
| `F_ref_set` | `Value` | `F_ref` = 15 N | Tension reference output |
| `winder_mode` | `Value` | `winder_mode_set` = +1 or −1 | Winding/unwinding direction |

The S-curve has zero slope at both ends, so the line-speed acceleration starts and ends smoothly. That reduces the tension transient compared with a step or a linear ramp. `v_sat` is mathematically redundant for an S-curve in `[0,1]`, but it protects against a bad `T_ramp` or a changed expression.

`winder_mode_set` is **not defined inside `winder_params.m`**. `run_case_2s` assigns it:

```matlab
assignin('base','winder_mode_set',mode);   % +1 winding, -1 unwinding
```

If the clean model is run directly without setting this variable, it will error.

---

### 4.5 `Tension Control` subsystem

Inputs: `F` (filtered tension), `r`, `vline`, `mode`, `Fref`.

| Block | Parameter | Value | Effect |
|---|---|---:|---|
| `eF` | `Inputs` | `+ -` | `eF = Fref - F` |
| `PI_F` | Controller | **PI** | Tension loop is PI |
| `PI_F` | Form | **Parallel** | Independent P and I |
| `PI_F` | Time domain | **Continuous-time** | No discrete sample time; uses solver steps |
| `PI_F` | `P` | `Kp_F` = 4.4e-4 | rad/s trim per N |
| `PI_F` | `I` | `Ki_F` = 8.9e-4 | rad/s trim per N·s |
| `PI_F` | `D` | 0 | No derivative |
| `PI_F` | Output limits | ±`draw_max` = ±0.2 rad/s | Limits speed trim |
| `PI_F` | Anti-windup | clamping | Integrator stops at limit |
| `inv_Fslack` | `Gain` | `1/F_slack` = 2 | Normalizes tension for slack test |
| `one` | `Value` | 1 | Constant for `1 - F/F_slack` |
| `one_minus` | `Inputs` | `+ -` | `1 - F/F_slack` |
| `slack_sat` | Limits | 0 to 1 | Only positive slack correction |
| `takeup_gain` | `Gain` | `draw_takeup` = 0.02 rad/s | Fixed take-up speed |
| `draw_total` | `Inputs` | `+ +` | PI trim plus take-up |
| `mode_draw` | `Inputs` | 2, element-wise | Reverses trim sign for unwinding |
| `w_ff` | `Inputs` | `* /` | `w_ff = vline / r` |
| `w_ref` | `Inputs` | `+ +` | `w_ff + mode*draw` |
| `w_lim` | Limits | 0 to `w_max` = 60 rad/s | Speed-reference clamp |

Tension-loop equations:

```text
eF        = F_ref - F_filtered
u_PI      = PI_F(eF)                    % limited to +/- draw_max
slack     = sat(1 - F/F_slack, 0, 1)
u_takeup  = draw_takeup*slack
u_draw    = u_PI + u_takeup
w_ff      = v_line / r
w_ref     = w_ff + mode*u_draw
omega_ref = sat(w_ref, w_min, w_max)
```

The PI gains were designed for the plant from draw speed to tension, which is an integrator with gain `K*r`:

```text
K = E*A/L = 3e5 N/m
K*r at r=0.06 = 1.8e4
wn = 4 rad/s, zeta = 1
Kp_F = 2*zeta*wn/(K*r) = 4.4e-4
Ki_F = wn^2/(K*r)      = 8.9e-4
```

The `draw_takeup` term is a slack-prevention aid: when `F < 0.5 N`, it adds up to 0.02 rad/s of draw. The `mode` multiplication flips the trim sign when unwinding.

---

### 4.6 `Plant` — electrical drive and mechanical load

#### PMSM block — selected options

| Option | Selected value | Effect |
|---|---|---|
| Three-phase port | Composite | One three-phase port instead of separate phases |
| Stator connection | Wye | Star-connected stator |
| Parameterization | Constant | Constant `Ld`, `Lq`, `L0`, `Rs` |
| Pole pairs | 4 | Electrical/mechanical scaling |
| PM flux parameterization | Flux linkage | Uses `lambda_f = 0.175 Wb` |
| `Ld`, `Lq` | 8.5 mH each | Surface PMSM, non-salient |
| `L0` | 0.16 mH | Zero-sequence inductance |
| `Rs` | 2.875 Ω | Stator resistance |
| Zero sequence | Included | Full three-phase model |
| Rotor angle reference | d-axis | Standard dq orientation |
| Iron loss | None | No iron-loss resistance |
| `J` | 0 | **Mechanical inertia is in the plant** |
| `lam` | 0 | No PMSM mechanical damping; plant owns `Bm` |
| Thermal port | Off | No thermal network |
| Nominal `i_d`, `i_q` | 1 A | Linearization values, **not limits** |
| Nominal torque | 1 N·m | Linearization value, **not limit** |
| Nominal speed | 1 rpm | Linearization value, **not limit** |
| `idVec`, `iqVec` | [−200, 0, 200] A | Lookup breakpoints, **not ratings** |

`J = 0` and `lam = 0` are deliberate. The PMSM block is used as an electrical torque source; the Winder Plant integrates the mechanical momentum:

```text
dH/dt = Te - TL - B*omega
omega = H/J(r)
```

If the PMSM block also had inertia, the torque sensor would see a different torque and the feedforward `J` would be double-counted.

The `torque_constant` and `back_emf_constant` fields show 0.18, but they are **not active** because the selected PM-flux parameterization is `Flux linkage`, not `Torque constant`. The `LdMatrix`, `LqMatrix`, `PmMatrix`, `ktMatrix`, `keMatrix` fields are likewise inactive; they belong to the table-based parameterization option.

#### Converter block — selected options

| Option | Selected value | Effect |
|---|---|---|
| Three-phase port | Composite | One composite electrical port |
| Fidelity | Detailed | Switched device model, not averaged |
| Switching device | Ideal | Ideal switches with conduction data |
| Thermal port | Off | No device temperature model |
| `Ron` | 1 mΩ | On-state resistance |
| `Vf` | 0.8 V | Forward voltage |
| `Vth` | 0.5 V | Threshold voltage |
| `Ih` | 1 A | Holding current |
| `Goff` | 1 µS | Off-state conductance |
| `Eon` | 22.86 mJ | Turn-on loss data |
| `Eoff` | 17.14 mJ | Turn-off loss data |
| `Voff` | 300 V | Loss-model reference voltage |
| `Iout` | 600 A | Loss-model reference current |
| Protection diode | No dynamics | Ideal diode with `Vf=0.8`, `Ron=1 mΩ`, `Goff=10 µS` |
| Snubber | Excluded | `Rs=0.1 Ω`, `Cs=1e-7 F` are inactive |

The loss energies and 600 A are **device loss-model data**, not the motor rating. The converter's `Rs = 0.1 Ω` is the snubber resistance, **not** the motor stator resistance; because the snubber is excluded, it has no effect.

There is no PWM modulator in this model. The DTC switching table produces `Sa/Sb/Sc`; those plus their complements drive the six converter gates through `Six-Pulse Gate Multiplexer`. The effective switching frequency is variable and set by the hysteresis bands, not by a carrier.

#### DC source, sensors, and mechanical interfaces

| Block | Key setting | Effect |
|---|---|---|
| `DC Voltage Source` | `v0 = Vdc = 300 V` | DC bus |
| `Current Sensor`, `Current Sensor1`, `Current Sensor2` | Ideal | Measure `ia`, `ib`, `ic` |
| `Phase Splitter`, `Phase Splitter1` | Composite three-phase | Separate phase quantities |
| `Six-Pulse Gate Multiplexer` | `port_option = PS` | Combines six gate signals into a PS control port |
| `Torque Sensor` | Ideal | Measures shaft torque between PMSM and speed source |
| `Speed Source` | Ideal angular velocity | Imposes the Winder Plant speed on the PMSM mechanical port |
| `Mechanical Rotational Reference` (×3) | Mechanical ground | Reference for the rotational network |
| `PS-Simulink Converter` blocks | Default/inherit | Convert PS measurements to Simulink signals |
| `Simulink-PS Converter` blocks | Default/inherit | Convert Simulink commands to PS signals |
| `Solver Configuration` | Simscape local solver | `NE_BACKWARD_EULER_ADVANCER`, `ODE1`, 1 ms local sample |

The `Speed Source` is the key modelling choice: the PMSM is not allowed to set its own speed from its own inertia. The Winder Plant computes `omega`, and the speed source imposes it. That is why the PMSM `J` must be zero.

---

### 4.7 `Winder Plant` — every important gain and state

| Block | Parameter | Value | Effect |
|---|---|---:|---|
| `Jc` | `Value` | 0.005 kg·m² | Fixed core/shaft inertia |
| `Jm` | `Value` | 0.0008 kg·m² | Motor rotor inertia |
| `rc2` | `Value` | `rc^2` = 0.0025 m² | Core radius squared |
| `m` | `Gain` | `rho*web_w*pi` = 753.982 | Roll mass scale |
| `half_m` | `Gain` | 0.5 | Half-mass factor in roll inertia |
| `Jroll_core` | `Inputs` | 2, element-wise | `0.5*m*(r²+rc²)` |
| `Jroll` | `Inputs` | `+ +` | `Jc + Jroll_core` |
| `J` | `Inputs` | `+ +` | `Jm + Jroll` |
| `TL` | `Inputs` | 3, element-wise | `mode*F*r` |
| `dHdt` | `Inputs` | `+ - -` | `Te - TL - B*omega` |
| `Bw` | `Gain` | `B` = 1e-4 | Viscous damping torque |
| `Int_H` | IC / limits | `H0` / none | Momentum state; integrated `dH/dt` |
| `omega` | `Inputs` | `* /` | `H/J` |
| `num_dr` | `Inputs` | 2, element-wise | `mode*vline` |
| `h_gain` | `Gain` | `h` = 5e-4 m | Web thickness |
| `den_dr` | `Gain` | `2*pi` | Radius-growth denominator |
| `drdt` | `Inputs` | `* /` | `mode*h*vline/(2*pi*r)` |
| `Int_r` | IC / limits | `r0` / 0.05 to 0.12 m | Roll radius state |
| `vsurf` | `Inputs` | 2, element-wise | `omega*r` |
| `dv` | `Inputs` | `+ -` | `vsurf - vline` |
| `dxdt` | `Inputs` | 2, element-wise | `mode*(vsurf - vline)` |
| `Int_x` | IC / limits | `F0/K_web` / 0 to `Fmax/K_web` | Web stretch state |
| `K_x` | `Gain` | `K_web` = 3e5 N/m | Web stiffness |
| `C_d` | `Gain` | `C_web` = 500 N·s/m | Web damping |
| `F_sum` | `Inputs` | `+ +` | `K_web*x + C_web*dxdt` |
| `F_sat` | Limits | 0 to `Fmax` = 200 N | Physical tension clamp |

Plant equations:

```text
m(r)      = rho*w*pi*(r^2 - rc^2)
J_roll(r) = Jc + 0.5*m(r)*(r^2 + rc^2)
J(r)      = Jm + J_roll(r)
TL        = mode*F*r
dH/dt     = Te - TL - B*omega
omega     = H/J(r)
drdt      = mode*h*v_line/(2*pi*r)
v_surf    = omega*r
dx/dt     = mode*(v_surf - v_line)
F         = K_web*x + C_web*dx/dt
```

State initial conditions and limits:

| State | Initial condition | Limits |
|---|---|---|
| `Int_H` | `H0` = 0 (runtime) | None |
| `Int_r` | `r0` = 0.06 or 0.115 m (runtime) | 0.05 to 0.12 m |
| `Int_x` | `F0/K_web` = 15/3e5 = 5e-5 m | 0 to `Fmax/K_web` = 6.667e-4 m |

The `Int_r` limit is important: the radius cannot go below the core or above `rmax`. The `Int_x` limit indirectly limits tension to 200 N. The momentum state is deliberately unlimited; the speed reference clamp does the practical limiting.

---

### 4.8 `Logging` subsystem

| Signal | To Workspace variable | What it records |
|---|---|---|
| Flux magnitude | `lam_data` | Estimated `lambda_s_mag` |
| Phase A current | `ia_data` | `ia` |
| Switching state | `Sa_data` | `Sa` |
| Phase B current | `ib_data` | `ib` |
| Phase C current | via scope only | `ic` |
| Estimated torque | `Te_data` (variable name is **`Ts_data`**) | `Te_est` |
| Flux reference | scope only | `lambda_ref` |
| Flux alpha | XY Graph only | `lambda_alpha` |
| Flux beta | XY Graph only | `lambda_beta` |
| Mode | `Ic` scope | +1/−1 |
| Tension | `F_log` | `F` |
| Radius | `r_log` | `r` |
| Inertia | `J_log` | `J(r)` |
| Load torque | `TL_log` | `TL` |
| Speed-PI torque command | `Te_est` scope | `y` |
| Speed | `w_data` | `omega` |
| Actual torque | `Te_log` | `Te` from torque sensor |

**Naming issue:** `Logging/Te_data` has `VariableName = Ts_data`. It logs the **estimated** torque, not a sample time. `final_matrix` uses `Te_log` for actual torque, so the matrix results are not affected. If a future script looks for `Te_data`, it will not find it; it must use `Ts_data` or the block should be renamed.

The scopes (`Ic`, `Lambda_s_mag`, `Te_est`, `crrrents`, `omega`, `XY Graph`) are diagnostic only; they do not change the simulation.

---

## 5. Parameter-file audit

### 5.1 `pmsm_dtc_parameters.m`

| Constant | Value | Unit | Used in clean model? | Purpose |
|---|---:|---|---|---|
| `Rs` | 2.875 | Ω | Yes | Stator resistance for PMSM and estimator |
| `Ld` | 8.5e-3 | H | Yes | d-axis inductance |
| `Lq` | 8.5e-3 | H | Yes | q-axis inductance |
| `lambda_f` | 0.175 | Wb | Yes | PM flux linkage |
| `p` | 4 | — | Yes | Pole pairs |
| `J` | 0.0008 | kg·m² | No (legacy) | Rotor inertia; PMSM block uses `J=0`, plant uses `Jm` |
| `B` | 0.0001 | N·m·s | Indirect | Viscous damping; overwritten by `winder.Bm` (same value) |
| `Vdc` | 300 | V | Yes | DC bus |
| `Ts_dtc` | 20e-6 | s | Yes | DTC/estimator/PID sample |
| `Ts_pwm` | 2e-6 | s | No | SVM-DTC PWM resolution only; classical DTC has no PWM |
| `lambda_ref` | 0.175 | Wb | Yes | Stator flux reference |
| `HB_lambda` | 0.01*lambda_ref = 0.00175 | Wb | Yes | Flux hysteresis band |
| `HB_torque` | 0.02 | N·m | Yes | Torque hysteresis band |
| `Kp_speed` | 2.0 | — | Yes | Speed PI proportional gain |
| `Ki_speed` | 150 | — | Yes | Speed PI integral gain |
| `w_ref` | 20 | rad/s | Legacy | Original speed step; active winder reference comes from tension loop |
| `TL_init` | 0.5 | N·m | No | Legacy load step before load |
| `TL` | 2.0 | N·m | No | Legacy load step after load |
| `t_load` | 0.5 | s | No | Legacy load-step time |
| `Tsim` | 1 | s | Overridden | `winder_params` sets 20 s; `run_case_2s` sets 2 s |
| `Rs_factor` | 1.0 | — | Yes | Estimator `Rs` mismatch factor; 1.0 = no mismatch |
| `t_rev` | 1e9 | s | Legacy | Disables the legacy speed reversal |

**Takeaway:** `J`, `TL_init`, `TL`, `t_load`, `Ts_pwm`, `w_ref`, and `t_rev` are legacy/other-experiment values. They do not set the winder operating point, but they remain in the shared parameter file.

---

### 5.2 `winder_params.m`

| Constant | Value | Unit | Effect / status |
|---|---:|---|---|
| `winder.rho` | 800 | kg/m³ | Roll mass/inertia |
| `winder.w` | 0.30 | m | Web width |
| `winder.h` | 0.5e-3 | m | Web thickness |
| `winder.E` | 2.0e9 | Pa | Web Young's modulus |
| `winder.L` | 1.0 | m | Free web length |
| `winder.A` | 1.5e-4 | m² | `w*h`; used in `K_web` |
| `winder.rc` | 0.05 | m | Core radius |
| `winder.rmax` | 0.12 | m | Maximum radius |
| `winder.r0_wind` | 0.06 | m | Winding initial radius |
| `winder.r0_unwind` | 0.115 | m | Unwinding initial radius |
| `winder.Jc` | 0.005 | kg·m² | Core/shaft inertia |
| `winder.Jm` | 0.0008 | kg·m² | Motor inertia |
| `winder.Bm` | 0.0001 | N·m·s | Viscous damping |
| `winder.F_ref` | 15 | N | Tension setpoint |
| `winder.F0` | 15 | N | Initial tension |
| `winder.Fmax` | 200 | N | Tension limit |
| `winder.Tmax` | 5 | N·m | Torque limit |
| `winder.v_init` | 0.2 | m/s | Standalone ramp initial value (not clean S-curve) |
| `winder.v_slope` | 0.9 | m/s² | Standalone ramp slope (not clean S-curve) |
| `winder.v_max` | 2.0 | m/s | Standalone ramp final value (not clean S-curve) |
| `winder.v_line_set` | 1.2 | m/s | Clean-model line speed |
| `winder.T_ramp` | 0.4 | s | Saved default; runtime 1.0 s |
| `winder.f_c` | 2.0 | Hz | Tension filter cutoff |
| `winder.tau_F` | 0.0796 | s | `1/(2*pi*f_c)` |
| `winder.filt_on` | 1 | — | Filtered feedback enabled |
| `winder.C_web` | 500 | N·s/m | Web damping |
| `winder.ff_on` | 1 | — | Feedforward enabled |
| `winder.ff_full` | 0 | — | Saved default inertia-only; runtime matrix uses 1 |
| `winder.Kp_speed` | 2.0 | — | Same as drive speed PI |
| `winder.Ki_speed` | 150 | — | Same as drive speed PI |
| `winder.Kp_draw` | 1e-3 | rad/s per N | Standalone validation only |
| `winder.Ki_draw` | 2e-2 | rad/s per N·s | Standalone validation only |
| `winder.draw_max` | **0.2** | rad/s | Assigned 0.5 first, then overwritten to 0.2; final value is 0.2 |
| `winder.Kp_F` | 4.4e-4 | rad/s per N | Tension PI proportional |
| `winder.Ki_F` | 8.9e-4 | rad/s per N·s | Tension PI integral |
| `winder.draw_takeup` | 0.02 | rad/s | Slack take-up |
| `winder.F_slack` | 0.5 | N | Slack threshold |
| `winder.w_min` | 0 | rad/s | Speed-reference lower limit |
| `winder.w_max` | 60 | rad/s | Speed-reference upper limit |
| `winder.Ts` | 20e-6 | s | Controller/plant sample |
| `winder.Tsim` | 20 | s | Default simulation time; `run_case_2s` overrides to 2 |
| `winder_p` | `[rho w rc h E A L Jc Jm Bm Fmax rmax]` | — | Packed vector for the standalone MATLAB S-function, not the native clean plant |
| `winder_Jfun` | anonymous function | — | Total inertia helper `J(r)` |
| `K_web` | `E*A/L` = 3e5 | N/m | Web stiffness |
| `C_web` | 500 | N·s/m | Flat alias of `winder.C_web` |

**Duplicate assignment:** `winder.draw_max` is set to 0.5 on line 54 and then to 0.2 on line 64. MATLAB keeps the second value, so the tension PI limits are **±0.2 rad/s**. This is not a bug in execution, but it is confusing in a code listing.

**Standalone-only values:** `v_init`, `v_slope`, `v_max`, `Kp_draw`, `Ki_draw`, and `winder_p` belong to the standalone validation/S-function path. They do not set the native clean-model S-curve or tension PI.

---

### 5.3 Runtime overrides in `run_case_2s.m`

These overwrite the parameter-file values and must be used when interpreting the matrix results.

| Variable | Runtime value | Effect |
|---|---:|---|
| `winder_mode_set` | +1 winding or −1 unwinding | Direction |
| `r0` | 0.06 winding / 0.115 unwinding | Initial roll radius/inertia |
| `H0` | 0 | Cold-start momentum |
| `F0` | `F_ref` = 15 N | Initial tension |
| `Tsim` | 2 s | Matrix run length |
| `T_ramp` | 1.0 s | Slower S-curve than the saved 0.4 s |
| `ff_on` | 0 or 1 per case | Feedforward gate |
| `ff_full` | 1 | Full feedforward in the matrix |
| `filt_on` | 1 | Filtered tension |
| `MaxStep` | 5e-6 s | Relaxed from the saved 1e-6 s |
| `SimscapeLogType` | `none` | No Simscape logging |

`run_final_matrix.m` uses the **flat** `classic_dtc_winder` model and adds:

| Case group | Values |
|---|---|
| Four-way comparison | SVM/Classical × winding/unwinding × `ff = 0/1`, full feedforward |
| Line-speed robustness | `v_line_set = 0.8` and `1.6` m/s |
| Radius robustness | winding `r0 = 0.08` m; unwinding `r0 = 0.10` m |
| Tension step | `F_ref` 15 → 18 N at 1.2 s |

Those cases are 8 + 4 + 4 + 2 = **18 matrix rows**. The clean model's saved `ff_full = 0` is not the matrix setting; the matrix always passes `ff_full = 1`.

---

## 6. Selected options summary

| Block / area | Selected option | Consequence |
|---|---|---|
| Solver | Variable-step automatic, `RelTol=1e-3`, `MaxStep=1e-6` (runtime 5e-6) | Accuracy/runtime controlled by step limit |
| Speed loop | PI, parallel, discrete, forward Euler, `Ts_dtc`, output ±5, clamping | No derivative; torque command bounded |
| Tension loop | PI, parallel, continuous, `Kp_F`/`Ki_F`, output ±0.2, clamping | Continuous tension trim |
| PMSM | Constant parameterization, flux-linkage PM, wye, `LdLqL0`, zero sequence included, d-axis, no iron loss, thermal off, `J=0` | Electrical torque source; plant owns mechanics |
| Converter | Detailed, ideal switches, composite port, thermal off, protection diode no dynamics, snubber excluded | Switched 2-level VSI; no PWM block |
| DTC flux comparator | 2-level, `HB_lambda=1.75 mWb` | Flux ripple/switching frequency trade-off |
| DTC torque comparator | 3-level, `HB_torque=0.02 N·m` | Torque ripple/switching frequency trade-off |
| Switching table | Six 60° sectors, V0 zero vector, V1–V6 active vectors | Classical DTC |
| Voltage reconstruction | Last commanded `Sa/Sb/Sc` + `Vdc` | No voltage sensor |
| Line reference | S-curve, `v_line_set=1.2`, `T_ramp=1.0` runtime | Smooth start; low tension transient |
| Tension filter | First-order, `f_c=2 Hz`, `tau_F=79.6 ms`, enabled | Noise reduction with lag |
| Feedforward | Enabled; saved inertia-only, matrix full | Variable-inertia compensation |
| Radius state | Limited 0.05–0.12 m | Physical roll bounds |
| Tension state | Limited 0–200 N equivalent | Physical web limit |
| Data type | `double` for gate conversions | No Boolean/PS type mismatch |

---

## 7. What is intentionally not listed as “important”

The following do not change the research result and are therefore not expanded line by line:

- `Inport`/`Outport` numbering and labels;
- scope positions, colours, axis limits, and figure backgrounds;
- `To Workspace` `SaveFormat = Timeseries` (all loggers use it);
- `Position`, `ZOrder`, `Orientation`, `ShowName`, and similar layout properties;
- standard library internals such as `Sum` accumulators, `Product` data types, `Scope` rendering blocks, and Simscape converter helper blocks;
- `MaskValues` strings for PS-Simulink converters, except where they select a meaningful option (`Solver Configuration`, PMSM, converter, PID).

The `all_params` CSV still contains them, so nothing has been hidden if an examiner asks for the full dump.

---

## 8. Issues and caveats to state in the report/viva

1. **Clean vs executed model.** The matrix runner uses `classic_dtc_winder`, not `classic_dtc_winder_clean`. The clean model is subsystem-wrapped; the runner's path-based edits (`/F_ref_set`, `/Tension Control/5`, `/FF_Mux/2`) target the flat model. Do not claim the matrix was run on the clean file without changing the runner.
2. **`winder_mode_set` is external.** It is not defined in `winder_params.m`; `run_case_2s` sets it. Running the clean model directly without it will fail.
3. **`ff_full` default vs matrix.** Saved clean model: `ff_full=0` (inertia only). Matrix: `ff_full=1` (full). State which one a given result uses.
4. **`T_ramp` default vs matrix.** Saved: 0.4 s. Matrix: 1.0 s. The S-curve and feedforward derivative change accordingly.
5. **`Te_data` logs `Ts_data`.** It is the estimated torque; `Te_log` is actual torque. A future script looking for `Te_data` will not find it.
6. **Legacy speed steps.** `omega_ref`, `omega_rev`, and `ref_sum` feed `Out13`, which is unconnected. The active reference is `Tension Control/omega_ref` into `Controller/In12`.
7. **`draw_max` duplicate.** First 0.5, then 0.2; final is 0.2.
8. **`Rs` name collision.** Motor `Rs=2.875 Ω`; converter snubber `Rs=0.1 Ω`; snubber is excluded.
9. **`J` name collision.** PMSM block `J=0`; `winder.Jm=8e-4`; `pmsm_dtc_parameters.m` also defines `J=8e-4` but the PMSM block does not use it. The plant owns inertia.
10. **`Tsim` collision.** `pmsm_dtc_parameters.m` sets 1 s, `winder_params.m` sets 20 s, and `run_case_2s` sets 2 s. Load order matters; the matrix uses 2 s.
11. **No PWM.** `Ts_pwm=2e-6` belongs to SVM-DTC. Classical DTC uses hysteresis and a switching table; effective switching frequency is variable.
12. **No voltage sensor.** `MATLAB Function` reconstructs voltage from the last gate state. Estimator accuracy therefore depends on `Vdc`, dead time, and device drops not modelled in detail.
13. **Zero-vector comment vs code.** The switching-table comment says V0/V7 may alternate for switching-loss balance, but the code always selects `V0 = [0 0 0]`. It is functionally a valid DTC zero vector, but the comment overstates what is implemented.

---

## 9. Suggested run recipe for the clean model

The clean model needs the same base variables as the flat model, but the matrix runner's path edits do not apply. A minimal direct run is:

```matlab
root = pwd;  % run this from the repository root
addpath(fullfile(root,'experiments','exp05_winder_mechanics','models'));
addpath(fullfile(root,'experiments','exp05_winder_mechanics','scripts'));
addpath(fullfile(root,'experiments','exp03_rs_boundary','scripts'));
addpath(fullfile(root,'tools'));

run(fullfile(root,'experiments','exp03_rs_boundary','scripts','pmsm_dtc_parameters.m'));
run(fullfile(root,'experiments','exp05_winder_mechanics','scripts','winder_params.m'));

assignin('base','winder_mode_set',1);   % +1 winding
assignin('base','r0',0.06);
assignin('base','H0',0);
assignin('base','F0',F_ref);
assignin('base','Tsim',2);
assignin('base','T_ramp',1.0);
assignin('base','ff_on',1);
assignin('base','ff_full',1);
assignin('base','filt_on',1);

load_system('classic_dtc_winder_clean');
set_param('classic_dtc_winder_clean','MaxStep','5e-6','SimscapeLogType','none');
out = sim('classic_dtc_winder_clean');
```

This run does **not** create `wref_log` or `vline_log`; those are added by `run_case_2s` at the flat model's top level. For clean-model logging, add `To Workspace` blocks inside `Controller` (after `omega_ref_ramp`) and inside `Line_Reference` (after `v_sat`), or log the existing signals with signal logging.

---

## 10. Bottom line

The model's operating point is set by a small set of physically meaningful values:

```text
Vdc = 300 V
Ts_dtc = 20 us
Rs = 2.875 ohm, Ld = Lq = 8.5 mH, lambda_f = 0.175 Wb, p = 4
lambda_ref = 0.175 Wb, HB_lambda = 1.75 mWb, HB_torque = 0.02 N.m
Kp_speed = 2, Ki_speed = 150, Tmax = 5 N.m
F_ref = 15 N, Fmax = 200 N, v_line_set = 1.2 m/s, T_ramp = 1.0 s (runtime)
K_web = 3e5 N/m, C_web = 500 N.s/m
Jm = 8e-4, Jc = 5e-3 kg.m^2, rc = 0.05 m, rmax = 0.12 m
Kp_F = 4.4e-4, Ki_F = 8.9e-4, draw_max = 0.2 rad/s
ff_on = 1, ff_full = 1 (matrix), filt_on = 1, f_c = 2 Hz
```

Everything else in the 4,553-record parameter dump is either a default, a port/layout property, a logging convenience, or an inactive option belonging to a parameterization that the model did not select.
