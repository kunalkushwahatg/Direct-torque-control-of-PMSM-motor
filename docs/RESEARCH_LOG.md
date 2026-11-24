# Research log

## 2026-09: classical DTC
- Built the PMSM plus classical hysteresis DTC (switching table, voltage-model flux/torque estimator) in Simulink/Simscape.
- Found a current-sensor polarity quirk by testing (the estimator applies `-ia` and `-ib`).

## 2026-10: SVM-DTC
- Replaced the switching table with two PI controllers in the stator-flux frame plus 5 kHz PWM.
- Fixed: algebraic loop (unit delay), gate order, data type, the Simulink-PS filter erasing PWM pulses, and integrator windup.
- Found and fixed later (see `LESSONS_LEARNED.md`): PWM block expects volts; estimator drift from PWM duty quantisation; slow flux PI; stray recursive line in the estimator; speed-PI windup; J and B not applied.
- Result at 20 us controller sample time, 2 N.m load: torque ripple RMS 0.079 vs 0.451 N.m, current THD (20 kHz) 4.7 vs 26.1 %, fixed 5 kHz vs about 7.4 kHz switching.

## 2026-10-04: project organised, experiment 01 finalised
- Files restructured into `experiments/`, `literature/`, `tools/`, and `docs/`. exp01 figures and summary table generated.
- Merged `make_report` + `make_figures` into `scripts/make_results.m`.
- exp02 (Rs mismatch, low speed, reversal) done: both controllers lose control with Rs +30 % (all speeds) and with -30 % at low speed; the weak point is the shared flux estimator.
- exp03 (finer Rs sweep, 20 runs) done: at 20 rad/s any Rs overestimate of 5 % or more loses control, underestimates up to 30 % survive with a flux bias; at 5 rad/s every tested mismatch (even -10 %) loses control. SVM-DTC and classical DTC fail at the same moment (within a few ms). The simple growth-rate formula is only qualitatively supported.
- Literature first pass written (`docs/literature_rs_robust_flux_estimation.md`).

## 2026-11: exp05 winder study
- Added the winder/unwinder mechanical model, tension PI loop, speed trim, radius/inertia/tension feedforward, and S-curve line reference.
- Investigated the SVM winding resonance; introduced physically justified Kelvin–Voigt web damping (`C_web = 500 N·s/m`) and bounded the residual transient.
- Corrected the classical DTC wiring error; the earlier “flux-estimator collapse” was a torque-reference port error, not an estimator failure.
- Ran the final 18-case matrix: four-way comparison, line-speed robustness, initial-radius robustness, and tension step.
- Final results show feedforward reduces tension RMSE by about 88–98 %; classical DTC gives the tighter winding band, while SVM-DTC gives lower torque ripple and current.

## 2026-11-15: validation and documentation
- Added standalone winder validation metrics and figures.
- Audited the classical clean model block-by-block; audit evidence is in `docs/model_audit/`.
- Built the final report and the mid-semester report.

## 2026-11-24: filter and feedforward corrections
- Corrected the `filt_sel` switch wiring so `filt_on = 1` selects the filtered tension.
- Corrected `Tff_extra` to use the stepped `F_ref_set` input instead of the global `F_ref`.
- Re-ran the 18-case matrix with the corrected models and updated the report figures and tables.

## Next
- Resolve the low-speed flux-estimator boundary with an Rs-tolerant observer.
- Add current-offset and inverter dead-time tests.
