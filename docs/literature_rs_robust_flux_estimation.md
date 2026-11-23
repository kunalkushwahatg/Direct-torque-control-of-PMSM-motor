# Literature map: flux estimation that tolerates a wrong stator resistance (Rs)

**Status:** first pass from web-search summaries on 2026-10-05. I have NOT read the full papers, so the "limitation" column repeats what the search summaries say and must be checked against the actual papers before you cite or build on it. Nothing here proves that a gap is unexplored.

**Why this matters for us:** exp02 showed both SVM-DTC and classical DTC lose control when the estimator's Rs is +30 % too high, and at low speed when it is 30 % too low. The shared flux estimator is the weak point.

## Method families found

| # | Family | Idea in one line | Example source | Limitation noted in the summaries (verify!) |
|---|---|---|---|---|
| 1 | **Stator-flux estimator comparison / problems statement** | Compare pure integrator, low-pass filter, and compensated estimators for DTC of PMSM | [A comparison of stator flux linkage estimators for a direct torque controlled PMSM drive](https://www.researchgate.net/publication/224115552_A_comparison_of_stator_flux_linkage_estimators_for_a_direct_torque_controlled_PMSM_drive); [Problems of Stator Flux Estimation in DTC of PMSM Drives](https://www.researchgate.net/publication/216154135_Problems_of_Stator_Flux_Estimation_in_DTC_of_PMSM_Drives) | Background papers; Rs variation is described as a major DTC problem, worst at low speed because the resistive drop stays significant while the voltage is small |
| 2 | **PI stator-resistance compensator** | A PI loop corrects Rs online | [A PI stator resistance compensator for a DTC interior PMSM drive](https://www.researchgate.net/publication/3874814_A_PI_stator_resistance_compensator_for_a_direct_torque_controlled_interior_permanent_magnet_synchronous_motor_drive) | Not checked: how it behaves for positive Rs error at low speed, and whether it needs the rotor angle or flux model |
| 3 | **Current-based Rs estimator** | Compare actual and reference current to track the Rs change | summary of the IPMSM DTC Rs estimator found by the search | Depends on current reference accuracy and a good motor model |
| 4 | **Kalman filter (EKF) Rs estimation** | Reduced-order EKF updates Rs online | [Speed sensorless torque control of an IPMSM drive with online stator resistance estimation using reduced order EKF](https://www.sciencedirect.com/science/article/abs/pii/S0142061512006321) | Typically more computation and tuning effort |
| 5 | **Wavelet-based Rs estimator** | Multi-resolution wavelet analysis to estimate Rs for DTC | [Stator resistance estimator for DTC of PMSM drive systems using multi-resolution analysis wavelet](https://www.researchgate.net/publication/264551497_Stator_resistance_estimator_for_direct_torque_control_of_permanent_magnet_synchronous_motor_drive_systems_using_multi-resolution_analysis_wavelet) | Not checked |
| 6 | **Closed-loop (PI-compensated) flux observers** | Feedback on flux magnitude to cancel integrator drift | summary from [Performance Improvement of Nonlinear Flux Observer for Sensorless Control of PMSM](https://www.researchgate.net/publication/367231584_Performance_Improvement_of_Nonlinear_Flux_Observer_for_Sensorless_Control_of_PMSM) | Summaries say PI-based observers degrade under large parameter variation and disturbances |
| 7 | **Hybrid observers (voltage + current model)** | Current model at low speed, voltage model at high speed, blended | [Robust sensorless control of high speed PMSM drives under low carrier ratios and parameter uncertainties](https://pmc.ncbi.nlm.nih.gov/articles/PMC13049048/) and related hybrid flux observer work | Summaries say traditional hybrid active-flux observers lose performance, even go unstable, with Rs mismatch at low speed |
| 8 | **Sliding-mode flux observers** | Super-twisting observer for direct torque and flux control | [A Super-Twisting Sliding-Mode Stator Flux Observer for Sensorless Direct Torque and Flux Control of IPMSM](https://doi.org/10.3390/en12132564) | Not checked: chattering, tuning, switching-frequency cost |
| 9 | **Drift- and parameter-compensated estimators** | Estimator designed for zero-frequency operation (induction motors) | [Drift and parameter compensated flux estimator for persistent zero stator frequency operation](https://www.researchgate.net/publication/3972843_Drift_and_parameter_compensated_flux_estimator_for_persistent_zero_stator_frequency_operation_of_sensorless_controlled_induction_motors) | Induction motor, not PMSM |
| 10 | **Controller-observer co-design** | Estimate unknown resistance inside the control law | [A Robust Sensorless Controller-Observer Strategy for PMSMs with Unknown Resistance and Mechanical Model](https://arxiv.org/pdf/2002.01823) | Not checked: complexity, applicability to DTC-SVM |
| 11 | **DTC-SVM with extra flux PI (DTFC)** | Extra PI regulation tightens flux tracking and robustness | summaries around direct torque and flux control for DTC-SVM | Does not by itself fix a wrong flux estimate (our exp02: the estimate stays at 0.175 while the real flux is off) |

## Observations that connect to our results
- Rs error is a **well-known** problem, so "Rs robustness" alone will not be novel; the novelty has to be in the *how* (cost, simplicity, stability proof, low-speed behaviour, or the DTC-SVM context).
- Our exp02 asymmetry (higher assumed Rs is unstable at every speed, lower is a speed-dependent bias) is explained by a simple error equation: error rate = (Rs_assumed - Rs_true)/L. I did not find (in these summaries) a paper that frames it this way for DTC-SVM, but I have not checked thoroughly.

## Candidate gaps to investigate (hypotheses, NOT confirmed novelty)
1. **A lightweight self-correcting Rs term inside SVM-DTC itself**, using signals the controller already has (flux-PI and torque-PI integrator states), without EKF cost or injection. Check whether the information is observable without the rotor angle.
2. **Low-speed hybrid estimation without position sensor** that specifically avoids the positive-Rs-error instability.
3. **A stability-guaranteed fix evaluated against the same test set** (this project's exp02/exp03 tables) instead of single-case demonstrations.

## Next literature steps
- Read items 2, 4, 7 and 10 fully and note: test conditions, speeds, Rs error range, metrics, and whether they test positive and negative Rs error separately.
- Search specifically for "DTC-SVM" plus "stator resistance" plus "stability analysis".
