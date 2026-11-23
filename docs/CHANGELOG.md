# Research log

## 2026-09: classical DTC
- Built the PMSM plus classical hysteresis DTC (switching table, voltage-model flux/torque estimator) in Simulink/Simscape (archive/01, archive/02).
- Found a current-sensor polarity quirk by testing (the estimator applies -ia and -ib).

## 2026-10: SVM-DTC
- Replaced the switching table with two PI controllers in the stator-flux frame plus 5 kHz PWM (archive/03).
- Fixed: algebraic loop (unit delay), gate order, data type, the Simulink-PS filter erasing PWM pulses, and integrator windup.
- Found and fixed later (see lessons_learned.md): PWM block expects volts; estimator drift from PWM duty quantisation; slow flux PI; stray recursive line in the estimator; speed-PI windup; J and B not applied.
- Result at 20 us controller sample time, 2 N.m load: torque ripple RMS 0.079 vs 0.451 N.m, current THD (20 kHz) 4.7 vs 26.1 %, fixed 5 kHz vs about 7.4 kHz switching.

## 2026-10-04: project organised, experiment 01 finalised
- Files restructured into experiments/, archive/, literature/, tools/, docs/ (see FILE_MAP.md). exp01 figures and summary table generated.
- Merged make_report + make_figures into scripts/make_results.m (old versions in archive/04_superseded_scripts).
- exp02 (Rs mismatch, low speed, reversal) done: both controllers lose control with Rs +30 % (all speeds) and with -30 % at low speed; the weak point is the shared flux estimator.
- exp03 (finer Rs sweep, 20 runs) done: at 20 rad/s any Rs overestimate of 5 % or more loses control, underestimates up to 30 % survive with a flux bias; at 5 rad/s every tested mismatch (even -10 %) loses control. SVM-DTC and classical DTC fail at the same moment (within a few ms). The simple growth-rate formula is only qualitatively supported.
- Literature first pass written (docs/literature_rs_robust_flux_estimation.md).
- Next: resolve the low-speed boundary, choose one gap (Rs-tolerant flux estimation), then build and test it on the exp02/exp03 test map; later current offset and dead time.
