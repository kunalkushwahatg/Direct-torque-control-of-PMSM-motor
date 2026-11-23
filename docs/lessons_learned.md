# Lessons learned (debugging knowledge worth keeping)

1. **The Simscape PWM Generator (Three-phase, Two-level) takes Vabc in VOLTS and divides by Vdc/2 itself.** A normalised +-1 signal gives about 0.3 % modulation depth.
2. **A voltage-model flux estimator must integrate the voltage actually applied, not the commanded one.** PWM duty quantisation (1 % steps at Ts = 2 us with a 200 us carrier) caused about 0.05 Wb of flux error in 20 ms. Reconstruct the voltage from the gate pulses, averaged over the control period.
3. **Flux PI bandwidth matters.** Kp_lambda = 50 gave about 50 rad/s of bandwidth against about 1200 rad/s for the torque loop, and the flux collapsed. Kp = 1200 and Ki = 5e5 worked. Torque plant: dTe/dt is about 1.5 p lambda_f / Ld times vT.
4. **Classical DTC ripple depends strongly on sample time.** Compare at a realistic 20-50 us, never at 2 us (500 kHz sampling, about 64 kHz switching).
5. The saved models contained a stray self-call line in `dtc_estimator` that stops compilation. Check line 2 of the function after pasting code.
6. The speed PI needs anti-windup (clamping) when its output is limited.
7. Set the motor block's J and B from the workspace; check block parameters, not only workspace variables.
8. A MATLAB script run inside a function does not share the base workspace, and Simulink models read from the base workspace, so drive runs from a script.
9. `mv` is a PowerShell alias for Move-Item. Windows' 260-character path limit breaks Simulink code generation in deep folders.
10. Use `SimscapeLogType = none` for long runs to avoid out-of-memory errors.
11. **The voltage-model flux estimator is unstable for +30 % Rs error and biased for -30 %**, for both SVM-DTC and classical DTC (exp02). Always test flux estimators with a mismatched Rs; true flux (from measured currents) is the right yardstick, not the estimate.
12. When running work in parallel MATLAB sessions, start them with the experiment's `setup_paths` so that scripts/ and models/ are on the path.
13. In exp03 the Rs-error failure time is the same (within a few ms) for SVM-DTC and classical DTC, so fixes must target the flux estimator, not the modulation. At 5 rad/s even -10 % Rs error loses control.
14. Running two MATLAB sessions needs spare RAM (each ~1-2 GB with Simscape); with under ~1 GB free the licence service fails (error 5006). Run one session at a time.
